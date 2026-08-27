#if canImport(iosMath)
import iosMath
import UIKit

/// 一个由 LaTeX 生成的内存图片；图片缓存与订阅由调用方的通用图片管线管理。
public struct InkLaTeXRenderResult: @unchecked Sendable {
  public let image: UIImage
  public let stableID: String
  public let size: CGSize
}

/// 基于 iosMath 的异步 LaTeX → UIImage 渲染器。
///
/// 此类型不持有缓存、不写入磁盘，也不直接调用 ``InkImageStore``；接入层应以
/// ``InkLaTeXRenderRequest/stableID`` 作为生成图片源的 identity，并把结果交给既有 Store。
public struct InkLaTeXImageRenderer: Sendable {
  /// 变更图片生成逻辑时递增，以使既有缓存自然失效。
  public static let rendererVersion = "iosMath-2.3.1-r1"

  /// 单一公式源码的最大 Unicode 标量数量，限制解析和排版成本。
  public static let maximumContentLength = 8_192
  /// 允许生成的最大边长（像素）。
  public static let maximumPixelDimension: CGFloat = 4_096

  public init() {}

  /// 异步生成公式图片。输入校验不触碰 UI；iosMath 与 UIKit 绘制严格在 MainActor 上执行。
  public func render(_ request: InkLaTeXRenderRequest) async throws -> InkLaTeXRenderResult {
    try validate(request)
    try Task.checkCancellation()
    return try await MainActor.run {
      try renderOnMain(request)
    }
  }

  private func validate(_ request: InkLaTeXRenderRequest) throws {
    guard !request.latex.isEmpty else { throw InkLaTeXError.emptyExpression }
    guard request.latex.unicodeScalars.count <= Self.maximumContentLength else {
      throw InkLaTeXError.contentTooLong(limit: Self.maximumContentLength)
    }
    guard request.display.maxPixelWidth > 0,
          request.display.maxPixelWidth <= Self.maximumPixelDimension,
          request.display.scale >= 1,
          request.display.scale <= 4,
          request.style.fontSize >= 8,
          request.style.fontSize <= 128,
          request.style.horizontalPadding >= 0,
          request.style.verticalPadding >= 0,
          request.style.maxPixelHeight > 0,
          request.style.maxPixelHeight <= Self.maximumPixelDimension else {
      throw InkLaTeXError.invalidDisplayContext
    }
    try validateBraces(in: request.latex)
  }

  private func validateBraces(in latex: String) throws {
    var depth = 0
    var escaped = false
    for character in latex {
      if escaped {
        escaped = false
        continue
      }
      if character == "\\" {
        escaped = true
      } else if character == "{" {
        depth += 1
      } else if character == "}" {
        depth -= 1
        if depth < 0 { throw InkLaTeXError.unbalancedBraces }
      }
    }
    guard depth == 0 else { throw InkLaTeXError.unbalancedBraces }
  }

  @MainActor
  private func renderOnMain(_ request: InkLaTeXRenderRequest) throws -> InkLaTeXRenderResult {
    let maxPointHeight = request.style.maxPixelHeight / request.display.scale
    let label = MTMathUILabel()
    label.displayErrorInline = false
    label.mode = request.mode == .inline ? .text : .display
    label.fontSize = request.style.fontSize
    label.textColor = (request.style.color ?? InkLaTeXColor(.label)).uiColor
    label.latex = request.latex

    if let error = label.error {
      throw InkLaTeXError.renderingFailed(error.localizedDescription)
    }

    let measured = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: maxPointHeight))
    let size = CGSize(
      width: ceil(measured.width + request.style.horizontalPadding * 2),
      height: ceil(measured.height + request.style.verticalPadding * 2)
    )
    guard size.width > 0,
          size.height > 0,
          size.width * request.display.scale <= Self.maximumPixelDimension,
          size.height * request.display.scale <= request.style.maxPixelHeight else {
      throw InkLaTeXError.imageTooLarge
    }

    label.frame = CGRect(
      x: request.style.horizontalPadding,
      y: request.style.verticalPadding,
      width: measured.width,
      height: measured.height
    )
    label.setNeedsLayout()
    label.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = request.display.scale
    format.opaque = false
    let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
      label.layer.render(in: context.cgContext)
    }
    return InkLaTeXRenderResult(
      image: image,
      stableID: request.stableID(resolvedColor: request.style.color ?? InkLaTeXColor(.label)),
      size: size
    )
  }
}
#else
import UIKit

/// iosMath 未导入时的桩实现
public struct InkLaTeXRenderResult: Sendable {
  public let image: UIImage
  public let stableID: String
  public let size: CGSize
}

public struct InkLaTeXImageRenderer: Sendable {
  public static let rendererVersion = "iosMath-not-imported"
  public static let maximumContentLength = 8_192
  public static let maximumPixelDimension: CGFloat = 4_096

  public init() {}
  public func render(_ request: InkLaTeXRenderRequest) async throws -> InkLaTeXRenderResult {
    throw NSError(domain: "InkLaTeXImageRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "LaTeX rendering requires the iosMath module."])
  }
}
#endif
