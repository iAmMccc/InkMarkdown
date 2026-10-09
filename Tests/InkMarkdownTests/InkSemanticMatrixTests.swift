import Foundation
import Testing
import UIKit
@testable import InkMarkdown

// MARK: - CommonMark / GFM semantic matrix

/// Contracts not covered by the focused renderer tests.
///
/// These tests intentionally assert stable semantic properties (text, traits, links,
/// paragraph geometry, and routed block types) instead of serialized UIKit attributes
/// or pixel output. A limitation test is kept explicit where the public syntax contract
/// currently documents conservative behavior.
@Suite("CommonMark/GFM 渲染语义矩阵")
@MainActor
struct InkSemanticMatrixTests {

  @Test("H3-H6 使用标题色、加粗与对应固定行高")
  func headingLevels_threeThroughSixKeepHeadingSemantics() {
    var appearance = InkAppearance()
    appearance.supportsDynamicType = false
    appearance.text.color = .systemGreen
    appearance.heading.color = .systemPurple
    let configuration = InkConfiguration(appearance: appearance)

    for level in 3...6 {
      let title = "标题\(level)"
      let source = "\(String(repeating: "#", count: level)) \(title)"
      let snapshot = RenderSnapshotting.snapshot(
        source,
        configuration: configuration,
        appearance: appearance
      )
      let run = run(containing: title, in: snapshot)

      #expect(run?.attrs.isBold == true)
      #expect(run?.attrs.colorKey == .heading)
      #expect(run?.attrs.fontSize == appearance.heading.fontSize)
      #expect(run?.attrs.lineHeight == appearance.heading.lineHeight(forLevel: level))
    }
  }

  @Test("嵌套强调、加粗与删除线组合保留独立样式语义")
  func nestedInlineStyles_composeTraits() {
    let source = "***粗斜*** ~~**粗删**~~ ~~*斜删*~~"
    let snapshot = RenderSnapshotting.snapshot(source)

    let boldItalic = run(containing: "粗斜", in: snapshot)
    #expect(boldItalic?.attrs.isBold == true)
    #expect(boldItalic?.attrs.isItalic == true)
    #expect(boldItalic?.attrs.hasStrikethrough == false)

    let boldStrike = run(containing: "粗删", in: snapshot)
    #expect(boldStrike?.attrs.isBold == true)
    #expect(boldStrike?.attrs.isItalic == false)
    #expect(boldStrike?.attrs.hasStrikethrough == true)

    let italicStrike = run(containing: "斜删", in: snapshot)
    #expect(italicStrike?.attrs.isBold == false)
    #expect(italicStrike?.attrs.isItalic == true)
    #expect(italicStrike?.attrs.hasStrikethrough == true)
  }

  @Test("强调中的行内代码重置斜体并保留等宽背景")
  func inlineCode_resetsEmphasisTraits() {
    let snapshot = RenderSnapshotting.snapshot("*斜体中的 `代码`*")
    let code = run(containing: "代码", in: snapshot)

    #expect(code?.attrs.isMonospace == true)
    #expect(code?.attrs.isItalic == false)
    #expect(code?.attrs.isBold == false)
    #expect(code?.attrs.hasInlineCodeBackground == true)
  }

