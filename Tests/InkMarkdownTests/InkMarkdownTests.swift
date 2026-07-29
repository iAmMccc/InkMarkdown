import Testing
import UIKit
@_spi(Performance) @testable import InkMarkdown

// MARK: - 固定行高核心测试

@Test func fixedLineHeight_plainParagraph() async throws {
  let source = "这是一段普通正文，没有任何内联样式。"
  let result = InkAttributedRenderer.render(source)

  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 28)
  #expect(para.maximumLineHeight == 28)
  #expect(para.lineSpacing == 0)
}

@Test func fixedLineHeight_paragraphWithBold() async throws {
  let source = "报价为**1年1,300元**，3年2,300元。"
  let result = InkAttributedRenderer.render(source)

  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 28)
  #expect(para.maximumLineHeight == 28)

  // 所有 run 都有 baselineOffset
  var allHaveOffset = true
  result.enumerateAttribute(.baselineOffset, in: NSRange(location: 0, length: result.length), options: []) { value, _, _ in
    if value == nil { allHaveOffset = false }
  }
  #expect(allHaveOffset)
}

@Test func fixedLineHeight_paragraphWithInlineCode() async throws {
  let source = "使用 `config.lineHeight` 来设置行高。"
  let result = InkAttributedRenderer.render(source)

  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 28)
  #expect(para.maximumLineHeight == 28)

  // 行内代码跟随正文字号，只切换到等宽字体；baselineOffset 应与正文一致。
  var codeOffset: CGFloat = 0
  var bodyOffset: CGFloat = 0
  var codeFont: UIFont?
  var bodyFont: UIFont?
  result.enumerateAttributes(in: NSRange(location: 0, length: result.length), options: []) { attrs, _, _ in
    guard let font = attrs[.font] as? UIFont,
          let offset = attrs[.baselineOffset] as? CGFloat else { return }
    if font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
      codeOffset = offset
      codeFont = font
    } else {
      bodyOffset = offset
      bodyFont = font
    }
  }
  #expect(codeFont?.pointSize == bodyFont?.pointSize)
  #expect(codeOffset == bodyOffset)
}

@Test func fixedLineHeight_h1() async throws {
  let source = "# 一级标题"
  let result = InkAttributedRenderer.render(source)

  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 30)
  #expect(para.maximumLineHeight == 30)
  #expect(para.paragraphSpacing == 16)
}

@Test func fixedLineHeight_h2() async throws {
  let source = "## 二级标题"
  let result = InkAttributedRenderer.render(source)

  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 28)
  #expect(para.maximumLineHeight == 28)
  #expect(para.paragraphSpacing == 8)
}

@Test func fixedLineHeight_orderedList() async throws {
  let source = """
  1. 第一条内容
  2. 第二条内容
  3. 第三条内容
  """
  let result = InkAttributedRenderer.render(source)

  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 28)
  #expect(para.maximumLineHeight == 28)
  // 列表项左侧无缩进
  #expect(para.firstLineHeadIndent == 0)
  // 悬挂缩进 > 0
  #expect(para.headIndent > 0)
}

@Test func fixedLineHeight_unorderedList() async throws {
  let source = """
  - 无序列表一
  - 无序列表二
  """
  let result = InkAttributedRenderer.render(source)

  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 28)
  #expect(para.maximumLineHeight == 28)
  #expect(para.firstLineHeadIndent == 0)
  #expect(para.headIndent > 0)
}

@Test func fixedLineHeight_codeBlock() async throws {
  let source = """
  ```
  let x = 1
  let y = 2
  ```
  """
  let result = InkAttributedRenderer.render(source)

  // 代码块走富文本通道 fallback（visitCodeBlock），行高取 codeBlock.lineHeight = 24
  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 24)
  #expect(para.maximumLineHeight == 24)
}

@Test func thematicBreak_height() async throws {
  let source = "---"
  let result = InkAttributedRenderer.render(source)

  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 1)
  #expect(para.maximumLineHeight == 1)
  // 分割线不应有自身间距（依赖前后段落的 spacing）
  #expect(para.paragraphSpacingBefore == 0)
  #expect(para.paragraphSpacing == 0)
}

