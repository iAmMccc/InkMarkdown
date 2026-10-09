import UIKit
import Kingfisher
import InkMarkdown

/// 基于 Kingfisher 下载和缓存的完整图片管理后端。多个呈现可共享同一实例。
@MainActor
public final class InkKingfisherImageBackend: InkImageBackend {
  /// 后端资源预算。配置在实例创建时固定，避免宿主之间相互覆盖。
  public struct Configuration: Sendable {
    /// 内存缓存预算，默认 60 MiB。
    public var memoryBytes = 60 * 1024 * 1024
    /// 内存缓存条目数。
    public var memoryCount = 100
    /// 同时处理的请求数，包括生成图及磁盘读取。
    public var maxConcurrentLoads = 4
    /// 最大等待请求数。
    public var maxPendingLoads = 32
    /// 解码后的最大边长，限制高分辨率位图占用。
    public var maxPixelSize = 4096
    /// 是否持久化图片；默认仅使用内存，避免生成内容意外落盘。
    public var usesDiskCache = false
    /// 启用磁盘缓存时的容量上限。
    public var diskBytes: UInt = 200 * 1024 * 1024
    /// 创建默认预算。
    public init() {}
  }

  private final class Pending {
    let id = UUID()
    let request: InkImageRequest
    var waiters: [UUID: CheckedContinuation<UIImage, Error>] = [:]
    var task: Task<Void, Never>?
    init(_ request: InkImageRequest) { self.request = request }
  }

  /// 已固化的后端配置。
  public let configuration: Configuration
  private let cache: ImageCache
  private let sessionConfiguration: URLSessionConfiguration
  private var pending: [String: Pending] = [:]
  private var queue: [String] = []
  private var active = 0

  /// 创建隔离的 Kingfisher 后端；同名磁盘缓存仅应由同一安全域使用。
  /// - Parameters:
  ///   - configuration: 缓存、调度与解码预算，数值必须为有效的正数。
  ///   - cacheName: 磁盘缓存命名空间；省略时使用独立随机名称。
  public nonisolated init(configuration: Configuration = .init(), cacheName: String = UUID().uuidString,
                          sessionConfiguration: URLSessionConfiguration = .ephemeral) {
    precondition(configuration.memoryBytes > 0 && configuration.memoryCount > 0)
    precondition(configuration.maxConcurrentLoads > 0 && configuration.maxPendingLoads >= 0)
    precondition(configuration.maxPixelSize > 0 && configuration.diskBytes > 0)
    self.configuration = configuration
    self.sessionConfiguration = sessionConfiguration.copy() as! URLSessionConfiguration
    cache = ImageCache(name: "InkMarkdown." + cacheName + ".v2.pixels-\(configuration.maxPixelSize)")
    cache.memoryStorage.config.totalCostLimit = configuration.memoryBytes
    cache.memoryStorage.config.countLimit = configuration.memoryCount
    cache.diskStorage.config.sizeLimit = configuration.diskBytes
  }

  /// 同步内存查询；不会执行磁盘或网络操作。
  public func cachedImage(for request: InkImageRequest) -> UIImage? {
    cache.retrieveImageInMemoryCache(forKey: cacheKey(for: request))
  }

  private func cacheKey(for request: InkImageRequest) -> String {
    // 旧 Asset 条目已在首次解码时丢失 scale；仅隔离此来源，不废弃其他图片缓存。
    request.source.scheme == .asset ? "asset-scale-v1:" + request.cacheKey : request.cacheKey
  }

