import InkMarkdownLaTeX
import InkMarkdownMermaid
import Testing
import UIKit
@testable import InkMarkdown

private struct ImmediateMermaidProvider: InkMermaidRenderingProviding {
  func renderMermaid(
    _ request: InkMermaidRenderRequest,
    limits: InkMermaidRenderLimits
  ) async throws -> InkMermaidRenderResult {
    await MainActor.run {
      let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 60)).image { context in
        UIColor.systemBlue.setFill()
        context.cgContext.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
      }
      return InkMermaidRenderResult(image: image, pngData: image.pngData() ?? Data(), cacheIdentity: "test")
    }
  }

  func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage {
    guard request.owner == "mermaid" else { throw ImageLoadError.decodeFailed }
    return try await renderMermaid(
      InkMermaidRenderRequest(
        source: request.source,
        display: .init(maxPixelWidth: display.maxPixelWidth, scale: display.scale, theme: .light)
      ),
      limits: .init()
    ).image
  }
}

@Suite("生成型 addon 完整渲染链路", .serialized)
@MainActor
struct GeneratedAddonPipelineTests {

  @Test("LaTeX 注册后经 BlockRenderer-ImageBlock-Store 产出图片")
  func registeredLaTeX_completesFullPipeline() async throws {
    _ = InkMarkdownLaTeX.register()
    var appearance = InkAppearance()
    appearance.latexRendering.isEnabled = true
    try await assertGeneratedBlockSucceeds(
      markdown: "$$x + y$$",
      appearance: appearance,
      expectedOwner: "latex"
    )
  }

  @Test("Mermaid 注册后经 BlockRenderer-ImageBlock-Store 产出图片")
  func registeredMermaid_completesFullPipeline() async throws {
    _ = InkMarkdownMermaid.register()
    #expect(InkGeneratedAddonRuntime.makeLoader(owner: "mermaid") is any InkMermaidRenderingProviding)
    defer { _ = InkMarkdownMermaid.register() }
    _ = InkGeneratedAddonRuntime.register(
      owner: "mermaid",
      rendererVersion: "test-immediate-mermaid-v1",
      makeLoader: { ImmediateMermaidProvider() }
    )
    var appearance = InkAppearance()
    appearance.mermaidRendering.isEnabled = true
    appearance.mermaidRendering.limits.timeout = 15
    try await assertGeneratedBlockSucceeds(
      markdown: """
      ```mermaid
      graph TD
        A --> B
      ```
      """,
      appearance: appearance,
      expectedOwner: "mermaid"
    )
  }

  private func assertGeneratedBlockSucceeds(
    markdown: String,
    appearance baseAppearance: InkAppearance,
    expectedOwner: String
  ) async throws {
    var appearance = baseAppearance
    var completedSource: ImageSource?
    var completedImage: UIImage?
    var didComplete = false
    appearance.imageRendering.setLoadFinishedHandler({ source, image in
      completedSource = source
      completedImage = image
      didComplete = true
    }, semanticIdentity: InkSemanticIdentity("registered-pipeline.\(expectedOwner).v1"))

    let blocks = InkBlockRenderer.render(
      markdown,
      configuration: InkConfiguration(appearance: appearance)
    )
    let block = try #require(blocks.first as? InkImageBlock)
    #expect(block.source.generatedRequest?.owner == expectedOwner)

    block.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
    block.setNeedsLayout()
    block.layoutIfNeeded()

    let deadline = DispatchTime.now().uptimeNanoseconds + 20_000_000_000
    while !didComplete, DispatchTime.now().uptimeNanoseconds < deadline {
      try await Task.sleep(nanoseconds: 20_000_000)
    }

    #expect(didComplete)
    #expect(completedSource?.generatedRequest?.owner == expectedOwner)
    #expect(completedImage != nil)
    #expect(block.sizeThatFits(
      CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
    ).height > 0)
  }
}