@Test func baselineOffset_neverNegative() async throws {
  // 即使注入大字号字体，baselineOffset 也不应为负
  var appearance = InkAppearance()
  appearance.text.fontSize = 30
  appearance.text.lineHeight = 28
  let config = InkConfiguration(appearance: appearance)
  let source = "大字号测试"
  let result = InkAttributedRenderer.render(source, configuration: config)

  var hasNegativeOffset = false
  result.enumerateAttribute(.baselineOffset, in: NSRange(location: 0, length: result.length), options: []) { value, _, _ in
    if let offset = value as? CGFloat, offset < 0 {
      hasNegativeOffset = true
    }
  }
  #expect(!hasNegativeOffset)
}

@Test func paragraphSpacing_values() async throws {
  let source = """
  第一段正文。

  第二段正文。
  """
  let result = InkAttributedRenderer.render(source)

  // 第一段的 paragraphSpacing 应为 text.paragraphSpacing = 12
  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.paragraphSpacing == 12)
}

@Test func listItemSpacing() async throws {
  let source = """
  1. 第一条
  2. 第二条
  """
  let result = InkAttributedRenderer.render(source)

  // 第一个列表项的 paragraphSpacing 应为 list.itemSpacing = 12
  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.paragraphSpacing == 12)
}

@Test func appearance_defaultValues() async throws {
  let a = InkAppearance()
  #expect(a.text.fontSize == 17)
  #expect(a.codeBlock.fontSize == 14)
  #expect(a.heading.h1FontSize == 19)
  #expect(a.heading.fontSize == 17)
  #expect(a.text.lineHeight == 28)
  #expect(a.heading.h1LineHeight == 30)
  #expect(a.codeBlock.lineHeight == 24)
  #expect(a.table.lineHeight == 20)
  #expect(a.text.paragraphSpacing == 12)
  #expect(a.blockquote.innerSpacing == 12)
  #expect(a.heading.h1SpacingAfter == 16)
  #expect(a.heading.spacingAfter == 8)
  #expect(a.list.itemSpacing == 12)
  #expect(a.list.spacingAfter == 24)
  #expect(a.thematicBreak.lineThickness == 1)
}

@Test func mixedInlineStyles_uniformLineHeight() async throws {
  // 混合多种内联样式：加粗、行内代码、链接
  let source = "普通文字**加粗**和`代码`以及[链接](https://example.com)混排。"
  let result = InkAttributedRenderer.render(source)

  // 整段只有一个 paragraphStyle，行高锁死
  var paragraphStyles: [NSParagraphStyle] = []
  result.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: result.length), options: []) { value, _, _ in
    if let para = value as? NSParagraphStyle {
      paragraphStyles.append(para)
    }
  }

  for para in paragraphStyles {
    #expect(para.minimumLineHeight == 28)
    #expect(para.maximumLineHeight == 28)
  }
}

// MARK: - 流式增量渲染

@Test func streamRenderer_reparsesOnlyActiveSuffixAfterStableBlock() async throws {
  var renderer = InkIncrementalMarkdownRenderer()
  let config = InkConfiguration.standard

  _ = renderer.append("# 标题\n\n正在生成", configuration: config)
  let result = renderer.append("更多内容", configuration: config)
  let full = InkAttributedRenderer.render("# 标题\n\n正在生成更多内容")

  #expect(result.refreshLocation > 0)
  #expect(result.content.string == full.string)
}

@Test func streamRenderer_keepsUnclosedCodeFenceInActiveSuffix() async throws {
  var renderer = InkIncrementalMarkdownRenderer()
  let config = InkConfiguration.standard

  let openFence = renderer.append("```swift\nlet a = 1\n", configuration: config)
  #expect(openFence.refreshLocation == 0)

  _ = renderer.append("```\n\n下一段", configuration: config)
  let stableFence = renderer.append("继续", configuration: config)
  #expect(stableFence.refreshLocation > 0)
}

