import Foundation

/// Markdown 图片节点的规范化来源描述。
///
/// 将原始 URL 解析为 scheme 分类与去重用的 `canonicalID`，供缓存键与安全策略共用。
public struct ImageSource: Hashable, Sendable {

  /// 原始 URL（Markdown 解析结果或经 `baseURL` 解析后的绝对地址）。
  public let rawURL: URL

  /// 根据 URL scheme 推导的来源类型。
  public let scheme: ImageScheme

  /// 规范化标识：按配置剥离 query / fragment 后的 `absoluteString`，用于缓存去重。
  public let canonicalID: String

  /// 图片 URL 的 scheme 分类。
  public enum ImageScheme: Hashable, Sendable {
    case http
    case https
    case file
    case data
    case asset
    case bundle
    case relative
    case unknown
  }

  /// 从 URL 构建图片来源，并生成规范化 ID。
  ///
  /// - Parameters:
  ///   - url: 原始 URL。
  ///   - stripsQuery: 为 `true` 时从 `canonicalID` 中移除 query 组件。
  ///   - stripsFragment: 为 `true` 时从 `canonicalID` 中移除 fragment 组件。
  public init(url: URL, stripsQuery: Bool = true, stripsFragment: Bool = true) {
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
      // 相对 URL 可能没有 base，`url` 回退保证 canonicalID 始终可用。
      self.canonicalID = (components?.url ?? url).absoluteString
    } else {
      self.canonicalID = url.absoluteString
    }
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
    default: return .unknown
    }
  }
}