  @Test("Thought 富文本回落保留行内代码背景并隔离闭标签后正文")
  func thoughtFallback_preservesInlineCodeBackgroundAndSuffixBoundary() {
    var appearance = InkAppearance()
    appearance.supportsDynamicType = false
    appearance.thought.backgroundColor = .systemYellow
    appearance.inlineCode.backgroundColor = .systemPink
    let configuration = InkConfiguration(appearance: appearance)
    let source = "<think>\n思考中的 `代码`\n</think>正式回答"

    let snapshot = RenderSnapshotting.snapshot(
      source,
      configuration: configuration,
      appearance: appearance
    )
    let codeRun = run(containing: "代码", in: snapshot)
    #expect(codeRun?.attrs.isMonospace == true)
    #expect(codeRun?.attrs.hasInlineCodeBackground == true)

    let result = InkAttributedRenderer.render(source, configuration: configuration)
    guard let bodyRange = result.string.range(of: "思考中的"),
          let codeRange = result.string.range(of: "代码"),
          let suffixRange = result.string.range(of: "正式回答") else {
      Issue.record("Thought fallback 未保留预期正文或 suffix")
      return
    }

    let bodyAttributes = result.attributes(
      at: NSRange(bodyRange, in: result.string).location,
      effectiveRange: nil
    )
    let codeAttributes = result.attributes(
      at: NSRange(codeRange, in: result.string).location,
      effectiveRange: nil
    )
    let suffixAttributes = result.attributes(
      at: NSRange(suffixRange, in: result.string).location,
      effectiveRange: nil
    )

    #expect(bodyAttributes[.backgroundColor] as? UIColor == appearance.thought.backgroundColor)
    #expect(codeAttributes[.backgroundColor] as? UIColor == appearance.inlineCode.backgroundColor)
    #expect(codeAttributes[.inkInlineCodeBackground] as? InkInlineCodeBackgroundInfo != nil)
    #expect(suffixAttributes[.backgroundColor] as? UIColor != appearance.thought.backgroundColor)
    #expect(suffixAttributes[.inkInlineCodeBackground] == nil)
  }

  @Test("SoftBreak 转换为单个空格")
  func softBreak_becomesSingleSpace() {
    let snapshot = RenderSnapshotting.snapshot("第一行\n第二行")

    #expect(snapshot.plainText == "第一行 第二行")
    #expect(!snapshot.plainText.contains("\n"))
  }

  @Test("反斜杠硬换行转换为真实换行符")
  func backslashHardBreak_becomesNewline() {
    let snapshot = RenderSnapshotting.snapshot("第一行\\\n第二行")

    #expect(snapshot.plainText == "第一行\n第二行")
  }

  @Test("转义标点保持字面文本且不触发 Markdown 样式")
  func escapedPunctuation_remainsLiteral() {
    let source = "\\*literal\\* and \\[not a link](https://example.com) and \\# not heading"
    let snapshot = RenderSnapshotting.snapshot(source)

    #expect(snapshot.plainText == "*literal* and [not a link](https://example.com) and # not heading")
    RenderContractAssertions.noRun(
      snapshot,
      where: { $0.isBold || $0.isItalic || $0.hasLink },
      description: "转义标点不产生强调或链接"
    )
  }

  @Test("链接内的加粗与行内代码继承链接属性")
  func nestedLinkChildren_keepLinkSemantics() {
    let source = "[**加粗链接**](https://example.com) 与 [`代码链接`](https://example.com/code)"
    let snapshot = RenderSnapshotting.snapshot(source)

    let boldLink = run(containing: "加粗链接", in: snapshot)
    #expect(boldLink?.attrs.isBold == true)
    #expect(boldLink?.attrs.hasLink == true)
    #expect(boldLink?.attrs.colorKey == .link)

    let codeLink = run(containing: "代码链接", in: snapshot)
    #expect(codeLink?.attrs.isMonospace == true)
    #expect(codeLink?.attrs.hasInlineCodeBackground == true)
    #expect(codeLink?.attrs.hasLink == true)
    #expect(codeLink?.attrs.colorKey == .link)
  }

  @Test("标准自动链接产出 Link 属性")
  func standardAutolink_usesLinkAttribute() {
    let source = "<https://example.com>"
    let result = InkAttributedRenderer.render(source)
    var destinations: [String] = []

    result.enumerateAttribute(
      .link,
      in: NSRange(location: 0, length: result.length),
      options: []
    ) { value, _, _ in
      if let url = value as? URL {
        destinations.append(url.absoluteString)
      }
    }

    #expect(destinations == ["https://example.com"])
  }

  @Test("GFM 裸 URL 当前保守回退为普通文本")
  func gfmBareURL_fallsBackToPlainText() {
    // The pinned swift-markdown converter attaches table/strikethrough/tasklist
    // extensions only; without cmark-gfm autolink, a bare URL remains text.
    let result = InkAttributedRenderer.render("https://example.org/path")

    #expect(result.string == "https://example.org/path")
    #expect(result.attribute(.link, at: 0, effectiveRange: nil) == nil)
  }