@Test func streamRenderer_keepsUnclosedTildeFenceInActiveSuffix() async throws {
  var renderer = InkIncrementalMarkdownRenderer()
  let config = InkConfiguration.standard

  _ = renderer.append("~~~swift\n# 不是标题\n\n", configuration: config)
  let activeFence = renderer.append("let value = 1", configuration: config)

  #expect(activeFence.refreshLocation == 0)
}

@Test func streamRenderer_buffersUnclosedInlineDollarUntilPaired() async throws {
  var renderer = InkIncrementalMarkdownRenderer()
  let config = InkConfiguration.standard

  let partial = renderer.append("公式 $x", configuration: config)
  #expect(!partial.content.string.contains("$x"))

  let completed = renderer.append("$ 完成", configuration: config)
  #expect(completed.content.string.contains("$x$"))
}

@Test func streamRenderer_buffersUnclosedInlineParenthesesAndHonorsEscapesAndCode() async throws {
  var renderer = InkIncrementalMarkdownRenderer()
  let config = InkConfiguration.standard

  let partial = renderer.append("公式 \\(x", configuration: config)
  #expect(!partial.content.string.contains("\\(x"))
  let completed = renderer.append("\\) 完成", configuration: config)
  #expect(completed.content.string.contains("\\(x\\)"))

  renderer.reset()
  let escaped = renderer.append("\\$notLatex", configuration: config)
  #expect(escaped.content.string.contains("$notLatex"))
  renderer.reset()
  let code = renderer.append("`$notLatex", configuration: config)
  #expect(code.content.string.contains("$notLatex"))
}

@Test func streamRenderer_finishDegradesIncompleteInlineLatexToText() async throws {
  let renderer = InkStreamRenderer()
  renderer.append("$x")
  #expect(!renderer.currentAttributedString().string.contains("$x"))

  renderer.finish()
  for _ in 0..<50 where !renderer.currentAttributedString().string.contains("$x") {
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
  #expect(renderer.currentAttributedString().string.contains("$x"))
}

@Test func streamRenderer_doesNotFreezeListBeforeIndentedContinuation() async throws {
  var renderer = InkIncrementalMarkdownRenderer()
  let config = InkConfiguration.standard

  _ = renderer.append("- 第一段\n\n", configuration: config)
  let continuedList = renderer.append("  续段", configuration: config)
  let full = InkAttributedRenderer.render("- 第一段\n\n  续段")

  #expect(continuedList.refreshLocation == 0)
  #expect(continuedList.content.string == full.string)
}

@Test func streamRenderer_replaceSourceSeedsFutureAppend() async throws {
  var renderer = InkIncrementalMarkdownRenderer()
  let config = InkConfiguration.standard

  _ = renderer.replaceSource("# 标题\n\n已有内容", configuration: config)
  let result = renderer.append("继续", configuration: config)
  let full = InkAttributedRenderer.render("# 标题\n\n已有内容继续")

  #expect(result.refreshLocation > 0)
  #expect(result.content.string == full.string)
}

@Test func streamRenderer_incrementalBenchmarkMatchesFinalFullRender() async throws {
  let result = InkStreamingPerformanceBenchmark.measure()
  #expect(result.outputMatches)
}

// MARK: - context 下传验收（slice 1）
//
// 这批测试锁定 render-then-rewrite → context 下传重写后的样式正确性：
// 行内元素在混入 heading / blockquote / list 时，字体、颜色、链接、背景不再互相覆盖。

/// 1. heading + inline code：标题里的行内代码保持等宽（不被标题 bold 字体抹掉），
///    且字号跟随标题（等宽字号 == 标题字号，而非正文字号）。
@Test func headingInlineCode_keepsMonospaceAtHeadingSize() async throws {
  let source = "# 标题里的 `代码` 片段"
  let result = InkAttributedRenderer.render(source)

  var monoFont: UIFont?
  result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length), options: []) { value, _, _ in
    if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
      monoFont = font
    }
  }
  #expect(monoFont != nil)
  // 字号跟随 H1（19），而非正文（17）。
  #expect(monoFont?.pointSize == InkAppearance().heading.h1FontSize)
}

