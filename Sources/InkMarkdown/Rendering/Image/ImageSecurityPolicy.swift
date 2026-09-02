import Foundation

/// 图片加载的安全与 URL 规范化策略。
///
/// 本类型聚合两类边界（术语见 ADR-006）：
/// - **图片业务策略**（宿主可选）：``allowedHosts`` 域名白名单。空集表示
///   「宿主未配置业务来源限制」，默认放行所有有效 HTTP(S) host；
///   显式配置后，非白名单 host 被拒绝。库不把业务来源限制设为使用图片能力的前置条件。
/// - **图片资源安全边界**（始终生效）：scheme 白名单、重定向限制、query/fragment
///   规范化与响应大小上限。这些与业务来源无关，宿主不可关闭。
public struct ImageSecurityPolicy: Sendable, Hashable {

  /// 允许加载的 URL scheme 集合（资源安全边界，始终生效）。
  public var allowedSchemes: Set<ImageSource.ImageScheme> = [.http, .https, .file, .asset, .bundle]

  /// 允许的 host 白名单（图片业务策略，宿主可选配置）。
  ///
  /// - 空集（默认）：视为「未配置业务限制」，允许所有满足资源安全边界的 HTTP(S) host；
  ///   具体放行行为由 ``emptyHostPolicy`` 决定（默认 `.allowAll`）。
  /// - 非空集：仅允许集合内的 host，其余 host 返回 `ImageRejectReason.hostNotAllowed`。
  public var allowedHosts: Set<String> = []

  /// 是否从实际请求地址（``ImageSource/requestURL``）与 `canonicalID` 中剥离 query 组件。
  ///
  /// 默认 `false`：query 默认保留，以兼容带签名或尺寸参数的 URL（如 `?token=...`）；
  /// 同一规范化规则同时作用于网络请求 URL 与缓存键。开启后两者同时剥离。
  /// 在 AI / LLM 场景需防范 prompt-injection 经 query 外泄数据时，建议显式设为 `true`
  /// （host allowlist 仍是主防线）。
  public var stripsQuery: Bool = false

  /// 是否从实际请求地址（``ImageSource/requestURL``）与 `canonicalID` 中剥离 fragment 组件。
  ///
  /// 默认 `true`：fragment 不参与实际请求与缓存身份，避免无意义重复缓存；
  /// 规范化规则同样同时作用于请求与缓存键。
  public var stripsFragment: Bool = true

  /// 允许的最大 HTTP 重定向次数（资源安全边界）。
  ///
  /// 默认 3 次：支持常见 CDN 重定向，同时避免无限跳转。超限后加载失败，使用既有 fallback。
  public var maxRedirects: Int = 3

  /// 网络响应允许的最大字节数（资源安全边界，始终生效）。
  ///
  /// 默认 20 MiB。该上限是库对所有图片加载统一执行的资源保护，不是图片业务策略：
  /// 超限响应在完整载入和解码前安全失败（优先依据 `Content-Length` 预判，
  /// 否则在累计字节数越限时取消请求），加载失败后走既有 fallback，不写入缓存。
  public var maxResponseBytes: Int = 20 * 1024 * 1024

  /// 每次重定向后是否重新校验目标 host（资源安全边界）。
  ///
  /// 默认 `true`。为了兼容既有配置保留该开关；宿主配置了非空 host 白名单时，
  /// 无论本值为何都必须重新校验，业务来源限制不能通过 redirect 绕过。
  /// 未配置白名单时，本值只控制是否重复执行空白名单策略。
  public var redirectRevalidatesHost: Bool = true

  /// `allowedHosts` 为空集时的放行策略（图片业务策略的默认值）。
  ///
  /// - `.allowAll`（默认）：空集 = 允许所有有效 HTTP(S) host——开启真图渲染后开箱可用。
  /// - `.rejectAll`：空集 = 拒绝所有 HTTP(S) host（fail-closed），供需要显式 opt-in
  ///   业务来源的宿主选择。
  /// 非空 ``allowedHosts`` 时本字段不参与判定，白名单始终生效。
  public var emptyHostPolicy: EmptyHostPolicy = .allowAll

  /// `allowedHosts` 空集时的处理策略。
  ///
  /// 注意：本策略约束的是「白名单未配置」这一状态，而不是「URL 的 host 为空」；
  /// 相对 URL 与 `baseURL` 解析由 ``InkImageRendering/baseURL`` 负责。
  public enum EmptyHostPolicy: Sendable {
    /// 拒绝所有 HTTP(S) host（fail-closed）。
    case rejectAll
    /// 允许所有有效 HTTP(S) host（v0.0.2 默认；ADR-006 业务策略默认开放）。
    case allowAll
  }

  public init() {}
}

// MARK: - 共享策略判定

extension ImageSecurityPolicy {

  /// 对规范化后的图片来源执行唯一的资源安全与 host 业务策略判定。
  ///
  /// renderer、Block 路由和 URLSession 重定向都通过此 seam 判定，避免策略演进时
  /// 各通道产生不同结果。`maxDataURLBytes` 由 Store 配置提供；非 Data URL 可传 `nil`。
  func rejectionReason(
    for source: ImageSource,
    maxDataURLBytes: Int? = nil
  ) -> ImageRejectReason? {
    guard allowedSchemes.contains(source.scheme) else {
      return .schemeNotAllowed(String(describing: source.scheme))
    }

    if source.scheme == .http || source.scheme == .https {
      guard let host = source.requestURL.host, !host.isEmpty else {
        return .invalidURL(source.requestURL.absoluteString)
      }
      if let reason = hostRejectionReason(for: host) {
        return reason
      }
    }

    if source.scheme == .data,
       let maxDataURLBytes,
       source.requestURL.absoluteString.utf8.count > maxDataURLBytes {
      return .payloadTooLarge(source.requestURL.absoluteString.utf8.count)
    }

    return nil
  }

  /// 对 HTTP 重定向目标执行 scheme 与 host 复核。
  ///
  /// HTTP 会话只接受 HTTP(S) 跳转。配置了非空白名单时始终复核 host；空白名单时
  /// `redirectRevalidatesHost` 仅决定是否重复执行 `.allowAll` / `.rejectAll` 规则。
  func rejectionReason(forRedirectURL url: URL) -> ImageRejectReason? {
    let source = ImageSource(
      url: url,
      stripsQuery: stripsQuery,
      stripsFragment: stripsFragment
    )
    guard source.scheme == .http || source.scheme == .https else {
      return .schemeNotAllowed(String(describing: source.scheme))
    }
    guard allowedSchemes.contains(source.scheme) else {
      return .schemeNotAllowed(String(describing: source.scheme))
    }
    guard let host = source.requestURL.host, !host.isEmpty else {
      return .invalidURL(source.requestURL.absoluteString)
    }
    guard redirectRevalidatesHost || !allowedHosts.isEmpty else {
      return nil
    }
    return hostRejectionReason(for: host)
  }

  private func hostRejectionReason(for host: String) -> ImageRejectReason? {
    if allowedHosts.isEmpty {
      return emptyHostPolicy == .rejectAll ? .hostNotAllowed(host) : nil
    }
    return allowedHosts.contains(host) ? nil : .hostNotAllowed(host)
  }
}
