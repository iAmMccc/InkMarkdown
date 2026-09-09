//
//  InkThoughtBlockHandlerTests.swift
//  InkMarkdownTests
//

import Testing
import UIKit
@_spi(InkMarkdown) @testable import InkMarkdown

@Suite("InkThoughtBlockHandler 核心解析契约")
struct InkThoughtBlockHandlerTests {

  @Test("开闭思考标签必须同名，错误别名不能提前闭合")
  func scanner_requiresMatchingClosingTag() {
    let result = InkThoughtScanner.scan(
      from: "<think>第一步</thought>第二步</think>\n\n正式回答"
    )

    #expect(result?.isComplete == true)
    #expect(result?.thoughtBody == "第一步</thought>第二步")
    #expect(result?.suffixContent == "\n\n正式回答")

    let unclosed = InkThoughtScanner.scan(from: "<thought>仍在思考</think>")
    #expect(unclosed?.isComplete == false)
    #expect(unclosed?.thoughtBody == "仍在思考</think>")
  }

  @Test("非法思考标签安全降级，不进入递归 Block 路由")
  @MainActor
  func illegalTag_terminatesWithoutThoughtBlock() {
    let blocks = InkBlockRenderer.render(
      "<think class=\"x\">非法属性标签</think>"
    )

    #expect(!blocks.contains(where: { $0 is InkThoughtBlock }))
  }

  @Test("Thought suffix 的空行与缩进继续按标准 Markdown 路由")
  @MainActor
  func indentedSuffix_preservesMarkdownSemantics() throws {
    let source = "<think>思考过程</think>\n\n    let preserved = true\n"
    let result = try #require(InkThoughtScanner.scan(from: source))
    #expect(result.suffixContent == "\n\n    let preserved = true\n")

    let blocks = InkBlockRenderer.render(source)
    #expect(blocks.count == 2)
    #expect(blocks[1] is InkCodeBlock)
  }

  @Test("未闭合 Thought PREFIX 保持流式未完成状态")
  @MainActor
  func streamingThought_preservesIncompleteState() throws {
    let blocks = InkBlockRenderer.render("<think>\n正在深度思考中")
    let thought = try #require(blocks.first as? InkThoughtBlock)

    #expect(blocks.count == 1)
    #expect(thought.thought.contains("正在深度思考中"))
    #expect(thought.isComplete == false)
  }

  @Test("行内代码中的闭标签不提前结束 Thought")
  @MainActor
  func streamingScanner_ignoresClosingTagInsideInlineCode() throws {
    let source = """
    <think>
    1. 思考过程封装在 `<think>...</think>` 标签内。
    2. 这一行仍属于思考过程。
    </think>
    ## 正式回答
    """

    let split = InkThoughtScanner.splitStreamingSource(source)
    let expectedThought = try #require(split.thought)
    #expect(expectedThought.isComplete)
    #expect(expectedThought.thoughtBody.contains("这一行仍属于思考过程"))
    #expect(split.remainder.contains("正式回答"))

    var scanner = InkThoughtScanner.StreamingScanner()
    var incrementalThought = ""
    var incrementalRemainder = ""
    var finalPhase = InkThoughtScanner.StreamingScanner.Phase.prefixUndecided
    for character in source {
      let update = scanner.append(String(character))
      incrementalThought += update.thoughtBodyDelta
      incrementalRemainder += update.remainderDelta
      finalPhase = update.phase
    }

    #expect(incrementalThought == expectedThought.thoughtBody)
    #expect(incrementalRemainder == split.remainder)
    #expect(finalPhase == .thought(isComplete: true))

    let blocks = InkBlockRenderer.render(source)
    let renderedThought = try #require(blocks.first as? InkThoughtBlock)
    #expect(renderedThought.thought.contains("这一行仍属于思考过程"))
    #expect(
      (blocks.last as? InkAttributedTextBlock)?.attributedText.string.contains("正式回答") == true
    )
  }
}
