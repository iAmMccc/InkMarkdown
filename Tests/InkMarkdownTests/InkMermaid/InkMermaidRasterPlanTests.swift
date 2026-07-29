import Testing
import CoreGraphics
@testable import InkMarkdown

struct InkMermaidRasterPlanTests {
  private let limits = InkMermaidRenderLimits(
    minimumPixelWidth: 1,
    maximumPixelWidth: 1_000,
    maximumPixelHeight: 1_000
  )

  @Test func scaleTwoUsesPointLayoutButKeepsPixelBudget() throws {
    let plan = try InkMermaidRasterPlan.make(
      svgWidthInPoints: 500,
      svgHeightInPoints: 200,
      display: .init(maxPixelWidth: 600, scale: 2, theme: .light),
      limits: limits
    )
    #expect(plan.layoutSizeInPoints == CGSize(width: 300, height: 120))
    #expect(plan.outputSizeInPixels == CGSize(width: 600, height: 240))
  }

  @Test func scaleOneKeepsPointsAndPixelsEqual() throws {
    let plan = try InkMermaidRasterPlan.make(
      svgWidthInPoints: 500,
      svgHeightInPoints: 200,
      display: .init(maxPixelWidth: 600, scale: 1, theme: .light),
      limits: limits
    )
    #expect(plan.layoutSizeInPoints == CGSize(width: 500, height: 200))
    #expect(plan.outputSizeInPixels == CGSize(width: 500, height: 200))
  }

  @Test func scaleThreeUsesSamePixelBudgetWithoutDoubleScaling() throws {
    let plan = try InkMermaidRasterPlan.make(
      svgWidthInPoints: 500,
      svgHeightInPoints: 200,
      display: .init(maxPixelWidth: 600, scale: 3, theme: .light),
      limits: limits
    )
    #expect(plan.layoutSizeInPoints == CGSize(width: 200, height: 80))
    #expect(plan.outputSizeInPixels == CGSize(width: 600, height: 240))
  }

  @Test(arguments: [CGFloat.zero, .nan]) func invalidWidthIsRejected(width: CGFloat) {
    #expect(throws: InkMermaidRenderError.invalidDiagramSize) {
      try InkMermaidRasterPlan.make(
        svgWidthInPoints: width,
        svgHeightInPoints: 100,
        display: .init(maxPixelWidth: 300, scale: 2, theme: .light),
        limits: limits
      )
    }
  }

  @Test(arguments: [CGFloat.zero, .nan]) func invalidHeightIsRejected(height: CGFloat) {
    #expect(throws: InkMermaidRenderError.invalidDiagramSize) {
      try InkMermaidRasterPlan.make(
        svgWidthInPoints: 100,
        svgHeightInPoints: height,
        display: .init(maxPixelWidth: 300, scale: 3, theme: .light),
        limits: limits
      )
    }
  }

  @Test(arguments: [CGFloat.zero, 0.5, .nan]) func scaleBelowUIKitMinimumIsRejected(scale: CGFloat) {
    #expect(throws: InkMermaidRenderError.invalidDisplaySize) {
      try InkMermaidRasterPlan.make(
        svgWidthInPoints: 100,
        svgHeightInPoints: 100,
        display: .init(maxPixelWidth: 300, scale: scale, theme: .light),
        limits: limits
      )
    }
  }
}
