import InkMarkdown
import Testing
import UIKit

@Suite("核心库 addon 注册边界", .serialized)
@MainActor
struct GeneratedAddonRegistrationBoundaryTests {

  @Test("仅链接 InkMarkdown 时已知 addon owner 不得隐式注册")
  func knownAddonOwnersStartUnregistered() {
    #expect(InkGeneratedAddonRuntime.rendererVersion(owner: "latex") == nil)
    #expect(InkGeneratedAddonRuntime.rendererVersion(owner: "mermaid") == nil)
    #expect(InkGeneratedAddonRuntime.resourceBundle(owner: "mermaid") == nil)
  }

  @Test("LaTeX 未注册时完整 block-store 链路明确失败")
  func unregisteredLaTeXFailsThroughBlockAndStorePipeline() async throws {
    try await assertUnregisteredGeneratedBlockFails(
      markdown: "$$x + y$$",
      configure: { appearance in
        appearance.latexRendering.isEnabled = true
      },
      expectedOwner: "latex"
    )
  }

  @Test("Mermaid 未注册时完整 block-store 链路明确失败")
  func unregisteredMermaidFailsThroughBlockAndStorePipeline() async throws {
    try await assertUnregisteredGeneratedBlockFails(
      markdown: """
      ```mermaid
      graph TD
        A --> B
      ```
      """,
      configure: { appearance in
        appearance.mermaidRendering.isEnabled = true
      },
      expectedOwner: "mermaid"
    )
  }

  private func assertUnregisteredGeneratedBlockFails(
    markdown: String,
    configure: (inout InkAppearance) -> Void,
    expectedOwner: String
  ) async throws {
    var appearance = InkAppearance()
    configure(&appearance)

    var completedSource: ImageSource?
    var completedImage: UIImage?
    var didComplete = false
    appearance.imageRendering.setLoadFinishedHandler({ source, image in
      completedSource = source
      completedImage = image
      didComplete = true
    }, semanticIdentity: InkSemanticIdentity("core-contract.\(expectedOwner).failure.v1"))

    let blocks = InkBlockRenderer.render(
      markdown,
      configuration: InkConfiguration(appearance: appearance)
    )
    let block = try #require(blocks.first as? InkImageBlock)
    #expect(block.source.generatedRequest?.owner == expectedOwner)

    block.frame = CGRect(x: 0, y: 0, width: 320, height: 160)
    block.setNeedsLayout()
    block.layoutIfNeeded()

    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while !didComplete, DispatchTime.now().uptimeNanoseconds < deadline {
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    #expect(didComplete)
    #expect(completedSource?.generatedRequest?.owner == expectedOwner)
    #expect(completedImage == nil)
  }
}
