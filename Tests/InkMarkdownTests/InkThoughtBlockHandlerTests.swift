//
//  InkThoughtBlockHandlerTests.swift
//  InkMarkdownTests
//

import Testing
import UIKit
@testable import InkMarkdown

@Suite("InkThoughtBlockHandler 思考过程块解析与渲染行为矩阵测试")
struct InkThoughtBlockHandlerTests {

  // MARK: - 1. 终止性与边界扫描测试

  @Test("InkThoughtScanner 精确匹配思考标签，严格排除非法前缀")
  func scannerExactTagMatching() {
    #expect(InkThoughtScanner.startsWithThoughtTag("<think>"))
    #expect(InkThoughtScanner.startsWithThoughtTag("<thought>"))
    #expect(InkThoughtScanner.startsWithThoughtTag("  <think >  "))
    #expect(InkThoughtScanner.startsWithThoughtTag("<THINK>"))
    #expect(InkThoughtScanner.startsWithThoughtTag("<Thought>"))

    // 非法前缀严格排除
    #expect(!InkThoughtScanner.startsWithThoughtTag("<thinker>"))
    #expect(!InkThoughtScanner.startsWithThoughtTag("<thinking>"))
    #expect(!InkThoughtScanner.startsWithThoughtTag("<think-box>"))
    #expect(!InkThoughtScanner.startsWithThoughtTag("<thoughtful>"))
    #expect(!InkThoughtScanner.startsWithThoughtTag("<think class=\"x\">"))
    #expect(!InkThoughtScanner.startsWithThoughtTag("普通文本 <think>"))
  }

  @Test("开闭思考标签必须同名，错误别名不能提前闭合")
  func scannerRequiresMatchingClosingTag() {
    let result = InkThoughtScanner.scan(from: "<think>第一步</thought>第二步</think>\n\n正式回答")

    #expect(result?.isComplete == true)
    #expect(result?.thoughtBody == "第一步</thought>第二步")
    #expect(result?.suffixContent == "\n\n正式回答")

    let unclosed = InkThoughtScanner.scan(from: "<thought>仍在思考</think>")
    #expect(unclosed?.isComplete == false)
    #expect(unclosed?.thoughtBody == "仍在思考</think>")
  }

  @Test("非法标签 <think class=\"x\"> 与 <thinker> 不会触发递归死循环并安全降级")
  @MainActor
  func illegalTagsTerminateWithoutRecursion() {
    let illegalSource1 = "<think class=\"x\">这是非法属性标签</think>"
    let blocks1 = InkBlockRenderer.render(illegalSource1)
    #expect(!blocks1.contains(where: { $0 is InkThoughtBlock }))

    let attr1 = InkAttributedRenderer.render(illegalSource1)
    // HTMLBlock 降级忽略，安全返回不崩溃
    #expect(!attr1.string.contains("💭"))

    let illegalSource2 = "<thinker>这是非思考标签</thinker>"
    let blocks2 = InkBlockRenderer.render(illegalSource2)
    #expect(!blocks2.contains(where: { $0 is InkThoughtBlock }))

    let attr2 = InkAttributedRenderer.render(illegalSource2)
    #expect(!attr2.string.contains("💭"))
  }

  // MARK: - 2. 尾随正文保全（Suffix Preservation）与数据完整性测试

  @Test("同节点内闭标签后的正文（Suffix Preservation）在 Block 路由通道 100% 保全")
  @MainActor
  func singleNodeSuffixPreservedInBlockRendering() {
    let source = "<think>思考过程第一步</think>这是正式回答的第一段。"
    let blocks = InkBlockRenderer.render(source)

    #expect(blocks.count == 2)
    #expect(blocks[0] is InkThoughtBlock)
    #expect(blocks[1] is InkAttributedTextBlock)

    if let thoughtBlock = blocks[0] as? InkThoughtBlock {
      #expect(thoughtBlock.thought == "思考过程第一步")
      #expect(thoughtBlock.isComplete == true)
    }

    if let textBlock = blocks[1] as? InkAttributedTextBlock {
      #expect(textBlock.attributedText.string.contains("这是正式回答的第一段。"))
    }
  }

