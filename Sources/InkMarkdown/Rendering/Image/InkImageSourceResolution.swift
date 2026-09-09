import Foundation

/// Markdown 图片 source → ``ImageSource`` 的统一解析入口（行内与块级通道共用）。
///
/// 解析规则（ADR-006 相对 URL 契约）：
/// - 带 scheme 的地址按原样使用（scheme 分类由 ``ImageSource`` 完成）；
/// - 无 scheme 的相对地址：提供 ``InkImageRendering/baseURL`` 时解析为**确定**的绝对
///   请求 URL；未提供时返回 `.rejected(.noBaseURL)`——调用方按既有占位契约呈现，库不猜测来源。
enum InkImageSourceResolution {

  /// 已解析为确定来源。
  case resolved(ImageSource)
  /// 来源被拒绝；调用方按既有占位 / fallback 契约呈现。
  case rejected(ImageRejectReason)

  /// 从 Markdown 图片 source 字符串解析为明确结果。
  static func resolve(from urlString: String, rendering: InkImageRendering) -> InkImageSourceResolution {
    guard let raw = URL(string: urlString) else {
      return .rejected(.invalidURL(urlString))
    }

    if let scheme = raw.scheme, !scheme.isEmpty {
      return .resolved(makeSource(url: raw, rendering: rendering))
    }

    // 无 scheme：相对地址（或无法归类的裸路径）。只有显式提供 baseURL 才解析。
    guard let base = rendering.baseURL,
          let joined = URL(string: urlString, relativeTo: base),
          let absolute = URL(string: joined.absoluteString) else {
      return .rejected(.noBaseURL)
    }
    return .resolved(makeSource(url: absolute, rendering: rendering))
  }

  private static func makeSource(url: URL, rendering: InkImageRendering) -> ImageSource {
    ImageSource(
      url: url,
      stripsQuery: rendering.securityPolicy.stripsQuery,
      stripsFragment: rendering.securityPolicy.stripsFragment
    )
  }
}
