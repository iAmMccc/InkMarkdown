import UIKit

/// 图片渲染的核心状态管理器：内存缓存、并发加载与订阅通知。
///
/// 同一 `canonicalID` 的并发请求合并为单次加载；超出并发上限的请求进入待处理队列。
/// 所有公开 API 须在主线程（``@MainActor``）调用。
@MainActor
public final class InkImageStore {

  // MARK: - 配置

  /// 图片 Store 的运行时配置。
  public struct Configuration: Sendable, Equatable {
    /// 内存缓存总字节上限。
    public var totalCostLimit: Int = 60 * 1024 * 1024
    /// 内存缓存条目数上限。
    public var countLimit: Int = 100
    /// 同时进行中的加载任务数上限。
    public var maxConcurrentLoads: Int = 4
    /// 等待队列最大条目数，防止慢速 loader 下无限积压。
    public var maxPendingLoads: Int = 32
    /// Data URL 允许的最大编码字节数（供 loader 校验参考）。
    public var maxDataURLBytes: Int = 2 * 1024 * 1024

    public init() {}
  }

  /// 当前生效的配置。
  public private(set) var configuration: Configuration

  /// 进程内共享的默认 Store，供块级 / 行内图片通道在未注入实例时使用。
  @MainActor public static let shared = InkImageStore()

  // MARK: - 缓存

  private let cache = NSCache<NSString, UIImage>()

  // MARK: - Inflight（按 sourceID + DisplayKey 合并）

  private var inflight: [NSString: Task<UIImage, Error>] = [:]
  private var activeCount: Int = 0
  private var pendingLoads: [PendingLoad] = []

  private struct PendingLoad {
    let source: ImageSource
    let display: DisplayContext
    let loader: InkImageLoading
    let key: DisplayKey
  }

  /// 生成 source 缺少专用 renderer 时的安全哨兵。禁止落入 URLSession loader。
  private struct MissingGeneratedImageLoader: InkImageLoading {
    let owner: String

