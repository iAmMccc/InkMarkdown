//
//  InkMarkdownLoopPreventionTests.swift
//  InkMarkdownSwiftUITests
//
//  Created by InkMarkdown on 2026/8/18.
//

import Testing
import UIKit
import SwiftUI
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

private final class TestLinkHandlerState: @unchecked Sendable {
  var callCount = 0
  let result: Bool

  init(result: Bool) {
    self.result = result
  }
}

@Suite("InkMarkdown SwiftUI 混编防死循环与尺寸测量测试")
@MainActor
struct InkMarkdownLoopPreventionTests {

  @Test("Coordinator updateStatic 在相同输入与配置下保持幂等且不重复测量")
  func coordinator_updateStaticIsIdempotent() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container

    let markdown = """
    # 标题
    正文内容一段。
    ```swift
    let x = 1
    ```
    | A | B |
    |---|---|
    | 1 | 2 |
    """

    coordinator.updateStatic(markdown: markdown, configuration: .standard)
    let initialSubviews = container.subviews
    #expect(!initialSubviews.isEmpty)
    let firstSize = container.sizeThatFits(
      CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)
    )
    let firstMeasurementCount = container.blockMeasurementInvocationCount

    // 第二次传入相同内容与配置
    coordinator.updateStatic(markdown: markdown, configuration: .standard)
    let secondSubviews = container.subviews
    let secondSize = container.sizeThatFits(
      CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)
    )
    let secondMeasurementCount = container.blockMeasurementInvocationCount

    #expect(initialSubviews.count == secondSubviews.count)
    #expect(secondSize == firstSize)
    #expect(firstMeasurementCount > 0)
    #expect(secondMeasurementCount == 0)
  }

  @Test("Coordinator updateStatic 在配置发生语义变化时更新可见语义")
  func coordinator_rerendersOnSemanticConfigurationChange() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container

    let markdown = "测试文本"
    var config1 = InkConfiguration.standard
    config1.appearance.text.fontSize = 16
    coordinator.updateStatic(markdown: markdown, configuration: config1)

    let firstTextView = try #require(container.subviews.first as? UITextView)
    let firstFont = try #require(
      firstTextView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
    )
    #expect(firstFont.pointSize == 16)

    var config2 = InkConfiguration.standard
    config2.appearance.text.fontSize = 22
    coordinator.updateStatic(markdown: markdown, configuration: config2)

    let secondTextView = try #require(container.subviews.first as? UITextView)
    let secondFont = try #require(
      secondTextView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
    )
    #expect(secondFont.pointSize == 22)
  }

  @Test("Coordinator 依据稳定语义身份保持或更新链接回调")
  func coordinator_updatesLinkBehaviorForSemanticIdentity() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    let markdown = "[链接](https://example.com)"
    let url = URL(string: "https://example.com")!

    let firstState = TestLinkHandlerState(result: true)
    var first = InkConfiguration.standard
    first.setLinkTapHandler({ _, _ in
      firstState.callCount += 1
      return firstState.result
    }, semanticIdentity: "links.v1")
    coordinator.updateStatic(markdown: markdown, configuration: first)
    let firstTextView = try #require(container.subviews.first as? UITextView)
    #expect(firstTextView.delegate?.textView?(
      firstTextView,
      shouldInteractWith: url,
      in: NSRange(location: 0, length: 2),
      interaction: .invokeDefaultAction
    ) == false)
    #expect(firstState.callCount == 1)

    let equivalentState = TestLinkHandlerState(result: true)
    var equivalent = InkConfiguration.standard
    equivalent.setLinkTapHandler({ _, _ in
      equivalentState.callCount += 1
      return equivalentState.result
    }, semanticIdentity: "links.v1")
    coordinator.updateStatic(markdown: markdown, configuration: equivalent)
    let equivalentTextView = try #require(container.subviews.first as? UITextView)
    #expect(equivalentTextView.delegate?.textView?(
      equivalentTextView,
      shouldInteractWith: url,
      in: NSRange(location: 0, length: 2),
      interaction: .invokeDefaultAction
    ) == false)
    #expect(firstState.callCount == 2)
    #expect(equivalentState.callCount == 0)

    let changedState = TestLinkHandlerState(result: false)
    var changed = InkConfiguration.standard
    changed.setLinkTapHandler({ _, _ in
      changedState.callCount += 1
      return changedState.result
    }, semanticIdentity: "links.v2")
    coordinator.updateStatic(markdown: markdown, configuration: changed)
    let changedTextView = try #require(container.subviews.first as? UITextView)
    #expect(changedTextView.delegate?.textView?(
      changedTextView,
      shouldInteractWith: url,
      in: NSRange(location: 0, length: 2),
      interaction: .invokeDefaultAction
    ) == true)
    #expect(changedState.callCount == 1)
  }

  @Test("InkConfiguration.isSemanticallyEqualTo 准确识别字号、间距与环境变化")
  func configuration_equalityCheck() {
    let config1 = InkConfiguration.standard
    var config2 = InkConfiguration.standard
    #expect(config1.isSemanticallyEqualTo(config2))

    config2.appearance.text.fontSize = 20
    #expect(!config1.isSemanticallyEqualTo(config2))

    config2.appearance.text.fontSize = config1.appearance.text.fontSize
    #expect(config1.isSemanticallyEqualTo(config2))

    config2.appearance.text.paragraphSpacing = 6
    #expect(!config1.isSemanticallyEqualTo(config2))

    config2.appearance.text.paragraphSpacing = config1.appearance.text.paragraphSpacing
    config2.renderEnvironment.userInterfaceStyle = .dark
    #expect(!config1.isSemanticallyEqualTo(config2))
  }

  @Test("各 Block View 在 sizeThatFits 下返回有效正数高度且无约束冲突")
  func blockViews_measureValidHeight() {
    let width: CGFloat = 360

    // 1. Code Block
    let codeBlock = InkCodeBlock(code: "func test() {\n  return 42\n}")
    let codeView = codeBlock.makeView()
    let codeSize = codeView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    #expect(codeSize.height > 20)
    #expect(codeSize.width == width)

    // 2. Thematic Break
    let breakBlock = InkThematicBreakBlock()
    let breakView = breakBlock.makeView()
    let breakSize = breakView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    #expect(breakSize.height > 0)
    #expect(breakSize.width == width)

    // 3. Table Block
    let tableBlock = InkTableBlock(
      headers: ["Key", "Value"],
      rows: [["Name", "InkMarkdown"], ["Platform", "iOS"]],
      alignments: [.left, .right]
    )
    let tableView = tableBlock.makeView()
    let tableSize = tableView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    #expect(tableSize.height > 30)
    #expect(tableSize.width == width)

    // 4. Container View
    let container = InkMarkdownContainerView()
    let blocks: [InkRenderableBlock] = [codeBlock, breakBlock, tableBlock]
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    coordinator.updateBlocks(blocks, configuration: .standard)

    let containerSize = container.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    #expect(containerSize.height >= codeSize.height + breakSize.height + tableSize.height)
  }

  @Test("InkAttributedRenderer 能够在流式富文本阶段格式化输出表格内容")
  func attributedTable_rendering() {
    let markdown = """
    | 语言 | 平台 |
    |---|---|
    | Swift | iOS |
    | Kotlin | Android |
    """
    let attributed = InkAttributedRenderer.render(markdown)
    let string = attributed.string
    #expect(string.contains("语言"))
    #expect(string.contains("平台"))
    #expect(string.contains("Swift"))
    #expect(string.contains("iOS"))
    #expect(string.contains("│"))
  }
}
