import Testing
import UIKit
@testable import InkMarkdown

@MainActor private func latexBlockConfiguration(isEnabled: Bool = true) -> InkConfiguration {
  var appearance = InkAppearance()
  appearance.latexRendering.isEnabled = isEnabled
  var configuration = InkConfiguration(appearance: appearance)
  configuration.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: .light)
  return configuration
}

@Test @MainActor func latexBlockHandlerPromotesMultiParagraphDollarBlock() {
  let source = """
  块级积分公式：

  $$
  \\int_{-\\infty}^{+\\infty} e^{-x^2} dx = \\sqrt{\\pi}
  $$
  """
  let blocks = InkBlockRenderer.render(source, configuration: latexBlockConfiguration())

  #expect(blocks.count == 2)
  #expect(blocks[0] is InkAttributedTextBlock)
  #expect(blocks[1] is InkImageBlock)

  let imageBlock = blocks[1] as! InkImageBlock
  #expect(imageBlock.source.generatedRequest?.owner == "latex")
  #expect(
    imageBlock.source.generatedRequest?.source.contains("\\int")
      == true
  )
}

@Test @MainActor func latexBlockHandlerPromotesSingleLineDollarBlock() {
  let blocks = InkBlockRenderer.render(
    "$$a^2$$",
    configuration: latexBlockConfiguration()
  )

  #expect(blocks.count == 1)
  #expect(blocks[0] is InkImageBlock)
  #expect((blocks[0] as! InkImageBlock).source.generatedRequest?.source == "a^2")
}

@Test @MainActor func latexBlockHandlerDoesNotPromoteWhenDisabled() {
  let source = """
  $$
  \\int_{-\\infty}^{+\\infty} e^{-x^2} dx = \\sqrt{\\pi}
  $$
  """
  let blocks = InkBlockRenderer.render(
    source,
    configuration: latexBlockConfiguration(isEnabled: false)
  )

  #expect(blocks.count == 1)
  #expect(blocks[0] is InkAttributedTextBlock)
  #expect(!(blocks[0] is InkImageBlock))
}

@Test @MainActor func latexBlockHandlerDoesNotPromoteMixedParagraph() {
  let blocks = InkBlockRenderer.render(
    "前缀 $$a^2$$ 后缀",
    configuration: latexBlockConfiguration()
  )

  #expect(blocks.count == 1)
  #expect(blocks[0] is InkAttributedTextBlock)
  #expect(!(blocks[0] is InkImageBlock))
}

@Test @MainActor func latexBlockHandlerPromotesMultiParagraphBracketBlock() {
  let source = """
  \\[
  E = mc^2
  \\]
  """
  let blocks = InkBlockRenderer.render(source, configuration: latexBlockConfiguration())

  #expect(blocks.count == 1)
  #expect(blocks[0] is InkImageBlock)
  #expect((blocks[0] as! InkImageBlock).source.generatedRequest?.source == "E = mc^2")
}
