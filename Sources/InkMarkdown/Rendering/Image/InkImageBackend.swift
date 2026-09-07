import UIKit

/// 一次完整的图片请求。生成器只负责生图，缓存与调度由后端统一拥有。
public struct InkImageRequest: Sendable {
  /// 规范化图片来源。
  public let source: ImageSource
  /// 目标解码尺寸与显示比例。
  public let display: DisplayContext
  /// 后端必须遵循的来源与传输限制。
  public let securityPolicy: ImageSecurityPolicy
  /// 生成图的生产者；普通图片为 nil。
  public let generator: (any InkImageLoading)?
  /// 生成器的语义身份，参与缓存隔离。
  public let generatorIdentity: InkSemanticIdentity?

  /// 构造请求；宿主不得在同一语义身份下改变生成器行为。
  public init(source: ImageSource, display: DisplayContext,
              securityPolicy: ImageSecurityPolicy = .init(),
              generator: (any InkImageLoading)? = nil,
              generatorIdentity: InkSemanticIdentity? = nil) {
    self.source = source
    self.display = display
    self.securityPolicy = securityPolicy
    self.generator = generator
    self.generatorIdentity = generatorIdentity ?? generator?.semanticIdentity ?? (generator == nil ? nil : .unique())
  }

  /// 无歧义、跨进程稳定的缓存键；包含来源、实际尺寸、生成器及安全策略。
  public var cacheKey: String {
    let p = securityPolicy
    let parts = [source.canonicalID, String(Double(display.maxPixelWidth)),
      String(Double(display.scale)), String(describing: display.contentMode),
      generatorIdentity?.rawValue ?? "", p.allowedSchemes.map { String(describing: $0) }.sorted().joined(separator: ","),
      p.allowedHosts.sorted().joined(separator: ","), String(p.maxRedirects), String(p.maxResponseBytes),
      String(p.stripsQuery), String(p.stripsFragment), String(p.redirectRevalidatesHost),
      String(describing: p.emptyHostPolicy)]
    return parts.map { "\($0.utf8.count):\($0)" }.joined()
  }
}

/// 可替换的完整图片管理接口。核心不会在该接口外再缓存或合并请求。
///
/// 后端拥有下载、解码、缓存、并发限制及请求合并；取消一个调用只释放该调用的
/// 订阅，最后一个调用取消后才可取消共享任务。生成图通过 request.generator 生产。
/// 切换配置不会清空后端缓存。鉴权或租户改变时应创建独立后端实例。
@MainActor
public protocol InkImageBackend: AnyObject, Sendable {
  /// 同步查询已解码的内存缓存；不得执行阻塞 I/O。未命中返回 nil。
  func cachedImage(for request: InkImageRequest) -> UIImage?
  /// 获取图片；处理 Task 取消并传播失败，遵守请求中的资源与来源限制。
  func image(for request: InkImageRequest) async throws -> UIImage
}

public extension InkImageBackend {
  /// 不提供同步内存命中的后端可使用此默认实现。
  func cachedImage(for request: InkImageRequest) -> UIImage? { nil }
}