  @Test("闭标签后的前导空行与代码缩进在 suffix 中保全")
  @MainActor
  func indentedSuffixPreservesMarkdownSemantics() throws {
    let source = "<think>思考过程</think>\n\n    let preserved = true\n"
    let result = try #require(InkThoughtScanner.scan(from: source))
    #expect(result.suffixContent == "\n\n    let preserved = true\n")

    let blocks = InkBlockRenderer.render(source)
    #expect(blocks.count == 2)
    #expect(blocks[1] is InkCodeBlock)
  }

  @Test("同节点内闭标签后的正文在富文本降级通道中 100% 保全且包含思考与正式正文")
  @MainActor
  func singleNodeSuffixPreservedInAttributedRendering() {
    let source = """
    <think>
    思考过程步骤
    </think>
    正式回答正文。
    """
    let attr = InkAttributedRenderer.render(source)

    #expect(attr.string.contains("💭 已深度思考"))
    #expect(attr.string.contains("思考过程步骤"))
    #expect(attr.string.contains("正式回答正文。"))
  }

  @Test("单行行内 <think> 标签在富文本通道中剥离标签并保留全部文本内容")
  @MainActor
  func inlineThoughtTagPreservesAllTextInAttributedRendering() {
    let source = "<think>思考过程步骤</think>正式回答正文。"
    let attr = InkAttributedRenderer.render(source)

    #expect(attr.string.contains("思考过程步骤"))
    #expect(attr.string.contains("正式回答正文。"))
    #expect(!attr.string.contains("<think>"))
    #expect(!attr.string.contains("</think>"))
  }

  @Test("多段跨行 <think> 标签（含空行）正确合并且保留后续 Markdown 节点")
  @MainActor
  func multiParagraphThoughtBlockWithBlankLinesAndSubsequentMarkdown() {
    let source = """
    <think>
    第一步：理解用户需求。

    第二步：分析可能的边界情况。

    第三步：总结最终结论。
    </think>

    ## 最终结论

    这是回答内容。
    """
    let blocks = InkBlockRenderer.render(source)
    #expect(blocks.count >= 2)
    #expect(blocks[0] is InkThoughtBlock)

    if let thoughtBlock = blocks[0] as? InkThoughtBlock {
      #expect(thoughtBlock.thought.contains("第一步：理解用户需求。"))
      #expect(thoughtBlock.thought.contains("第二步：分析可能的边界情况。"))
      #expect(thoughtBlock.thought.contains("第三步：总结最终结论。"))
      #expect(thoughtBlock.isComplete == true)
    }

    let trailingText = blocks.compactMap { ($0 as? InkAttributedTextBlock)?.attributedText.string }.joined(separator: "\n")
    #expect(trailingText.contains("最终结论"))
    #expect(trailingText.contains("这是回答内容。"))
  }

  @Test("<thought> 别名标签完整支持")
  @MainActor
  func thoughtAliasTag() {
    let source = """
    <thought>
    思考一下...
    </thought>

    回答正文。
    """
    let blocks = InkBlockRenderer.render(source)
    #expect(blocks.count == 2)
    #expect(blocks[0] is InkThoughtBlock)
    if let thoughtBlock = blocks[0] as? InkThoughtBlock {
      #expect(thoughtBlock.thought == "思考一下...")
      #expect(thoughtBlock.isComplete == true)
    }
  }

  // MARK: - 3. 流式中途态与标题生命周期测试

  @Test("未闭合的 <think> 标签（流式中途态）解析为 isComplete == false 并展示进行中文案")
  @MainActor
  func unclosedStreamingThoughtBlockLifecycle() {
    let source = """
    <think>
    正在深度思考中，尚未闭合标签...
    """
    let blocks = InkBlockRenderer.render(source)
    #expect(blocks.count == 1)
    #expect(blocks[0] is InkThoughtBlock)
    if let thoughtBlock = blocks[0] as? InkThoughtBlock {
      #expect(thoughtBlock.thought.contains("正在深度思考中"))
      #expect(thoughtBlock.isComplete == false)

      let view = thoughtBlock.makeView() as! InkThoughtBlockView
      #expect(view.headerContainer.accessibilityLabel == thoughtBlock.config.title)
    }

    let attr = InkAttributedRenderer.render(source)
    #expect(attr.string.contains("💭 思考过程"))
    #expect(attr.string.contains("正在深度思考中"))
  }

  // MARK: - 4. 原生视图交互、折叠状态模型与可访问性测试

