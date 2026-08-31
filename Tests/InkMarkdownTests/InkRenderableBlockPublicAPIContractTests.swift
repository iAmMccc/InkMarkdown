//
//  InkRenderableBlockPublicAPIContractTests.swift
//  InkMarkdownTests
//

import Markdown
import Testing
import UIKit
import InkMarkdown

/// 模拟仅 `import InkMarkdown` 的外部消费者，不依赖任何 SPI witness。
private struct CustomBannerBlock: InkRenderableBlock {
  let text: String

  func makeView() -> UIView {
    let label = UILabel()
    label.text = text
    return label
  }
}

private final class NonSendableBannerService {
  var prefix = ""
}

private struct LegacyInlineSyntax: InkInlineSyntax {
  let service: NonSendableBannerService

  func render(text: String, context: InkInlineContext) -> NSAttributedString? {
    service.prefix.isEmpty ? nil : NSAttributedString(string: service.prefix + text)
  }
}

private struct CustomBannerHandler: InkBlockHandler {
  let service: NonSendableBannerService

  func canHandle(_ markup: Markup) -> Bool {
    markup is Paragraph
  }

  func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let paragraph = markup as? Paragraph else { return nil }
    let text = paragraph.children.compactMap { ($0 as? Text)?.string }.joined()
    guard !text.isEmpty else { return nil }
    return CustomBannerBlock(text: service.prefix + text)
  }
}

/// 保持非隔离：若公开 initializer、扩展点或闭包重新添加 actor / Sendable 约束，
/// 这段 0.0.1 风格用法应在编译阶段直接失败。
private func makeLegacyPublicAPIFixture() -> InkConfiguration {
  let service = NonSendableBannerService()
  var appearance = InkAppearance()
  appearance.table.onCopyFeedback = { _ in service.prefix = "copied:" }
  appearance.imageRendering.onImageTap = { _, _ in service.prefix = "image:" }
  appearance.imageRendering.onLoadFinished = { _, _ in service.prefix = "loaded:" }

  _ = InkAttributedTextBlock(
    attributedText: NSAttributedString(string: "legacy"),
    linkTapHandler: { _, _ in !service.prefix.isEmpty }
  )

  return InkConfiguration(
    appearance: appearance,
    inlineSyntaxes: [LegacyInlineSyntax(service: service)],
    sourceFilter: { service.prefix + $0 },
    blockHandlers: [CustomBannerHandler(service: service)],
    linkTapHandler: { _, _ in !service.prefix.isEmpty }
  )
}

@Suite("公开自定义块契约")
@MainActor
struct InkRenderableBlockPublicAPIContractTests {

  @Test("普通 import 可实现 InkRenderableBlock 并通过自定义 handler 渲染")
  func publicConsumer_canImplementRenderableBlock() {
    _ = makeLegacyPublicAPIFixture()

    var config = InkConfiguration.standard
    config.blockHandlers = [CustomBannerHandler(service: NonSendableBannerService())]

    let blocks = InkBlockRenderer.render("Hello custom block\n", configuration: config)

    #expect(!blocks.isEmpty)
    let label = blocks[0].makeView() as? UILabel
    #expect(label?.text == "Hello custom block")
  }
}
