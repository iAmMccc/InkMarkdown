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
import InkMarkdown

@Suite("InkMarkdown SwiftUI 混编防死循环与尺寸测量测试")
@MainActor
struct InkMarkdownLoopPreventionTests {

  @Test("Coordinator updateStatic 在相同输入与配置下保持幂等，不重新分配子视图")
  func coordinatorUpdateStaticIsIdempotent() throws {
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

    // 第二次传入相同内容与配置
    coordinator.updateStatic(markdown: markdown, configuration: .standard)
    let secondSubviews = container.subviews

    #expect(initialSubviews.count == secondSubviews.count)
    for (i, view) in initialSubviews.enumerated() {
      #expect(view === secondSubviews[i], "视图指针应完全一致，不应重建")
    }
  }

  @Test("Coordinator updateStatic 在配置发生语义变化时会重新渲染")
  func coordinatorRerendersOnSemanticConfigurationChange() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container

    let markdown = "测试文本"
    var config1 = InkConfiguration.standard
    config1.appearance.text.fontSize = 16
    coordinator.updateStatic(markdown: markdown, configuration: config1)

    let firstTextView = try #require(container.subviews.first as? UITextView)
    let initialPointer = ObjectIdentifier(firstTextView)

    var config2 = InkConfiguration.standard
    config2.appearance.text.fontSize = 22
    coordinator.updateStatic(markdown: markdown, configuration: config2)

    let secondTextView = try #require(container.subviews.first as? UITextView)
    let secondPointer = ObjectIdentifier(secondTextView)

    #expect(initialPointer != secondPointer, "配置变更后应重新生成新视图")
  }

  @Test("InkConfiguration.isSemanticallyEqualTo 准确识别字号、间距与环境变化")
  func configurationEqualityCheck() {
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
  func blockViewsMeasureValidHeight() {
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
    container.updateBlocks(blocks, configuration: .standard)

    let containerSize = container.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    #expect(containerSize.height >= codeSize.height + breakSize.height + tableSize.height)
  }

  @Test("InkAttributedRenderer 能够在流式富文本阶段格式化输出表格内容")
  func attributedTableRendering() {
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

