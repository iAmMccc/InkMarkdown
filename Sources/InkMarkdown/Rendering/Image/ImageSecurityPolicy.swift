/// 图片加载的安全与 URL 规范化策略。
public struct ImageSecurityPolicy: Sendable {

  /// 允许加载的 URL scheme 集合。
  public var allowedSchemes: Set<ImageSource.ImageScheme> = [.http, .https, .file, .asset, .bundle]

  /// 允许的主机白名单；空集时行为由 `emptyHostPolicy` 控制
  /// - `.rejectAll`（默认）：空集 = 拒绝所有 HTTP(S) 主机（fail-closed）
  /// - `.allowAll`：空集 = 允许所有主机
  public var allowedHosts: Set<String> = []

  /// 生成 `canonicalID` 时是否剥离 query 组件。
  public var stripsQuery: Bool = true

  /// 生成 `canonicalID` 时是否剥离 fragment 组件。
  public var stripsFragment: Bool = true

  /// 允许的最大 HTTP 重定向次数。
  public var maxRedirects: Int = 3

  /// 重定向后是否重新校验目标主机是否在白名单内。
  public var redirectRevalidatesHost: Bool = true

  /// 空主机名（相对 URL 或未指定 host）的处理策略。
  public var emptyHostPolicy: EmptyHostPolicy = .rejectAll

  /// 相对 URL 或无 host 远程 URL 的处理方式。
  public enum EmptyHostPolicy: Sendable {
    /// 拒绝所有空 host 请求。
    case rejectAll
    /// 允许空 host（通常配合 `baseURL` 解析相对路径）。
    case allowAll
  }

  public init() {}
}
