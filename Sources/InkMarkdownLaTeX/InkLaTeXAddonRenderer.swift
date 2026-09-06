import InkMarkdown
import iosMath
import UIKit

/// 基于 iosMath 的 LaTeX addon 渲染后端。
struct InkLaTeXAddonRenderer: Sendable {
  /// 变更图片生成逻辑时递增，以使既有缓存自然失效。
  static let rendererVersion = "iosMath-2.3.1-r2"

  /// 异步生成公式图片。输入校验不触碰 UI；iosMath 与 UIKit 绘制严格在 MainActor 上执行。
  func render(_ request: InkLaTeXRenderRequest) async throws -> InkLaTeXRenderResult {
    try validate(request)
    try Task.checkCancellation()
    return try await MainActor.run {
      try renderOnMain(request)
    }
  }

  private func validate(_ request: InkLaTeXRenderRequest) throws {
    guard !request.latex.isEmpty else { throw InkLaTeXError.emptyExpression }
    guard request.latex.unicodeScalars.count <= InkLaTeXImageRenderer.maximumContentLength else {
      throw InkLaTeXError.contentTooLong(limit: InkLaTeXImageRenderer.maximumContentLength)
    }
    guard request.display.maxPixelWidth > 0,
          request.display.maxPixelWidth <= InkLaTeXImageRenderer.maximumPixelDimension,
          request.display.scale >= 1,
          request.display.scale <= 4,
          request.style.fontSize >= 8,
          request.style.fontSize <= 128,
          request.style.horizontalPadding >= 0,
          request.style.verticalPadding >= 0,
          request.style.maxPixelHeight > 0,
          request.style.maxPixelHeight <= InkLaTeXImageRenderer.maximumPixelDimension else {
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
    let label = MTMathUILabel()
    label.displayErrorInline = false
    label.mode = request.mode == .inline ? .text : .display
    label.fontSize = request.style.fontSize
    label.textColor = (request.style.color ?? InkLaTeXColor(.label)).uiColor
    label.latex = request.latex

    if let error = label.error {
      throw InkLaTeXError.renderingFailed(error.localizedDescription)
    }

    // Measure the complete formula first, then scale the rasterization plan as a whole.
    // Passing the width budget to iosMath can clip or reflow a formula; uniform scaling
    // preserves its geometry while making both output pixel limits authoritative.
    let measured = label.sizeThatFits(CGSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    ))
    let naturalSize = CGSize(
      width: ceil(measured.width + request.style.horizontalPadding * 2),
      height: ceil(measured.height + request.style.verticalPadding * 2)
    )
    guard naturalSize.width.isFinite,
          naturalSize.height.isFinite,
          naturalSize.width > 0,
          naturalSize.height > 0 else {
      throw InkLaTeXError.imageTooLarge
    }

    // UIGraphicsImageRenderer allocates an integer number of pixels. Floor the public
    // budgets first so a request such as 160.5px cannot round up to 161px on output.
    let pixelWidthBudget = max(
      1,
      Int(floor(min(request.display.maxPixelWidth, InkLaTeXImageRenderer.maximumPixelDimension)))
    )
    let pixelHeightBudget = max(
      1,
      Int(floor(min(request.style.maxPixelHeight, InkLaTeXImageRenderer.maximumPixelDimension)))
    )
    let naturalPixelWidth = max(1, Int(ceil(naturalSize.width * request.display.scale)))
    let naturalPixelHeight = max(1, Int(ceil(naturalSize.height * request.display.scale)))
    let widthScale = CGFloat(pixelWidthBudget) / CGFloat(naturalPixelWidth)
    let heightScale = CGFloat(pixelHeightBudget) / CGFloat(naturalPixelHeight)
    let outputScale = min(1, widthScale, heightScale)
    guard outputScale.isFinite, outputScale > 0 else {
      throw InkLaTeXError.imageTooLarge
    }

    let outputPixelWidth = max(
      1,
      min(pixelWidthBudget, Int(ceil(CGFloat(naturalPixelWidth) * outputScale)))
    )
    let outputPixelHeight = max(
      1,
      min(pixelHeightBudget, Int(ceil(CGFloat(naturalPixelHeight) * outputScale)))
    )
    let outputPointSize = CGSize(
      width: pointDimension(forPixelCount: outputPixelWidth, scale: request.display.scale),
      height: pointDimension(forPixelCount: outputPixelHeight, scale: request.display.scale)
    )
    guard outputPointSize.width > 0,
          outputPointSize.height > 0 else {
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
    let image = UIGraphicsImageRenderer(size: outputPointSize, format: format).image { context in
      context.cgContext.scaleBy(x: outputScale, y: outputScale)
      label.layer.render(in: context.cgContext)
    }
    let actualPixelWidth = image.cgImage?.width
      ?? Int(ceil(image.size.width * image.scale))
    let actualPixelHeight = image.cgImage?.height
      ?? Int(ceil(image.size.height * image.scale))
    guard actualPixelWidth <= pixelWidthBudget,
          actualPixelHeight <= pixelHeightBudget,
          actualPixelWidth <= Int(InkLaTeXImageRenderer.maximumPixelDimension),
          actualPixelHeight <= Int(InkLaTeXImageRenderer.maximumPixelDimension) else {
      throw InkLaTeXError.imageTooLarge
    }
    return InkLaTeXRenderResult(
      image: image,
      stableID: request.stableID(resolvedColor: request.style.color ?? InkLaTeXColor(.label)),
      size: image.size
    )
  }

  /// Keep a renderer point dimension just below the exact pixel boundary so Core Graphics
  /// rounding cannot allocate one pixel beyond the already-floored budget.
  private func pointDimension(forPixelCount pixelCount: Int, scale: CGFloat) -> CGFloat {
    (CGFloat(pixelCount) / scale).nextDown
  }
}

/// 注册到核心的 LaTeX 生成型 loader。
struct InkLaTeXAddonGeneratedImageLoader: InkLaTeXRenderingProviding {
  private let renderer = InkLaTeXAddonRenderer()

  func renderLaTeX(_ request: InkLaTeXRenderRequest) async throws -> InkLaTeXRenderResult {
    try await renderer.render(request)
  }

  func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage {
    guard request.owner == "latex" else { throw ImageLoadError.decodeFailed }
    let mode: InkLaTeXRenderMode
    let style: InkLaTeXStyle
    if request.styleIdentity.hasPrefix("block:") {
      mode = .block
      style = InkLaTeXStyle(fontSize: 20, horizontalPadding: 6, verticalPadding: 6)
    } else {
      mode = .inline
      style = .init()
    }
    return try await renderLaTeX(InkLaTeXRenderRequest(
      latex: request.source,
      mode: mode,
      display: display,
      style: style
    )).image
  }
}
