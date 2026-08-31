//
//  AccessibilityAndDynamicTypeTests.swift
//  InkMarkdownTests
//

import Testing
import UIKit
@testable import InkMarkdown

@Suite("InkMarkdown 可访问性 (VoiceOver) 与 Dynamic Type 测试矩阵")
@MainActor
struct AccessibilityAndDynamicTypeTests {

  // MARK: - 1. 思考过程块 (InkThoughtBlockView) 可访问性

  @Test("InkThoughtBlockView 折叠与展开状态下提供精准的 VoiceOver 语义与提示")
  func thoughtBlockAccessibilitySemantics() {
    var thoughtConfig = InkAppearance.Thought()
    thoughtConfig.isCollapsible = true
    thoughtConfig.isInitiallyCollapsed = true
    thoughtConfig.title = "正在思考中"
    thoughtConfig.completedTitle = "已深度思考"

    let block = InkThoughtBlock(
      thought: "推导过程第 1 步\n推导过程第 2 步",
      isComplete: true,
      config: thoughtConfig, renderConfiguration: .standard
    )

    let view = block.makeView() as! InkThoughtBlockView

    // 1. 初始折叠态 VoiceOver 校验
    #expect(view.headerContainer.isAccessibilityElement == true)
    #expect(view.headerContainer.accessibilityTraits.contains(.button))
    #expect(view.headerContainer.accessibilityLabel == "已深度思考")
    #expect(view.headerContainer.accessibilityValue == "已折叠")
    #expect(view.headerContainer.accessibilityHint == "连按两次展开思考过程")

    // 2. 点击展开后 VoiceOver 语义状态更新
    view.handleHeaderTap()
    #expect(view.headerContainer.accessibilityValue == "已展开")
    #expect(view.headerContainer.accessibilityHint == "连按两次折叠思考过程")

    // 3. 流式中途态（未完成）文案校验
    let streamingBlock = InkThoughtBlock(
      thought: "实时思考中...",
      isComplete: false,
      config: thoughtConfig, renderConfiguration: .standard
    )
    let streamingView = streamingBlock.makeView() as! InkThoughtBlockView
    #expect(streamingView.headerContainer.accessibilityLabel == "正在思考中")
  }

  @Test("不可折叠思考卡片 (isCollapsible == false) 的 VoiceOver 特征降级为 .header")
  func nonCollapsibleThoughtBlockAccessibilityTraits() {
    var thoughtConfig = InkAppearance.Thought()
    thoughtConfig.isCollapsible = false

    let block = InkThoughtBlock(
      thought: "思考细节内容",
      isComplete: true,
      config: thoughtConfig, renderConfiguration: .standard
    )

    let view = block.makeView() as! InkThoughtBlockView
    #expect(view.headerContainer.accessibilityTraits.contains(.header))
    #expect(!view.headerContainer.accessibilityTraits.contains(.button))
    #expect(view.headerContainer.accessibilityValue == nil)
    #expect(view.headerContainer.accessibilityHint == nil)
  }

  // MARK: - 2. 代码块与分割线可访问性

  @Test("InkCodeBlockView 提供代码语言与代码内容的无障碍辅助描述")
  func codeBlockAccessibilityDescription() {
    let block = InkCodeBlock(code: "let answer = 42\nprint(answer)", language: "swift")
    let view = block.makeView()

    #expect(view.isAccessibilityElement == true)
    #expect(view.accessibilityLabel == "swift 代码块")
    #expect(view.accessibilityValue?.contains("let answer = 42") == true)
  }

  @Test("InkThematicBreakView 提供分割线无障碍标签")
  func thematicBreakAccessibilityLabel() {
    let block = InkThematicBreakBlock()
    let view = block.makeView()

    #expect(view.isAccessibilityElement == true)
    #expect(view.accessibilityLabel == "分割线")
  }

  // MARK: - 3. Dynamic Type 与自适应字号排版