  @Test("InkThoughtBlockView 点击 Header 触发折叠展开切换及尺寸动态变化")
  @MainActor
  func thoughtBlockViewHeaderTapInteractionAndSizing() {
    var thoughtAppearance = InkAppearance.Thought()
    thoughtAppearance.isCollapsible = true
    thoughtAppearance.isInitiallyCollapsed = true

    let longThought = """
    第 1 步：分析输入条件
    第 2 步：推导状态方程
    第 3 步：计算渐进复杂度
    第 4 步：得出最终结论
    """
    let block = InkThoughtBlock(
      thought: longThought,
      isComplete: true,
      config: thoughtAppearance, renderConfiguration: .standard
    )
    guard let view = block.makeView() as? InkThoughtBlockView else {
      Issue.record("Expected InkThoughtBlockView")
      return
    }

    // 1. 初始折叠状态
    #expect(view.isCollapsed == true)
    #expect(view.headerContainer.accessibilityTraits.contains(.button))
    #expect(view.headerContainer.accessibilityValue == "已折叠")
    let collapsedSize = view.sizeThatFits(CGSize(width: 320, height: 1000))
    #expect(collapsedSize.height > 0)
    #expect(collapsedSize.height <= 60)

    // 2. 模拟点击 Header 展开
    view.handleHeaderTap()
    #expect(view.isCollapsed == false)
    #expect(view.headerContainer.accessibilityValue == "已展开")
    let expandedSize = view.sizeThatFits(CGSize(width: 320, height: 1000))
    #expect(expandedSize.height > collapsedSize.height + 40)

    // 3. 再次点击 Header 折叠
    view.handleHeaderTap()
    #expect(view.isCollapsed == true)
    #expect(view.headerContainer.accessibilityValue == "已折叠")
    let reCollapsedSize = view.sizeThatFits(CGSize(width: 320, height: 1000))
    #expect(reCollapsedSize.height == collapsedSize.height)
  }

  @Test("非可折叠配置（isCollapsible == false）严格归一化为不可折叠态")
  @MainActor
  func nonCollapsibleConfigurationNormalization() {
    var config = InkAppearance.Thought()
    config.isCollapsible = false
    config.isInitiallyCollapsed = true // 冲突非法配置

    let block = InkThoughtBlock(thought: "思考细节", isComplete: true, config: config, renderConfiguration: .standard)
    guard let view = block.makeView() as? InkThoughtBlockView else {
      Issue.record("Expected InkThoughtBlockView")
      return
    }

    #expect(view.isCollapsed == false)
    #expect(view.headerContainer.accessibilityTraits.contains(.header))
    #expect(!view.headerContainer.accessibilityTraits.contains(.button))
    #expect(view.headerContainer.accessibilityValue == nil)
  }

  // MARK: - 5. splitStreamingSource 与 apply 契约

  @Test("splitStreamingSource：未闭合 PREFIX 思考标签 remainder 为空")
  func splitStreamingSourceUnclosedPrefix() {
    let source = "<think>\n正在思考..."
    let split = InkThoughtScanner.splitStreamingSource(source)
    #expect(split.thought != nil)
    #expect(split.thought?.isComplete == false)
    #expect(split.remainder.isEmpty)
  }

  @Test("splitStreamingSource：已闭合 PREFIX 思考标签 remainder 为闭标签后 suffix")
  func splitStreamingSourceClosedWithSuffix() {
    let source = "<think>步骤一</think>\n\n正式回答"
    let split = InkThoughtScanner.splitStreamingSource(source)
    #expect(split.thought?.isComplete == true)
    #expect(split.remainder.contains("正式回答"))
  }

  @Test("splitStreamingSource：非 PREFIX 文本 thought 为 nil，remainder 为全文")
  func splitStreamingSourceNonPrefix() {
    let source = "普通回答 <think>不应匹配</think>"
    let split = InkThoughtScanner.splitStreamingSource(source)
    #expect(split.thought == nil)
    #expect(split.remainder == source)
  }