  @Test("有序列表保留 Markdown 起始序号")
  func orderedList_honorsStartIndex() {
    let snapshot = RenderSnapshotting.snapshot("3. 第三项\n4. 第四项")

    #expect(snapshot.plainText == "3. 第三项\n4. 第四项")
  }

  @Test("多级列表的悬挂缩进递进增加")
  func nestedLists_increaseHangingIndent() {
    // common-syntax.md promises recursive list indentation; each nested list must
    // add its own marker width instead of reusing the outer width.
    let source = "- 外层\n  - 内层\n    - 深层"
    let result = InkAttributedRenderer.render(source)

    let outer = paragraphStyle(containing: "外层", in: result)
    let inner = paragraphStyle(containing: "内层", in: result)
    let deep = paragraphStyle(containing: "深层", in: result)

    #expect(outer?.firstLineHeadIndent == 0)
    #expect(outer?.headIndent ?? 0 > 0)
    #expect(inner?.headIndent ?? 0 > (outer?.headIndent ?? 0))
    #expect(deep?.headIndent ?? 0 > (inner?.headIndent ?? 0))
  }

  @Test("任务列表显示 checked 与 unchecked 标记")
  func taskList_usesCheckboxMarkers() {
    let snapshot = RenderSnapshotting.snapshot("- [ ] 待办\n- [x] 已完成\n- [X] 大写完成")

    #expect(snapshot.plainText == "☐ 待办\n☑ 已完成\n☑ 大写完成")
  }

  @Test("有序任务列表同时保留序号与 checkbox")
  func orderedTaskList_preservesOrdinalAndCheckboxMarkers() {
    let snapshot = RenderSnapshotting.snapshot("3. [ ] 待办\n4. [x] 已完成")

    #expect(snapshot.plainText == "3. ☐ 待办\n4. ☑ 已完成")
  }

  @Test("嵌套引用保持竖线标记并递进缩进")
  func nestedBlockquotes_increaseIndent() {
    let source = "> 外层引用\n>\n> > 内层引用"
    let result = InkAttributedRenderer.render(source)
    let fullRange = NSRange(location: 0, length: result.length)

    let outer = paragraphStyle(containing: "外层引用", in: result)
    let inner = paragraphStyle(containing: "内层引用", in: result)
    let hasBar = result.attribute(.inkBlockquoteBar, at: 0, effectiveRange: nil) != nil

    #expect(hasBar)
    #expect(inner?.headIndent ?? 0 > (outer?.headIndent ?? 0))
    #expect(result.attribute(.inkBlockquoteBar, at: fullRange.location, effectiveRange: nil) != nil)
  }

  @Test("GFM 表格解析保留列对齐、单元格 Markdown 与块路由")
  func gfmTable_preservesAlignmentAndRoutesAsBlock() {
    let source = """
    | 名称 | 值 | 备注 |
    | :--- | :---: | ---: |
    | **A** | `1` | [详情](https://example.com) |
    """
    let blocks = InkBlockRenderer.render(source)
    let table = blocks.first as? InkTableBlock

    #expect(blocks.count == 1)
    #expect(table != nil)
    #expect(table?.headers == ["名称", "值", "备注"])
    #expect(table?.rows.count == 1)
    #expect(table?.rows.first?.contains("**A**") == true)
    #expect(table?.rows.first?.contains("`1`") == true)
    #expect(table?.rows.first?.contains("[详情](https://example.com)") == true)
    #expect(table?.alignments == [.left, .center, .right])

    let snapshot = RenderSnapshotting.snapshot(source)
    #expect(run(containing: "名称", in: snapshot)?.attrs.isBold == true)
    #expect(run(containing: "1", in: snapshot)?.attrs.isMonospace == true)
    #expect(run(containing: "详情", in: snapshot)?.attrs.hasLink == true)
  }

