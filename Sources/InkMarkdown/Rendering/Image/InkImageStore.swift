import UIKit

/// 图片呈现协调器。仅桥接后端与视图订阅，不拥有缓存、队列或共享下载任务。
@MainActor
public final class InkImageStore {
  /// 创建无资源状态的呈现协调器。
  public init() {}

  /// 创建协调器；缓存共享由配置中的后端实例决定。
  public static func defaultStore(for rendering: InkImageRendering) -> InkImageStore { .init() }

  /// 构造绑定后端与生成器的请求入口，供预览及呈现通道复用。
  public func loader(for rendering: InkImageRendering, source: ImageSource? = nil) -> any InkImageLoading {
    InkBackendImageLoader(rendering: rendering)
  }

  /// 一个视图的订阅句柄。取消不会清空后端缓存或影响其他视图。
  public struct ImageLoadSubscription {
    /// 取消此订阅及其异步调用。
    public let cancel: () -> Void
  }

  /// 呈现查询结果；异步加载在注册订阅时启动。
  public enum ResolveResult {
    /// 内存命中。
    case ready(UIImage)
    /// 通过闭包注册加载完成通知。
    case loading(subscribe: (@escaping (UIImage?) -> Void) -> ImageLoadSubscription)
    /// 后端排队状态的呈现形式。
    case queued(subscribe: (@escaping (UIImage?) -> Void) -> ImageLoadSubscription)
    /// 来源被拒绝。
    case rejected(ImageRejectReason)
  }

  /// 取消后即使后端晚返回也不会通知旧视图。
  public func resolve(source: ImageSource, display: DisplayContext, loader: any InkImageLoading) -> ResolveResult {
    if let bound = loader as? InkBackendImageLoader,
       let image = bound.cachedImage(source: source, display: display) {
      return .ready(image)
    }
    return .loading { callback in
      let task = Task { @MainActor in
        do {
          let image = try await loader.loadImage(source: source, display: display)
          guard !Task.isCancelled else { return }
          callback(image)
        } catch {
          guard !Task.isCancelled else { return }
          callback(nil)
        }
      }
      return ImageLoadSubscription(cancel: { task.cancel() })
    }
  }
}

private struct InkBackendImageLoader: InkImageLoading {
  let rendering: InkImageRendering
  var semanticIdentity: InkSemanticIdentity? { rendering.backendIdentity }

  private func request(source: ImageSource, display: DisplayContext) -> InkImageRequest {
    InkImageRequest(source: source, display: display, securityPolicy: rendering.securityPolicy,
      generator: source.generatedRequest == nil ? nil : rendering.generatedLoader,
      generatorIdentity: rendering.generatedLoader.flatMap {
        rendering.resolvedLoaderSemanticIdentity(for: $0, source: source)
      })
  }

  @MainActor
  func cachedImage(source: ImageSource, display: DisplayContext) -> UIImage? {
    guard source.generatedRequest != nil || rendering.securityPolicy.rejectionReason(
      for: source, maxDataURLBytes: rendering.maxDataURLBytes) == nil else { return nil }
    return rendering.backend?.cachedImage(for: request(source: source, display: display))
  }

  func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    do {
      guard source.generatedRequest != nil || rendering.securityPolicy.rejectionReason(
        for: source, maxDataURLBytes: rendering.maxDataURLBytes) == nil else {
        throw ImageLoadError.sourceRejected
      }
      guard let backend = rendering.backend else { throw ImageLoadError.backendNotConfigured }
      let image = try await backend.image(for: request(source: source, display: display))
      try Task.checkCancellation()
      return image
    } catch {
      if !Task.isCancelled {
        await MainActor.run {
          guard !Task.isCancelled else { return }
          rendering.onFailure?(source, error)
        }
      }
      throw error
    }
  }
}