  /// 获取图片，合并同键请求；取消只移除当前调用，最后一个调用取消后停止底层任务。
  public func image(for request: InkImageRequest) async throws -> UIImage {
    try Task.checkCancellation()
    if let image = cachedImage(for: request) { return image }
    let key = cacheKey(for: request)
    let subscriber = UUID()
    return try await withTaskCancellationHandler(operation: {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        if let existing = pending[key] {
          existing.waiters[subscriber] = continuation
          return
        }
        guard active < configuration.maxConcurrentLoads || queue.count < configuration.maxPendingLoads else {
          continuation.resume(throwing: ImageLoadError.queueFull)
          return
        }
        let entry = Pending(request)
        entry.waiters[subscriber] = continuation
        pending[key] = entry
        queue.append(key)
        drain()
      }
    }, onCancel: {
      Task { @MainActor [weak self] in self?.cancel(key: key, subscriber: subscriber) }
    })
  }

  private func cancel(key: String, subscriber: UUID) {
    guard let entry = pending[key], let waiter = entry.waiters.removeValue(forKey: subscriber) else { return }
    waiter.resume(throwing: CancellationError())
    guard entry.waiters.isEmpty else { return }
    pending.removeValue(forKey: key)
    queue.removeAll { $0 == key }
    if let task = entry.task {
      // 不提前释放运行额度：不合作的生成器返回前仍占用真实资源。
      task.cancel()
    }
    drain()
  }

  private func drain() {
    while active < configuration.maxConcurrentLoads, !queue.isEmpty {
      let key = queue.removeFirst()
      guard let entry = pending[key] else { continue }
      active += 1
      let cache = self.cache
      let config = configuration
      let request = entry.request
      let sessionConfiguration = self.sessionConfiguration
      let generation = entry.id
      entry.task = Task { [weak self] in
        let result: Result<UIImage, Error>
        var needsDiskWrite = false
        do {
          let image: UIImage
          if config.usesDiskCache, let disk = try await cache.retrieveImageInDiskCache(
            forKey: key, options: [.cacheSerializer(InkImageCacheSerializer())]) {
            image = disk
          } else {
            image = try await Self.produce(request, maxPixelSize: config.maxPixelSize,
                                           sessionConfiguration: sessionConfiguration)
            needsDiskWrite = config.usesDiskCache
          }
          try Task.checkCancellation()
          result = .success(image)
        } catch { result = .failure(error) }
        self?.complete(key: key, generation: generation, result: result, toDisk: needsDiskWrite)
      }
    }
  }

  private func complete(key: String, generation: UUID, result: Result<UIImage, Error>, toDisk: Bool) {
    active -= 1
    defer { drain() }
    guard let entry = pending[key], entry.id == generation else { return }
    pending.removeValue(forKey: key)
    if case .success(let image) = result {
      cache.store(image, forKey: key, cacheSerializer: InkImageCacheSerializer(), toDisk: toDisk)
    }
    for waiter in entry.waiters.values { waiter.resume(with: result) }
  }

  /// 清除此后端的内存缓存；核心在配置切换时不会调用。
  public func clearMemoryCache() { cache.clearMemoryCache() }

  /// 清除此后端的磁盘缓存，完成后返回。
  public func clearDiskCache() async { await cache.clearDiskCache() }

  nonisolated private static func produce(_ request: InkImageRequest, maxPixelSize: Int,
                                          sessionConfiguration: URLSessionConfiguration) async throws -> UIImage {
    let width = min(request.display.maxPixelWidth, CGFloat(maxPixelSize))
    guard width.isFinite, width > 0 else { throw ImageLoadError.decodeFailed }
    let display = DisplayContext(maxPixelWidth: width, scale: request.display.scale,
                                 contentMode: request.display.contentMode)
    let processor = DownsamplingImageProcessor(size: CGSize(width: width, height: width))
    let options = KingfisherParsedOptionsInfo([.processor(processor), .scaleFactor(1)])
    if let generated = request.source.generatedRequest {
      guard let generator = request.generator else {
        throw ImageLoadError.generatedLoaderUnavailable(owner: generated.owner)
      }
      let image = try await generator.loadImage(source: request.source, display: display)
      try Task.checkCancellation()
      guard image.size.width * image.scale <= CGFloat(maxPixelSize),
            image.size.height * image.scale <= CGFloat(maxPixelSize) else { throw ImageLoadError.decodeFailed }
      return image
    }
    guard request.securityPolicy.rejectionReason(for: request.source) == nil else {
      throw ImageLoadError.sourceRejected
    }
    switch request.source.scheme {
    case .http, .https:
      // 请求独享传输 delegate，防止不同策略或取消状态相互污染；上层已合并同键请求。
      let downloader = ImageDownloader(name: UUID().uuidString)
      let delegate = InkBoundedDownloadDelegate(policy: request.securityPolicy)
      downloader.sessionDelegate = delegate
      downloader.sessionConfiguration = sessionConfiguration
      do {
        let image = try await downloader.downloadImage(with: request.source.requestURL,
          options: [.processor(processor), .scaleFactor(1)])
        try Task.checkCancellation()
        if let rejection = delegate.rejectionError { throw rejection }
        return image.image
      } catch {
        try Task.checkCancellation()
        if let rejection = delegate.rejectionError { throw rejection }
        throw error
      }
    case .file, .bundle:
      let url = request.source.scheme == .bundle
        ? URL(fileURLWithPath: request.source.requestURL.path) : request.source.requestURL
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= request.securityPolicy.maxResponseBytes else { throw ImageLoadError.payloadTooLarge(size) }
      let data = try Data(contentsOf: url, options: .mappedIfSafe)
      return try decode(data, processor: processor, options: options, limit: request.securityPolicy.maxResponseBytes)
    case .data:
      guard let payload = request.source.requestURL.absoluteString.split(separator: ",", maxSplits: 1).last,
            payload.utf8.count <= request.securityPolicy.maxResponseBytes,
            let data = Data(base64Encoded: String(payload)) else { throw ImageLoadError.invalidBase64 }
      return try decode(data, processor: processor, options: options, limit: request.securityPolicy.maxResponseBytes)
    case .asset:
      let name = request.source.requestURL.host ?? request.source.requestURL.lastPathComponent
      guard let image = UIImage(named: name) else {
        throw ImageLoadError.assetNotFound(name)
      }
      return try downsampleAsset(image, maxPixelWidth: width)
    default: throw ImageLoadError.unsupportedScheme
    }
  }

  nonisolated static func downsampleAsset(_ image: UIImage, maxPixelWidth: CGFloat) throws -> UIImage {
    // Kingfisher 以点尺寸乘 scale 计算像素预算；保留 Asset 原始密度，避免点尺寸被放大。
    let pointLimit = maxPixelWidth / image.scale
    let processor = DownsamplingImageProcessor(size: CGSize(width: pointLimit, height: pointLimit))
    let options = KingfisherParsedOptionsInfo([.scaleFactor(image.scale)])
    guard let output = processor.process(item: .image(image), options: options) else {
      throw ImageLoadError.decodeFailed
    }
    return output
  }

  nonisolated private static func decode(_ data: Data, processor: DownsamplingImageProcessor,
                                         options: KingfisherParsedOptionsInfo, limit: Int) throws -> UIImage {
    guard data.count <= limit else { throw ImageLoadError.payloadTooLarge(data.count) }
    guard let image = processor.process(item: .data(data), options: options) else { throw ImageLoadError.decodeFailed }
    return image
  }
}