  @Test("内置代码块、表格与分割线按顺序路由，正文保留富文本块")
  func builtInBlockHandlers_routeStableSequence() {
    let source = """
    前置正文

    ```swift
    let value = 1
    ```

    | A | B |
    | --- | --- |
    | 1 | 2 |

    ---

    后置正文
    """
    let blocks = InkBlockRenderer.render(source)

    #expect(blocks.count == 5)
    #expect(blocks[0] is InkAttributedTextBlock)
    #expect(blocks[1] is InkCodeBlock)
    #expect(blocks[2] is InkTableBlock)
    #expect(blocks[3] is InkThematicBreakBlock)
    #expect(blocks[4] is InkAttributedTextBlock)

    let code = blocks[1] as? InkCodeBlock
    #expect(code?.language == "swift")
    #expect(code?.code.contains("let value = 1") == true)
    #expect((blocks[0] as? InkAttributedTextBlock)?.attributedText.string.contains("前置正文") == true)
    #expect((blocks[4] as? InkAttributedTextBlock)?.attributedText.string.contains("后置正文") == true)
  }

  @Test("块 handler 返回 nil 时保守回落到富文本")
  func nilBlockHandler_fallsBackToAttributedText() {
    let configuration = InkConfiguration(blockHandlers: [NilBlockHandler()])
    let blocks = InkBlockRenderer.render(
      "```swift\nlet value = 1\n```",
      configuration: configuration
    )

    #expect(blocks.count == 1)
    #expect(blocks[0] is InkAttributedTextBlock)
    #expect((blocks[0] as? InkAttributedTextBlock)?.attributedText.string.contains("let value = 1") == true)
  }

  @Test("inline syntax 返回 nil 时回落到标准文本")
  func nilInlineSyntax_fallsBackToStandardText() {
    var configuration = InkConfiguration.standard
    configuration.inlineSyntaxes = [NilInlineSyntax()]
    let snapshot = RenderSnapshotting.snapshot(
      "普通文本",
      configuration: configuration,
      appearance: configuration.appearance
    )

    #expect(snapshot.plainText == "普通文本")
    #expect(snapshot.runs.count == 1)
    #expect(snapshot.runs[0].attrs.isBold == false)
  }

  @Test("已知限制：自定义 inline syntax 命中时不继承删除线")
  func knownLimitationCustomInlineSyntax_doesNotInheritStrikethrough() {
    var configuration = InkConfiguration.standard
    configuration.inlineSyntaxes = [MentionInlineSyntax()]
    let result = InkAttributedRenderer.render("~~@张三~~", configuration: configuration)

    #expect(result.string == "@张三")
    let attributes = result.attributes(at: 0, effectiveRange: nil)
    #expect(attributes[.strikethroughStyle] == nil)
  }

  @Test("InlineHTML br 转换为换行，自闭合未知标签保守丢弃")
  func inlineHTML_usesStableFallbackRules() {
    let result = InkAttributedRenderer.render("前<br>后 <widget data-id=\"1\"/>尾")

    #expect(result.string == "前\n后 尾")
  }

  private func run(containing text: String, in snapshot: RenderSnapshot) -> RenderSnapshot.Run? {
    guard let range = snapshot.plainText.range(of: text) else { return nil }
    let nsRange = NSRange(range, in: snapshot.plainText)
    let upperBound = nsRange.location + nsRange.length - 1
    return snapshot.runs.first {
      $0.range.lowerBound <= nsRange.location && $0.range.upperBound >= upperBound
    }
  }

  private func paragraphStyle(containing text: String, in result: NSAttributedString) -> NSParagraphStyle? {
    guard let range = result.string.range(of: text) else { return nil }
    let location = result.string.distance(from: result.string.startIndex, to: range.lowerBound)
    return result.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
  }
}

private struct NilInlineSyntax: InkInlineSyntax {
  func render(text: String, context: InkInlineContext) -> NSAttributedString? {
    nil
  }
}

private struct MentionInlineSyntax: InkInlineSyntax {
  func render(text: String, context: InkInlineContext) -> NSAttributedString? {
    guard text == "@张三" else { return nil }
    return NSAttributedString(
      string: text,
      attributes: [
        .font: context.baseFont,
        .foregroundColor: context.textColor,
      ]
    )
  }
}

private struct NilBlockHandler: InkBlockHandler {
  func canHandle(_ markup: Markup) -> Bool {
    markup is Markdown.CodeBlock
  }

  @MainActor
  func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    nil
  }
}
