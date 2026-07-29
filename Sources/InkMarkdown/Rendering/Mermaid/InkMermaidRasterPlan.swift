import CoreGraphics

/// Mermaid SVG 到 WebKit snapshot 的单一单位换算。
///
/// SVG 的 `getBoundingClientRect`、WKWebView frame、`WKSnapshotConfiguration.rect` 与
/// `snapshotWidth` 都使用 point；`DisplayContext.maxPixelWidth`、渲染限制以及 image budget
/// 使用 pixel。`outputSizeInPixels = layoutSizeInPoints × display.scale`，只在这里换算一次。
struct InkMermaidRasterPlan: Equatable {
  let layoutSizeInPoints: CGSize
  let outputSizeInPixels: CGSize

  static func make(
    svgWidthInPoints: CGFloat,
    svgHeightInPoints: CGFloat,
    display: InkMermaidDisplayContext,
    limits: InkMermaidRenderLimits
  ) throws -> InkMermaidRasterPlan {
    guard svgWidthInPoints.isFinite, svgHeightInPoints.isFinite,
          svgWidthInPoints > 0, svgHeightInPoints > 0 else {
      throw InkMermaidRenderError.invalidDiagramSize
    }
    guard display.maxPixelWidth.isFinite, display.maxPixelWidth > 0,
          display.scale.isFinite, display.scale >= 1,
          limits.minimumPixelWidth.isFinite, limits.minimumPixelWidth > 0,
          limits.maximumPixelWidth.isFinite, limits.maximumPixelWidth >= limits.minimumPixelWidth,
          limits.maximumPixelHeight.isFinite, limits.maximumPixelHeight > 0 else {
      throw InkMermaidRenderError.invalidDisplaySize
    }

    let maximumOutputWidthInPixels = min(display.maxPixelWidth, limits.maximumPixelWidth)
    let nativeWidthInPixels = svgWidthInPoints * display.scale
    let aspectRatio = svgHeightInPoints / svgWidthInPoints
    guard maximumOutputWidthInPixels.isFinite, maximumOutputWidthInPixels > 0,
          nativeWidthInPixels.isFinite, nativeWidthInPixels > 0,
          aspectRatio.isFinite, aspectRatio > 0 else {
      throw InkMermaidRenderError.invalidDiagramSize
    }

    let outputWidthInPixels = min(
      max(nativeWidthInPixels, limits.minimumPixelWidth),
      maximumOutputWidthInPixels
    )
    let outputHeightInPixels = outputWidthInPixels * aspectRatio
    let layoutWidthInPoints = outputWidthInPixels / display.scale
    let layoutHeightInPoints = outputHeightInPixels / display.scale
    guard outputWidthInPixels.isFinite, outputHeightInPixels.isFinite,
          layoutWidthInPoints.isFinite, layoutHeightInPoints.isFinite,
          outputWidthInPixels > 0, outputHeightInPixels > 0,
          layoutWidthInPoints > 0, layoutHeightInPoints > 0 else {
      throw InkMermaidRenderError.invalidDiagramSize
    }
    guard outputHeightInPixels <= limits.maximumPixelHeight else {
      throw InkMermaidRenderError.exceedsMaximumSize
    }

    return InkMermaidRasterPlan(
      layoutSizeInPoints: CGSize(width: layoutWidthInPoints, height: layoutHeightInPoints),
      outputSizeInPixels: CGSize(width: outputWidthInPixels, height: outputHeightInPixels)
    )
  }
}