/// 2. heading + link：链接 run 用链接色 + 带 .link 属性；非链接 run 用标题色。两者共存不互覆盖。
@Test func headingLink_linkColorCoexistsWithHeadingColor() async throws {
  let source = "# 标题 [链接](https://example.com) 收尾"
  let result = InkAttributedRenderer.render(source)
  let full = NSRange(location: 0, length: result.length)

  var linkRunColor: UIColor?
  var hasLinkAttr = false
  var nonLinkColors: Set<UIColor> = []
  result.enumerateAttributes(in: full, options: []) { attrs, _, _ in
    let color = attrs[.foregroundColor] as? UIColor
    if attrs[.link] != nil {
      hasLinkAttr = true
      linkRunColor = color
    } else if let c = color {
      nonLinkColors.insert(c)
    }
  }
  #expect(hasLinkAttr)
  #expect(linkRunColor == InkAppearance().link.color)      // 链接色
  #expect(nonLinkColors.contains(InkAppearance().heading.color))  // 标题色仍在
  #expect(!nonLinkColors.contains(InkAppearance().link.color))    // 非链接 run 未被染成链接色
}

/// 3. blockquote + link：引用块里的链接保持链接色，周围文字保持引用色，二者共存。
@Test func blockquoteLink_bothColorsCoexist() async throws {
  let source = "> 引用里有 [链接](https://example.com) 和普通文字"
  let result = InkAttributedRenderer.render(source)
  let full = NSRange(location: 0, length: result.length)

  var linkRunColor: UIColor?
  var nonLinkColors: Set<UIColor> = []
  result.enumerateAttributes(in: full, options: []) { attrs, _, _ in
    let color = attrs[.foregroundColor] as? UIColor
    if attrs[.link] != nil {
      linkRunColor = color
    } else if let c = color {
      nonLinkColors.insert(c)
    }
  }
  #expect(linkRunColor == InkAppearance().link.color)             // 链接色
  #expect(nonLinkColors.contains(InkAppearance().blockquote.color))  // 引用色仍在
}

/// 4. list + inline code：列表项里的行内代码保留代码背景 attribute + 等宽字体。
@Test func listInlineCode_keepsBackgroundAndMonospace() async throws {
  let source = """
  - 列表项含 `代码`
  - 第二项
  """
  let result = InkAttributedRenderer.render(source)
  let full = NSRange(location: 0, length: result.length)

  var hasBackgroundAttr = false
  var codeRunIsMono = false
  result.enumerateAttributes(in: full, options: []) { attrs, _, _ in
    if attrs[.inkInlineCodeBackground] as? InkInlineCodeBackgroundInfo != nil {
      hasBackgroundAttr = true
      if let font = attrs[.font] as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
        codeRunIsMono = true
      }
    }
  }
  #expect(hasBackgroundAttr)
  #expect(codeRunIsMono)
}

/// 5. strong 里的 inline code 不加粗（monospaced() 重置字重，不继承 bold）。
@Test func strongInlineCode_codeStaysRegularWeight() async throws {
  let source = "**加粗中的 `代码`**"
  let result = InkAttributedRenderer.render(source)
  let full = NSRange(location: 0, length: result.length)

  var codeFont: UIFont?
  result.enumerateAttribute(.font, in: full, options: []) { value, _, _ in
    if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
      codeFont = font
    }
  }
  #expect(codeFont != nil)
  // 代码身份：等宽但不加粗。
  #expect(codeFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == false)
}

// MARK: - Helpers

private func extractParagraphStyle(from attrStr: NSAttributedString, at location: Int) -> NSParagraphStyle {
  guard attrStr.length > location else {
    return NSParagraphStyle.default
  }
  return attrStr.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle ?? NSParagraphStyle.default
}