  @Test("大字号 Dynamic Type 配置下正文与标题行高正确缩放且不截断")
  func dynamicTypeScalingRendersValidLineHeights() {
    var config = InkConfiguration.standard
    // 模拟超大字体辅助模式 (Accessibility XXL)
    config.appearance.text.fontSize = 28
    config.appearance.text.lineHeight = 38
    config.appearance.heading.h1FontSize = 36
    config.appearance.heading.h1LineHeight = 46

    let source = """
    # 大字号主标题
    这是在超大字号排版下渲染的正文内容，包含足够的文本以跨越多行排版。
    """

    let rendered = InkAttributedRenderer.render(source, configuration: config)
    #expect(rendered.length > 0)

    let blocks = InkBlockRenderer.render(source, configuration: config)
    #expect(!blocks.isEmpty)

    let textBlock = blocks.first(where: { $0 is InkAttributedTextBlock }) as? InkAttributedTextBlock
    #expect(textBlock != nil)
    let view = textBlock!.makeView()
    let size = view.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
    #expect(size.height > 60)
  }

  @Test("表格列宽测量、流式 cell 字体与行高使用同一 Dynamic Type trait")
  func tableWidthMeasurementUsesScaledFont() {
    var normal = InkConfiguration.standard
    normal.renderEnvironment = InkRenderEnvironment(contentSizeCategory: .large)
    var accessibility = normal
    accessibility.renderEnvironment = InkRenderEnvironment(
      contentSizeCategory: .accessibilityExtraExtraExtraLarge
    )

    let headers = ["Column"]
    let rows = [["Dynamic Type table measurement"]]
    let normalWidths = InkTableRenderHelper.measureColumnContentWidths(
      headers: headers,
      rows: rows,
      config: normal.appearance.table,
      configuration: normal,
      containerWidth: 2_000
    )
    let accessibilityWidths = InkTableRenderHelper.measureColumnContentWidths(
      headers: headers,
      rows: rows,
      config: accessibility.appearance.table,
      configuration: accessibility,
      containerWidth: 2_000
    )

    #expect(normalWidths.count == 1)
    #expect(accessibilityWidths.count == 1)
    #expect(accessibilityWidths[0] > normalWidths[0])

    // 保持内容宽度低于最窄支持设备的 columnMaxWidthRatio 上限，
    // 否则普通与辅助功能字号都会被 clamp 成同一宽度，测试只会验证设备尺寸。
    let streamHeaders = ["Column", "Value"]
    let streamRows = [["Content", "1"]]
    let normalStream = InkStreamTableView(layoutMode: .scroll, configuration: normal)
    normalStream.setHeaders(streamHeaders, referenceRows: streamRows)
    normalStream.appendRow(streamRows[0])
    let accessibilityStream = InkStreamTableView(layoutMode: .scroll, configuration: accessibility)
    accessibilityStream.setHeaders(streamHeaders, referenceRows: streamRows)
    accessibilityStream.appendRow(streamRows[0])

    let normalCell = descendants(of: UITextView.self, in: normalStream)[0]
    let accessibilityCell = descendants(of: UITextView.self, in: accessibilityStream)[0]
    let normalHelperFont = InkTableRenderHelper.font(
      isHeader: true,
      config: normal.appearance.table,
      configuration: normal
    )
    let accessibilityHelperFont = InkTableRenderHelper.font(
      isHeader: true,
      config: accessibility.appearance.table,
      configuration: accessibility
    )
    let normalFont = normalCell.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
    let accessibilityFont = accessibilityCell.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
    let normalParagraph = normalCell.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    let accessibilityParagraph = accessibilityCell.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
    let normalWidth = widthConstraintConstants(in: normalStream).max() ?? 0
    let accessibilityWidth = widthConstraintConstants(in: accessibilityStream).max() ?? 0

    #expect(accessibilityHelperFont.pointSize > normalHelperFont.pointSize)
    #expect(accessibilityFont?.pointSize == accessibilityHelperFont.pointSize)
    #expect(normalFont?.pointSize == normalHelperFont.pointSize)
    #expect((accessibilityParagraph?.minimumLineHeight ?? 0) > (normalParagraph?.minimumLineHeight ?? 0))
    #expect(accessibilityWidth > normalWidth)
  }

  private func descendants<T: UIView>(of type: T.Type, in root: UIView) -> [T] {
    root.subviews.flatMap { view -> [T] in
      let current = (view as? T).map { [$0] } ?? []
      return current + descendants(of: type, in: view)
    }
  }

  private func widthConstraintConstants(in root: UIView) -> [CGFloat] {
    let own = root.constraints.compactMap { constraint -> CGFloat? in
      guard constraint.firstAttribute == .width, constraint.constant > 1 else { return nil }
      return constraint.constant
    }
    return own + root.subviews.flatMap(widthConstraintConstants(in:))
  }
}
