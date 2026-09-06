import UIKit

/// 管理闭包式 NotificationCenter 观察者生命周期。
///
/// center 与 token 创建后均不可变；`deinit` 只执行线程安全的 observer 移除，因此可跨
/// actor 释放，而不访问 ``InkImageStore`` 的主 actor 状态。
final class InkNotificationObserverToken: @unchecked Sendable {
  private let center: NotificationCenter
  private let token: any NSObjectProtocol

  init(center: NotificationCenter, token: any NSObjectProtocol) {
    self.center = center
    self.token = token
  }

  deinit {
    center.removeObserver(token)
  }
}

/// 图片渲染的核心状态管理器：内存缓存、并发加载与订阅通知。
///
/// 同一 `canonicalID` 的并发请求合并为单次加载；超出并发上限的请求进入待处理队列。
/// 所有公开 API 须在主线程（``@MainActor``）调用。
@MainActor
public final class InkImageStore {

  // MARK: - 配置

  /// 图片 Store 的运行时配置。
  public struct Configuration: Sendable, Equatable, Hashable {
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

  /// 进程内共享的兼容 Store。
  ///
  /// 默认 block / attachment 渲染路径使用 ``defaultStore(for:)``，因此不会读取或改写
  /// 此实例。需要沿用 0.0.1 全局 Store 语义的宿主可显式注入 ``shared``。
  @MainActor public static let shared = InkImageStore()

  /// 默认 Store 的弱注册项；实际所有权由 block、attachment 或宿主持有。
  private final class DefaultStoreRegistration {
    weak var store: InkImageStore?

    init(store: InkImageStore) {
      self.store = store
    }
  }

  /// 默认渲染路径按完整缓存 / 调度配置隔离 Store。
  ///
  /// 显式注入的 Store 不经过此注册表，也不会被渲染块暗中改写；调用方拥有其配置。
  /// 注册表只保留弱引用，宿主释放 Store 后对应配置会在下一次查找时被清除。
  @MainActor private static var defaultStores: [Configuration: DefaultStoreRegistration] = [:]

  /// 返回指定渲染配置的默认 Store。
  ///
  /// 相同完整配置复用同一默认 Store；不同配置获得独立预算和调度状态，避免不同宿主
  /// 按调用顺序互相覆盖。调用方须持有返回值或把它注入实际宿主；否则 Store 释放后，
  /// 下一次查找会创建新的实例。公开 ``shared`` 仅作为旧 API 的显式 Store 入口，
  /// 不参与该池。
  @MainActor
  public static func defaultStore(for rendering: InkImageRendering) -> InkImageStore {
    let configuration = rendering.storeConfiguration
    // 配置对象可能来自动态宿主；每次查找顺便清理已释放的弱注册项，避免配置数量
    // 无界增长，同时不凭 hash 合并不同 Configuration。
    defaultStores = defaultStores.filter { $0.value.store != nil }
    if let registered = defaultStores[configuration]?.store {
      if registered.configuration == configuration {
        return registered
      }
      // The Store owner may have explicitly reconfigured a previously returned default
      // instance. It no longer represents this registry key, so do not return it for the
      // old configuration.
      defaultStores.removeValue(forKey: configuration)
    }
    let store = InkImageStore(configuration: configuration)
    defaultStores[configuration] = DefaultStoreRegistration(store: store)
    return store
  }

  // MARK: - 缓存

  private let cache = NSCache<NSString, UIImage>()

  // MARK: - Inflight（按 sourceID + DisplayKey 合并）

  private struct InflightLoad {
    let id: UUID
    let task: Task<UIImage, Error>
  }

  private var inflight: [NSString: InflightLoad] = [:]
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

  /// 把配置层 identity 带到 Store 的既有 loader seam；不扩大 `resolve` 的公开 interface。
  private struct SemanticIdentityImageLoaderAdapter: InkImageLoading {
    let base: any InkImageLoading
    let semanticIdentity: InkSemanticIdentity?

    func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
      try await base.loadImage(source: source, display: display)
    }
  }

  // MARK: - 订阅

  private var subscribers: [NSString: [(id: UUID, callback: (UIImage?) -> Void)]] = [:]

  /// 按安全策略复用的内置 URLSession 加载器，避免 renderer / block 各自创建 session。
  private var defaultLoaders: [ImageSecurityPolicy: DefaultURLSessionImageLoader] = [:]
  private var memoryWarningObserver: InkNotificationObserverToken?

  /// 图片加载订阅句柄；调用 ``cancel`` 可取消回调。
  public struct ImageLoadSubscription {
    /// 取消订阅，不再接收加载完成通知。
    public let cancel: () -> Void
  }

  // MARK: - Init

  /// 使用指定配置创建 Store。
  public convenience init(configuration: Configuration = .init()) {
    self.init(configuration: configuration, notificationCenter: .default)
  }