  @Test("InkThoughtBlockView.apply 更新正文与标题但不重置 isCollapsed")
  @MainActor
  func applyPreservesCollapsedState() {
    var thoughtAppearance = InkAppearance.Thought()
    thoughtAppearance.isCollapsible = true
    thoughtAppearance.isInitiallyCollapsed = true

    let view = InkThoughtBlockView(
      thought: "初始思考",
      isComplete: false,
      config: thoughtAppearance, renderConfiguration: .standard
    )
    #expect(view.isCollapsed == true)

    view.apply(thought: "更新后的思考正文", isComplete: true)
    #expect(view.isCollapsed == true)
    #expect(view.isComplete == true)
    #expect(view.headerContainer.accessibilityLabel == thoughtAppearance.completedTitle)

    view.handleHeaderTap()
    #expect(view.isCollapsed == false)
  }

  @Test("handleHeaderTap 同步写入 onToggleCollapse，不等待动画完成")
  @MainActor
  func handleHeaderTapWritesCollapseImmediately() {
    var thoughtAppearance = InkAppearance.Thought()
    thoughtAppearance.isCollapsible = true
    thoughtAppearance.isInitiallyCollapsed = false

    var callbackCollapsed: Bool?
    let view = InkThoughtBlockView(
      thought: "思考正文",
      isComplete: true,
      config: thoughtAppearance, renderConfiguration: .standard
    )
    view.onToggleCollapse = { callbackCollapsed = $0 }

    view.handleHeaderTap()
    #expect(callbackCollapsed == true)
    #expect(view.isCollapsed == true)
  }

  @Test("apply(isCollapsed:) 同步折叠可见性，避免 alpha 与折叠态不一致")
  @MainActor
  func applySyncsCollapsedVisualState() {
    var thoughtAppearance = InkAppearance.Thought()
    thoughtAppearance.isCollapsible = true
    thoughtAppearance.isInitiallyCollapsed = false

    let longThought = """
    第 1 步：分析输入条件
    第 2 步：推导状态方程
    第 3 步：计算渐进复杂度
    """
    let view = InkThoughtBlockView(
      thought: longThought,
      isComplete: true,
      config: thoughtAppearance, renderConfiguration: .standard
    )
    let expandedSize = view.sizeThatFits(CGSize(width: 320, height: 1000))

    view.apply(thought: longThought + "\n第 4 步：追加", isComplete: true, isCollapsed: true)
    #expect(view.isCollapsed == true)
    let collapsedSize = view.sizeThatFits(CGSize(width: 320, height: 1000))
    #expect(collapsedSize.height < expandedSize.height)
    #expect(collapsedSize.height <= 60)
  }

  @Test("InkThoughtScanner.stripThoughtTags 剥离非首位及成对标签并保留合法文本")
  func stripThoughtTagsRemovesInlineAndMiddleTags() {
    let source1 = "前置文本 <think> 思考正文 </think> 后置文本"
    let stripped1 = InkThoughtScanner.stripThoughtTags(from: source1)
    #expect(stripped1 == "前置文本  思考正文  后置文本")

    let source2 = "多标签测试 <thought>思路A</thought> 正文 <think >思路B</think > 尾部"
    let stripped2 = InkThoughtScanner.stripThoughtTags(from: source2)
    #expect(stripped2 == "多标签测试 思路A 正文 思路B 尾部")

    // 非思考标签保留不被误删
    let source3 = "<thinker>保留</thinker> 与 <thinking>保留</thinking>"
    let stripped3 = InkThoughtScanner.stripThoughtTags(from: source3)
    #expect(stripped3 == source3)
  }

  @Test("apply(config:renderConfiguration:) 同步刷新配置与外观样式")
  @MainActor
  func applyUpdatesConfigurationAndAppearance() {
    var initialAppearance = InkAppearance.Thought()
    initialAppearance.backgroundColor = .systemGray
    initialAppearance.headerColor = .black
    let initialConfig = InkConfiguration.standard

    let view = InkThoughtBlockView(
      thought: "思考细节",
      isComplete: false,
      config: initialAppearance,
      renderConfiguration: initialConfig
    )

    var updatedAppearance = initialAppearance
    updatedAppearance.backgroundColor = .systemPurple
    updatedAppearance.headerColor = .white
    var updatedConfig = initialConfig
    updatedConfig.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: .dark)

    view.apply(
      thought: "新思考细节",
      isComplete: true,
      config: updatedAppearance,
      renderConfiguration: updatedConfig
    )

    #expect(view.config.backgroundColor == .systemPurple)
    #expect(view.config.headerColor == .white)
    #expect(view.renderConfiguration.renderEnvironment.userInterfaceStyle == .dark)
  }
}
