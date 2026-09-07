import UIKit

/// 单个呈现所有者对 ``InkImageStore`` 的一次观察生命周期。
///
/// 不拥有缓存/预算，不设置默认 Store；由调用方注入 Store 与 loader。
/// 负责 generation 作废、订阅安装顺序、过期结果抑制与一次终结。
@MainActor
final class InkImagePresentationLoad {
  enum Completion: Equatable {
    case image(UIImage)
    case loadFailed
    case rejected
  }

  private var generation = UUID()
  private var subscription: InkImageStore.ImageLoadSubscription?
  /// 强持有注入的 Store，直到本次观察终止。
  private var retainedStore: InkImageStore?
  private var hasActiveObservation = false

  /// 启动或替换一次观察。总会先作废并取消前一次观察。
  ///
  /// - Important: 不要同时传入 Store 的 `onLoad`；本类型只用 `subscribe` 路径。
  func start(
    source: ImageSource,
    display: DisplayContext,
    loader: InkImageLoading,
    store: InkImageStore,
    onPending: (() -> Void)? = nil,
    onCompletion: @escaping (Completion) -> Void
  ) {
    let observation = UUID()
    generation = observation
    let previous = subscription
    subscription = nil
    previous?.cancel()

    retainedStore = store
    hasActiveObservation = true

    let result = store.resolve(source: source, display: display, loader: loader)

    switch result {
    case .ready(let image):
      deliver(.image(image), observation: observation, onCompletion: onCompletion)

    case .loading(let subscribe), .queued(let subscribe):
      let installed = subscribe { [weak self] image in
        // Store 广播栈上只安排后续 MainActor turn，避免重入 resolve/cancel。
        Task { @MainActor [weak self] in
          guard let self else { return }
          guard self.generation == observation else { return }
          let completion: Completion = image.map(Completion.image) ?? .loadFailed
          self.deliver(completion, observation: observation, onCompletion: onCompletion)
        }
      }

      // 同步终结或重入作废后不得写回旧句柄。
      guard generation == observation else {
        installed.cancel()
        return
      }
      subscription = installed

      onPending?()

      // onPending 可能同步 cancel/start；失效后不得把旧 subscription 写回。
      if generation != observation {
        return
      }

    case .rejected:
      deliver(.rejected, observation: observation, onCompletion: onCompletion)
    }
  }

  /// 作废当前观察并取消底层订阅。不向呈现层外发失败。
  func cancel() {
    generation = UUID()
    hasActiveObservation = false
    let active = subscription
    subscription = nil
    active?.cancel()
    retainedStore = nil
  }

  deinit {
    subscription?.cancel()
  }

  private func deliver(
    _ completion: Completion,
    observation: UUID,
    onCompletion: @escaping (Completion) -> Void
  ) {
    guard generation == observation, hasActiveObservation else { return }
    hasActiveObservation = false
    let active = subscription
    subscription = nil
    active?.cancel()
    retainedStore = nil
    // 先清理本观察终态，再外发；允许 completion 内同步 start 新请求。
    onCompletion(completion)
  }
}

/// async 等待 Store 观察的一次终结；不另建 resolve 分支。
enum InkImagePresentationAsyncError: Error {
  case rejected
}

@MainActor
enum InkImagePresentationLoadAsync {
  /// 等待一次 Store 观察结果。取消映射为 `CancellationError`；`rejected` / nil 失败分别映射。
  static func loadImage(
    source: ImageSource,
    display: DisplayContext,
    loader: InkImageLoading,
    store: InkImageStore
  ) async throws -> UIImage {
    let session = Session()
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
        session.install(continuation)
        guard !session.hasFinished else { return }
        session.load.start(
          source: source,
          display: display,
          loader: loader,
          store: store,
          onCompletion: { completion in
            switch completion {
            case .image(let image):
              session.finish(.success(image))
            case .loadFailed:
              session.finish(.failure(ImageLoadError.decodeFailed))
            case .rejected:
              session.finish(.failure(InkImagePresentationAsyncError.rejected))
            }
          }
        )
      }
    } onCancel: {
      Task { @MainActor in
        session.cancel()
      }
    }
  }

  @MainActor
  private final class Session {
    let load = InkImagePresentationLoad()
    private var continuation: CheckedContinuation<UIImage, Error>?
    private(set) var hasFinished = false

    func install(_ continuation: CheckedContinuation<UIImage, Error>) {
      guard !hasFinished else {
        continuation.resume(throwing: CancellationError())
        return
      }
      self.continuation = continuation
      if Task.isCancelled {
        finish(.failure(CancellationError()))
      }
    }

    func finish(_ result: Result<UIImage, Error>) {
      guard !hasFinished else { return }
      hasFinished = true
      load.cancel()
      let continuation = self.continuation
      self.continuation = nil
      switch result {
      case .success(let image):
        continuation?.resume(returning: image)
      case .failure(let error):
        continuation?.resume(throwing: error)
      }
    }

    func cancel() {
      finish(.failure(CancellationError()))
    }
  }
}
