import UIKit

/// 一个由 LaTeX 生成的内存图片；图片缓存与订阅由调用方的通用图片管线管理。
public struct InkLaTeXRenderResult: @unchecked Sendable {
  public let image: UIImage
  public let stableID: String
  public let size: CGSize

  public init(image: UIImage, stableID: String, size: CGSize) {
    self.image = image
    self.stableID = stableID
    self.size = size
  }
}

/// LaTeX → UIImage 渲染器的核心门面。
///
/// 真实 iosMath 实现由 ``InkMarkdownLaTeX`` addon 经 ``InkGeneratedAddonRuntime`` 注册；
/// 未注册时 ``render(_:)`` 抛出 ``ImageLoadError/generatedLoaderUnavailable(owner:)``。
public struct InkLaTeXImageRenderer: Sendable {
  /// 变更图片生成逻辑时递增，以使既有缓存自然失效；未注册 addon 时为 `nil` 映射的空字符串。
  public static var rendererVersion: String {
    InkGeneratedAddonRuntime.rendererVersion(owner: "latex") ?? ""
  }

  /// 单一公式源码的最大 Unicode 标量数量，限制解析和排版成本。
  public static let maximumContentLength = 8_192
  /// 允许生成的最大边长（像素）。
  public static let maximumPixelDimension: CGFloat = 4_096

  public init() {}

  /// 异步生成公式图片。须已链接并注册 ``InkMarkdownLaTeX`` addon。
  public func render(_ request: InkLaTeXRenderRequest) async throws -> InkLaTeXRenderResult {
    guard let provider = InkGeneratedAddonRuntime.makeLoader(owner: "latex") as? InkLaTeXRenderingProviding else {
      throw ImageLoadError.generatedLoaderUnavailable(owner: "latex")
    }
    return try await provider.renderLaTeX(request)
  }
}