    func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
      throw ImageLoadError.generatedLoaderUnavailable(owner: owner)
    }
  }

  // MARK: - 订阅

  private var subscribers: [NSString: [(id: UUID, callback: (UIImage?) -> Void)]] = [:]

  /// 按安全策略复用的内置 URLSession 加载器，避免 renderer / block 各自泄漏 session。
  private var defaultLoaders: [ImageSecurityPolicy: DefaultURLSessionImageLoader] = [:]

  /// 图片加载订阅句柄；调用 ``cancel`` 可取消回调。
  public struct ImageLoadSubscription {
    /// 取消订阅，不再接收加载完成通知。
    public let cancel: () -> Void
  }

  // MARK: - Init

  /// 使用指定配置创建 Store。
  public init(configuration: Configuration = .init()) {
    self.configuration = configuration
    applyConfiguration(configuration)

    NotificationCenter.default.addObserver(
      forName: UIApplication.didReceiveMemoryWarningNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.cache.removeAllObjects()
      }
    }
  }

  /// 更新运行时配置（含共享单例）。变更立即作用于缓存与并发上限。
  public func updateConfiguration(_ config: Configuration) {
    configuration = config
    applyConfiguration(config)
  }

  /// 将 ``InkImageRendering/storeConfiguration`` 应用到 Store，并在解析前调用。
  ///
  /// 缓存与 data URL 上限始终跟随 rendering；并发上限仅在 rendering 显式偏离默认值时覆盖，
  /// 避免 ``configure(containerWidth:loader:)`` 把注入 Store 的 tight limit 重置为默认 4/32。
  public func prepareForRendering(_ rendering: InkImageRendering) {
    var merged = configuration
    let incoming = rendering.storeConfiguration
    let defaults = Configuration()
    merged.totalCostLimit = incoming.totalCostLimit
    merged.countLimit = incoming.countLimit
    merged.maxDataURLBytes = incoming.maxDataURLBytes
    if incoming.maxConcurrentLoads != defaults.maxConcurrentLoads {
      merged.maxConcurrentLoads = incoming.maxConcurrentLoads
    }
    if incoming.maxPendingLoads != defaults.maxPendingLoads {
      merged.maxPendingLoads = incoming.maxPendingLoads
    }
    updateConfiguration(merged)
  }

  /// 获取渲染配置对应的加载器：自定义 loader 优先，否则复用 Store 持有的默认实例。
  public func loader(for rendering: InkImageRendering, source: ImageSource? = nil) -> InkImageLoading {
    if let generatedRequest = source?.generatedRequest {
      return rendering.generatedLoader ?? MissingGeneratedImageLoader(owner: generatedRequest.owner)
    }
    if let custom = rendering.loader {
      return custom
    }
    let policy = rendering.securityPolicy
    if let cached = defaultLoaders[policy] {
      return cached
    }
    let loader = DefaultURLSessionImageLoader(securityPolicy: policy)
    defaultLoaders[policy] = loader
    return loader
  }

  // MARK: - 核心 API

  /// 解析图片来源：命中缓存立即返回，否则启动或合并加载。
  ///
  /// - Parameters:
  ///   - source: 规范化后的图片来源。
  ///   - display: 目标显示上下文。
  ///   - loader: 实际执行解码的加载器。
  ///   - onLoad: 可选的加载完成回调；成功时传入图片，失败时传入 `nil`。
  /// - Returns: 就绪、加载中、排队或被拒绝的结果。
  public func resolve(
    source: ImageSource,
    display: DisplayContext,
    loader: InkImageLoading,
    onLoad: ((UIImage?) -> Void)? = nil
  ) -> ResolveResult {
    let key = DisplayKey(source: source, display: display)

    if let cached = cache.object(forKey: key.cacheKey) {
      return .ready(cached)
    }

    let subscribe = makeSubscribeClosure(cacheKey: key.cacheKey, onLoad: onLoad)

    if inflight[key.cacheKey] != nil {
      if let onLoad {
        _ = makeSubscription(cacheKey: key.cacheKey, callback: onLoad)
      }
      return .loading(subscribe: subscribe)
    }

    if pendingLoads.contains(where: { $0.key.cacheKey == key.cacheKey }) {
      if let onLoad {
        _ = makeSubscription(cacheKey: key.cacheKey, callback: onLoad)
      }
      return .queued(subscribe: subscribe)
    }

    guard activeCount < configuration.maxConcurrentLoads else {
      guard pendingLoads.count < max(0, configuration.maxPendingLoads) else {
        return .rejected(.pendingQueueFull(limit: max(0, configuration.maxPendingLoads)))
      }
      pendingLoads.append(PendingLoad(source: source, display: display, loader: loader, key: key))
      if let onLoad {
        _ = makeSubscription(cacheKey: key.cacheKey, callback: onLoad)
      }
      return .queued(subscribe: subscribe)
    }

    startLoad(source: source, display: display, loader: loader, key: key)
    if let onLoad {
      _ = makeSubscription(cacheKey: key.cacheKey, callback: onLoad)
    }
    return .loading(subscribe: subscribe)
  }

  /// ``resolve(source:display:loader:onLoad:)`` 的返回类型。
  public enum ResolveResult {
    /// 缓存命中，图片已就绪。
    case ready(UIImage)
    /// 正在加载；通过 `subscribe` 注册完成回调。
    case loading(subscribe: (@escaping (UIImage?) -> Void) -> ImageLoadSubscription)
    /// 并发已满，已加入待处理队列；通过 `subscribe` 注册完成回调。
    case queued(subscribe: (@escaping (UIImage?) -> Void) -> ImageLoadSubscription)
    /// 被安全策略拒绝（由上层在调用前校验后返回）。
    case rejected(ImageRejectReason)
  }

  // MARK: - 加载管理

  private func startLoad(
    source: ImageSource,
    display: DisplayContext,
    loader: InkImageLoading,
    key: DisplayKey
  ) {
    activeCount += 1
    let task = Task.detached { [weak self] in
      // 成功/失败路径在同一 MainActor 临界区写 cache 并清理 inflight，
      // 避免「cache 已就绪但 inflightCount 仍为 1」的观测窗口；
      // defer 仅兜底取消等未走到上述路径的情况。
      var completedOnMain = false
      defer {
        if !completedOnMain {
          Task { @MainActor [weak self] in
            self?.completeLoad(cacheKey: key.cacheKey)
          }
        }
      }
      do {
        let image = try await loader.loadImage(source: source, display: display)
        await MainActor.run { [weak self] in
          guard let self else { return }
          self.cache.setObject(image, forKey: key.cacheKey, cost: image.memoryCost)
          self.broadcast(cacheKey: key.cacheKey, image: image)
          self.subscribers.removeValue(forKey: key.cacheKey)
          self.completeLoad(cacheKey: key.cacheKey)
        }
        completedOnMain = true
        return image
      } catch {
        await MainActor.run { [weak self] in
          guard let self else { return }
          self.broadcastFailure(cacheKey: key.cacheKey, error: error)
          self.completeLoad(cacheKey: key.cacheKey)
        }
        completedOnMain = true
        throw error
      }
    }
    inflight[key.cacheKey] = task
  }

  private func completeLoad(cacheKey: NSString) {
    guard inflight.removeValue(forKey: cacheKey) != nil else { return }
    activeCount = max(0, activeCount - 1)
    drainPendingLoads()
  }

  private func drainPendingLoads() {
    while activeCount < configuration.maxConcurrentLoads, !pendingLoads.isEmpty {
      let pending = pendingLoads.removeFirst()
      if let cached = cache.object(forKey: pending.key.cacheKey) {
        broadcast(cacheKey: pending.key.cacheKey, image: cached)
        subscribers.removeValue(forKey: pending.key.cacheKey)
        continue
      }
      startLoad(
        source: pending.source,
        display: pending.display,
        loader: pending.loader,
        key: pending.key
      )
    }
  }

  // MARK: - 订阅管理

  private func makeSubscribeClosure(
    cacheKey: NSString,
    onLoad: ((UIImage?) -> Void)?
  ) -> (@escaping (UIImage?) -> Void) -> ImageLoadSubscription {
    { [weak self] callback in
      self?.makeSubscription(cacheKey: cacheKey, callback: callback)
        ?? ImageLoadSubscription(cancel: {})
    }
  }

  private func makeSubscription(
    cacheKey: NSString,
    callback: @escaping (UIImage?) -> Void
  ) -> ImageLoadSubscription {
    let id = UUID()
    if subscribers[cacheKey] == nil {
      subscribers[cacheKey] = []
    }
    subscribers[cacheKey]?.append((id: id, callback: callback))
    return ImageLoadSubscription(cancel: { [weak self] in
      guard let self else { return }
      self.subscribers[cacheKey]?.removeAll { $0.id == id }
      if self.subscribers[cacheKey]?.isEmpty != false {
        self.subscribers.removeValue(forKey: cacheKey)
        self.removeQueuedLoad(cacheKey: cacheKey)
      }
    })
  }

  /// 只有排队项可以因无人订阅取消；active/inflight 继续运行以便复用和写入缓存。
  private func removeQueuedLoad(cacheKey: NSString) {
    pendingLoads.removeAll { $0.key.cacheKey == cacheKey }
  }

  private func broadcast(cacheKey: NSString, image: UIImage) {
    guard let subs = subscribers[cacheKey] else { return }
    for sub in subs {
      sub.callback(image)
    }
  }

  private func broadcastFailure(cacheKey: NSString, error: Error) {
    guard let subs = subscribers[cacheKey] else { return }
    for sub in subs {
      sub.callback(nil)
    }
    subscribers.removeValue(forKey: cacheKey)
  }

  // MARK: - 配置应用

  private func applyConfiguration(_ config: Configuration) {
    cache.totalCostLimit = config.totalCostLimit
    cache.countLimit = config.countLimit
  }

  // MARK: - 公开工具

  /// 清除所有内存缓存。
  public func removeAllCachedImages() {
    cache.removeAllObjects()
  }

  /// 当前进行中的 inflight 任务数（测试用）。
  public var inflightCount: Int { inflight.count }

  /// 当前活跃加载数（测试用）。
  public var currentActiveCount: Int { activeCount }

  /// 当前等待队列长度（测试和诊断用）。
  public var pendingLoadCount: Int { pendingLoads.count }
}
