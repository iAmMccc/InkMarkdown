import Testing
import UIKit
@testable import InkMarkdown

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

  // 行内代码 14pt 的 baselineOffset 应大于正文 17pt 的
  var codeOffset: CGFloat = 0
  var bodyOffset: CGFloat = 0
  result.enumerateAttributes(in: NSRange(location: 0, length: result.length), options: []) { attrs, _, _ in
    guard let font = attrs[.font] as? UIFont,
          let offset = attrs[.baselineOffset] as? CGFloat else { return }
    if font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) {
      codeOffset = offset
    } else {
      bodyOffset = offset
    }
  }
  #expect(codeOffset > bodyOffset)
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

  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.minimumLineHeight == 28)
  #expect(para.maximumLineHeight == 28)
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
  let theme = InkTheme(bodyFontSize: 30, bodyLineHeight: 28)
  let config = InkConfiguration(theme: theme)
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

  // 第一段的 paragraphSpacing 应为 24pt
  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.paragraphSpacing == 24)
}

@Test func listItemSpacing() async throws {
  let source = """
  1. 第一条
  2. 第二条
  """
  let result = InkAttributedRenderer.render(source)

  // 第一个列表项的 paragraphSpacing 应为 listItemSpacing (16pt)
  let para = extractParagraphStyle(from: result, at: 0)
  #expect(para.paragraphSpacing == 16)
}

@Test func theme_defaultValues() async throws {
  let theme = InkTheme.standard
  #expect(theme.bodyFontSize == 17)
  #expect(theme.codeFontSize == 14)
  #expect(theme.h1FontSize == 19)
  #expect(theme.headingFontSize == 17)
  #expect(theme.bodyLineHeight == 28)
  #expect(theme.h1LineHeight == 30)
  #expect(theme.codeLineHeight == 28)
  #expect(theme.tableLineHeight == 20)
  #expect(theme.paragraphSpacing == 24)
  #expect(theme.innerParagraphSpacing == 12)
  #expect(theme.h1SpacingAfter == 16)
  #expect(theme.headingSpacingAfter == 8)
  #expect(theme.listItemSpacing == 16)
  #expect(theme.listSpacingAfter == 24)
  #expect(theme.thematicBreakHeight == 1)
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

// MARK: - Helpers

private func extractParagraphStyle(from attrStr: NSAttributedString, at location: Int) -> NSParagraphStyle {
  guard attrStr.length > location else {
    return NSParagraphStyle.default
  }
  return attrStr.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle ?? NSParagraphStyle.default
}
