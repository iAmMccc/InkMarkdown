//
//  InkThoughtBlockHandler.swift
//  InkMarkdown
//

import UIKit
import Markdown

/// 思考过程（`<think>...</think>` 或 `<thought>...</thought>`）块级处理器。
///
/// 识别 Markdown AST 中的思考标签，将其解析为原生可交互的 `InkThoughtBlock`（`InkThoughtBlockView` 卡片），
/// 并通过 `InkThoughtScanner` 实现数学收敛的语法解析与尾随正文（Suffix Preservation）续接渲染。
public struct InkThoughtBlockHandler: InkBlockHandler, InkConfigurationSemanticsProviding {

  public init() {}

  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    other is InkThoughtBlockHandler
  }

  public func canHandle(_ markup: Markup) -> Bool {
    InkThoughtScanner.startsWithThoughtTag(textContent(of: markup))
  }

  @preconcurrency @MainActor
  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    let rawText = textContent(of: markup)
    guard let parsed = InkThoughtScanner.scan(from: rawText) else { return nil }
    return InkThoughtPresentationPolicy.makeBlock(from: parsed, configuration: configuration)
  }

  /// 单 Block 消费（向后兼容实现）。
  @preconcurrency @MainActor
  public func consume(
    from children: [Markup],
    startingAt index: Int,
    configuration: InkConfiguration
  ) -> (block: InkRenderableBlock, consumedCount: Int)? {
    guard let result = consumeBlocks(from: children, startingAt: index, configuration: configuration),
          let firstBlock = result.blocks.first else {
      return nil
    }
    return (firstBlock, result.consumedCount)
  }

  /// 多 Block 消费实现：支持拆解出 ThoughtBlock 卡片，并将闭合标签后的尾随正文无缝转交下游渲染。
  @preconcurrency @MainActor
  public func consumeBlocks(
    from children: [Markup],
    startingAt index: Int,
    configuration: InkConfiguration
  ) -> (blocks: [InkRenderableBlock], consumedCount: Int)? {
    guard index < children.count else { return nil }
    let firstMarkup = children[index]
    guard canHandle(firstMarkup) else { return nil }

    var collectedTexts: [String] = []
    var scanIndex = index

    while scanIndex < children.count {
      let currentMarkup = children[scanIndex]
      let text = textContent(of: currentMarkup)
      collectedTexts.append(text)

      // 使用统一的 InkThoughtScanner 扫描已收集的文本序列
      if let parsed = InkThoughtScanner.scan(from: collectedTexts), parsed.isComplete {
        let thoughtBlock = InkThoughtPresentationPolicy.makeBlock(
          from: parsed,
          configuration: configuration
        )
        var resultBlocks: [InkRenderableBlock] = [thoughtBlock]

        // 尾随正文保全（Suffix Preservation）：将闭标签后的正文续接渲染为标准 Block 序列
        if let suffix = parsed.suffixContent, !suffix.isEmpty {
          let suffixBlocks = InkBlockRenderer.render(suffix, configuration: configuration)
          resultBlocks.append(contentsOf: suffixBlocks)
        }

        return (resultBlocks, scanIndex - index + 1)
      }

      scanIndex += 1
    }

    // 未找到闭合标签（流式未完结中途态），消费当前剩余所有内容
    if let parsed = InkThoughtScanner.scan(from: collectedTexts) {
      let thoughtBlock = InkThoughtPresentationPolicy.makeBlock(
        from: parsed,
        configuration: configuration
      )
      return ([thoughtBlock], children.count - index)
    }

    return nil
  }

  // MARK: - Private Helpers

  private func textContent(of markup: Markup) -> String {
    if let html = markup as? Markdown.HTMLBlock {
      return html.rawHTML
    }
    if let code = markup as? Markdown.CodeBlock {
      return code.code
    }
    return markup.format()
  }
}