  /// 内部可注入通知中心，使 observer 生命周期可被确定性验证。
  init(configuration: Configuration = .init(), notificationCenter: NotificationCenter) {
    self.configuration = configuration
    applyConfiguration(configuration)

    let token = notificationCenter.addObserver(
      forName: UIApplication.didReceiveMemoryWarningNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.cache.removeAllObjects()
      }
    }
    memoryWarningObserver = InkNotificationObserverToken(center: notificationCenter, token: token)
  }

  /// 更新运行时配置（含共享单例）。变更立即作用于缓存与并发上限。
  public func updateConfiguration(_ config: Configuration) {
    configuration = config
    applyConfiguration(config)
    // 提升上限或释放运行中任务后，立即接管已接受的 FIFO 请求；缩容不取消
    // 已运行任务，也不丢弃已接受请求。新请求仍由 resolve 按新 pending 上限拒绝。
    drainPendingLoads()
  }

  /// 将 ``InkImageRendering/storeConfiguration`` 应用到 Store。
  ///
  /// 这是 Store owner 的显式配置操作。图片块、attachment 和预览不会隐式调用此方法，
  /// 因而不会把某一份 rendering 的预算写入另一个宿主持有的 Store；默认渲染路径使用
  /// ``defaultStore(for:)`` 在创建时固化完整配置。
  public func prepareForRendering(_ rendering: InkImageRendering) {
    updateConfiguration(rendering.storeConfiguration)
  }

  /// 获取渲染配置对应的加载器：自定义 loader 优先，否则复用 Store 持有的默认实例。
  public func loader(for rendering: InkImageRendering, source: ImageSource? = nil) -> InkImageLoading {
    if let generatedRequest = source?.generatedRequest {
      let loader = rendering.generatedLoader ?? MissingGeneratedImageLoader(owner: generatedRequest.owner)
      return loaderWithResolvedIdentity(loader, rendering: rendering, source: source)
    }
    if let custom = rendering.loader {
      return loaderWithResolvedIdentity(custom, rendering: rendering, source: source)
    }
    let policy = rendering.securityPolicy
    if let cached = defaultLoaders[policy] {
      return cached
    }
    let loader = DefaultURLSessionImageLoader(securityPolicy: policy)
    defaultLoaders[policy] = loader
    return loader
  }

  private func loaderWithResolvedIdentity(
    _ loader: any InkImageLoading,
    rendering: InkImageRendering,
    source: ImageSource?
  ) -> any InkImageLoading {
    guard loader.semanticIdentity == nil,
          let identity = rendering.resolvedLoaderSemanticIdentity(for: loader, source: source) else {
      return loader
    }
    return SemanticIdentityImageLoaderAdapter(base: loader, semanticIdentity: identity)
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
    let key = DisplayKey(source: source, display: display, loader: loader)

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
    let loadID = UUID()
    let task = Task.detached { [weak self] in
      do {
        let image = try await loader.loadImage(source: source, display: display)
        // 自定义 loader 可能忽略取消；旧 generation 绝不能写缓存或覆盖新请求。
        try Task.checkCancellation()
        await self?.finishLoadSuccess(
          cacheKey: key.cacheKey,
          loadID: loadID,
          image: image
        )
        return image
      } catch {
        await self?.finishLoadFailure(
          cacheKey: key.cacheKey,
          loadID: loadID,
          error: error
        )
        throw error
      }
    }
    inflight[key.cacheKey] = InflightLoad(id: loadID, task: task)
  }

  private func finishLoadSuccess(
    cacheKey: NSString,
    loadID: UUID,
    image: UIImage
  ) {
    guard inflight[cacheKey]?.id == loadID else { return }
    cache.setObject(image, forKey: cacheKey, cost: image.memoryCost)
    broadcast(cacheKey: cacheKey, image: image)
    subscribers.removeValue(forKey: cacheKey)
    completeLoad(cacheKey: cacheKey, loadID: loadID)
  }

  private func finishLoadFailure(
    cacheKey: NSString,
    loadID: UUID,
    error: Error
  ) {
    guard inflight[cacheKey]?.id == loadID else { return }
    broadcastFailure(cacheKey: cacheKey, error: error)
    completeLoad(cacheKey: cacheKey, loadID: loadID)
  }

  private func completeLoad(cacheKey: NSString, loadID: UUID) {
    guard inflight[cacheKey]?.id == loadID else { return }
    inflight.removeValue(forKey: cacheKey)
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
      self.dropLoadIfUnsubscribed(cacheKey: cacheKey)
    })
  }

  /// 最后一个订阅消失时：移除排队项；若 inflight 已无订阅者则取消底层任务（ADR-006）。
  private func dropLoadIfUnsubscribed(cacheKey: NSString) {
    guard subscribers[cacheKey]?.isEmpty != false else { return }
    subscribers.removeValue(forKey: cacheKey)
    removeQueuedLoad(cacheKey: cacheKey)
    guard let load = inflight.removeValue(forKey: cacheKey) else { return }
    activeCount = max(0, activeCount - 1)
    load.task.cancel()
    drainPendingLoads()
  }

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
