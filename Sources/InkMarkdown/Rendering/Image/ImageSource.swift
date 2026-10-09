import Foundation

/// Markdown 图片节点的规范化来源描述。
///
/// 将原始 URL 解析为 scheme 分类、实际请求 URL 与去重用的 `canonicalID`，供缓存键与安全策略共用。
public struct ImageSource: Hashable, Sendable {

  /// 原始 URL（Markdown 解析结果或经 `baseURL` 解析后的绝对地址）。
  public let rawURL: URL

  /// 按安全策略剥离 query / fragment 后用于网络与本地读取的实际 URL。
  ///
  /// Loader 与缓存键均以此为准，保证「请求什么就缓存什么」。
  public let requestURL: URL

  /// 根据 URL scheme 推导的来源类型。
  public let scheme: ImageScheme

  /// 规范化标识：与 ``requestURL`` 的 `absoluteString` 一致，用于缓存去重。
  public let canonicalID: String

  /// 本地生成图片的可重建请求；普通 URL 图片为 `nil`。
  public let generatedRequest: InkGeneratedImageRequest?

  /// 图片 URL 的 scheme 分类。
  public enum ImageScheme: Hashable, Sendable {
    case http
    case https
    case file
    case data
    case asset
    case bundle
    case relative
    case generated
    case unknown
  }

  /// 从 URL 构建图片来源，并生成请求 URL 与规范化 ID。
  ///
  /// 默认值与 ``ImageSecurityPolicy`` 的规范化默认一致：query 默认**保留**（兼容
  /// 签名 / 尺寸参数），fragment 默认剥离。同一规范化规则同时决定实际请求与缓存身份。
  ///
  /// - Parameters:
  ///   - url: 原始 URL。
  ///   - stripsQuery: 为 `true` 时从 ``requestURL`` 中移除 query 组件；默认 `false`。
  ///   - stripsFragment: 为 `true` 时从 ``requestURL`` 中移除 fragment 组件；默认 `true`。
  public init(url: URL, stripsQuery: Bool = false, stripsFragment: Bool = true) {
    self.rawURL = url
    self.scheme = Self.imageScheme(for: url)

    if stripsQuery || stripsFragment {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      if stripsQuery {
        components?.query = nil
      }
      if stripsFragment {
        components?.fragment = nil
      }
      // 相对 URL 可能没有 base，`url` 回退保证 requestURL 始终可用。
      self.requestURL = components?.url ?? url
    } else {
      self.requestURL = url
    }
    self.canonicalID = requestURL.absoluteString
    self.generatedRequest = nil
  }

  /// 创建由库内 renderer 生成的图片来源。
  ///
  /// 原文不会进入 URL 或缓存键；最终缓存键仍由 `canonicalID + DisplayKey` 组成。
  public init(generated request: InkGeneratedImageRequest) {
    self.rawURL = URL(string: request.stableID)!
    self.requestURL = rawURL
    self.scheme = .generated
    self.canonicalID = request.stableID
    self.generatedRequest = request
  }

  private static func imageScheme(for url: URL) -> ImageScheme {
    guard let schemeString = url.scheme?.lowercased() else {
      return .relative
    }
    switch schemeString {
    case "http": return .http
    case "https": return .https
    case "file": return .file
    case "data": return .data
    case "asset": return .asset
    case "bundle": return .bundle
    case "ink-generated": return .generated
    default: return .unknown
    }
  }
}
