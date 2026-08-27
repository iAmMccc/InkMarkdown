import UIKit
import XCTest
@testable import InkMarkdown

final class InkLaTeXImageRendererTests: XCTestCase {

  func testStableIDChangesWithContentDisplayAndStyle() {
    let resolvedBlack = InkLaTeXColor(red: 0, green: 0, blue: 0)
    let base = makeRequest(latex: "x^2")
    let same = makeRequest(latex: " x^2\r\n")
    let changedContent = makeRequest(latex: "x^3")
    let changedDisplay = InkLaTeXRenderRequest(
      latex: "x^2",
      mode: .inline,
      display: DisplayContext(maxPixelWidth: 480, scale: 2),
      style: .init(color: resolvedBlack)
    )
    let changedStyle = InkLaTeXRenderRequest(
      latex: "x^2",
      mode: .inline,
      display: DisplayContext(maxPixelWidth: 320, scale: 2),
      style: .init(color: .init(red: 255, green: 0, blue: 0))
    )

    XCTAssertEqual(base.stableID(resolvedColor: resolvedBlack), same.stableID(resolvedColor: resolvedBlack))
    XCTAssertNotEqual(base.stableID(resolvedColor: resolvedBlack), changedContent.stableID(resolvedColor: resolvedBlack))
    XCTAssertNotEqual(base.stableID(resolvedColor: resolvedBlack), changedDisplay.stableID(resolvedColor: resolvedBlack))
    XCTAssertNotEqual(base.stableID(resolvedColor: resolvedBlack), changedStyle.stableID(resolvedColor: .init(red: 255, green: 0, blue: 0)))
  }

  func testRendererRejectsOversizedAndUnbalancedInputBeforeUIWork() async {
    if InkLaTeXImageRenderer.rendererVersion == "iosMath-not-imported" { return }
    let renderer = InkLaTeXImageRenderer()
    let tooLong = makeRequest(latex: String(repeating: "x", count: InkLaTeXImageRenderer.maximumContentLength + 1))
    let unbalanced = makeRequest(latex: "\\frac{1}{2")

    await assertError(.contentTooLong(limit: InkLaTeXImageRenderer.maximumContentLength)) {
      _ = try await renderer.render(tooLong)
    }
    await assertError(.unbalancedBraces) {
      _ = try await renderer.render(unbalanced)
    }
  }

  func testDisplayContextNormalizesSubunitAndNonFiniteScalesBeforeRendering() {
    for rawScale in [CGFloat(0.5), .nan, .infinity, -.infinity] {
      let request = makeRequest(latex: "x", scale: rawScale)

      XCTAssertEqual(request.display.scale, DisplayContext.minimumScale)
    }
  }

  func testRendererRejectsScaleAboveLaTeXLimitBeforeUIWork() async {
    if InkLaTeXImageRenderer.rendererVersion == "iosMath-not-imported" { return }
    let request = makeRequest(latex: "x", scale: 5)

    await assertError(.invalidDisplayContext) {
      _ = try await InkLaTeXImageRenderer().render(request)
    }
  }

  func testRendererAcceptsUIKitDisplayScales() async throws {
    if InkLaTeXImageRenderer.rendererVersion == "iosMath-not-imported" { return }
    let renderer = InkLaTeXImageRenderer()

    for scale in [CGFloat(1), 2, 3] {
      let result = try await renderer.render(makeRequest(latex: "x", scale: scale))
      XCTAssertEqual(result.image.scale, scale)
    }
  }

  func testRendererProducesImageForBasicExpression() async throws {
    if InkLaTeXImageRenderer.rendererVersion == "iosMath-not-imported" { return }
    let result = try await InkLaTeXImageRenderer().render(makeRequest(latex: "x^2 + y^2"))

    XCTAssertGreaterThan(result.image.size.width, 0)
    XCTAssertGreaterThan(result.image.size.height, 0)
    XCTAssertEqual(result.stableID, makeRequest(latex: "x^2 + y^2").stableID(resolvedColor: InkLaTeXColor(red: 0, green: 0, blue: 0)))
  }

  private func makeRequest(latex: String, scale: CGFloat = 2) -> InkLaTeXRenderRequest {
    InkLaTeXRenderRequest(
      latex: latex,
      mode: .inline,
      display: DisplayContext(maxPixelWidth: 320, scale: scale),
      style: .init(color: .init(red: 0, green: 0, blue: 0))
    )
  }

  private func assertError(
    _ expected: InkLaTeXError,
    operation: () async throws -> Void
  ) async {
    do {
      try await operation()
      XCTFail("预期抛出 \(expected)")
    } catch let error as InkLaTeXError {
      XCTAssertEqual(error, expected)
    } catch {
      XCTFail("收到意外错误：\(error)")
    }
  }
}
