import UIKit
import Markdown

/// 块级路由处理器：判断一个 Markup 节点是否需要独立渲染为 UIView。
///
/// 核心库内置默认注册（CodeBlock → InkCodeBlock, Table → InkTableBlock），
/// 业务方可实现此协议来覆盖或追加自定义块。
///
/// ```swift
/// struct MyCodeBlockHandler: InkBlockHandler {
///   func canHandle(_ markup: Markup) -> Bool {
///     markup is CodeBlock
///   }
///
///   func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
///     guard let codeBlock = markup as? CodeBlock else { return nil }
///     return MyFancyCodeCard(code: codeBlock.code)
///   }
/// }
/// ```
public protocol InkBlockHandler {
  /// 判断本 handler 是否能处理该 Markup 节点。
  func canHandle(_ markup: Markup) -> Bool

  /// 将 Markup 节点渲染为独立 Block。返回 nil 表示回落到富文本通道。
  ///
  /// - Parameter configuration: 完整渲染配置。Block 内部若需二次渲染行内内容
  ///   （如表格单元格），应透传此配置以复用 `inlineSyntaxes` / `linkTapHandler`。
  func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock?

  /// 从文档子节点序列中消费一个或多个 Markup 并产出 Block。
  ///
  /// 默认实现仅处理单节点：``canHandle(_:)`` 为真且 ``makeBlock(from:configuration:)`` 成功时
  /// 返回 `(block, 1)`；否则返回 `nil` 以回落富文本。多段块（如跨段 LaTeX）可覆写此方法。
  func consume(
    from children: [Markup],
    startingAt index: Int,
    configuration: InkConfiguration
  ) -> (block: InkRenderableBlock, consumedCount: Int)?

  /// 从文档子节点序列中消费一个或多个 Markup 并产出零个或多个 Block（支持拆解卡片与续接正文）。
  ///
  /// 默认实现转发至 ``consume(from:startingAt:configuration:)`` 并封装为单元素数组。
  func consumeBlocks(
    from children: [Markup],
    startingAt index: Int,
    configuration: InkConfiguration
  ) -> (blocks: [InkRenderableBlock], consumedCount: Int)?
}

public extension InkBlockHandler {
  func consume(
    from children: [Markup],
    startingAt index: Int,
    configuration: InkConfiguration
  ) -> (block: InkRenderableBlock, consumedCount: Int)? {
    guard index < children.count else { return nil }
    let markup = children[index]
    guard canHandle(markup),
          let block = makeBlock(from: markup, configuration: configuration) else {
      return nil
    }
    return (block, 1)
  }

  func consumeBlocks(
    from children: [Markup],
    startingAt index: Int,
    configuration: InkConfiguration
  ) -> (blocks: [InkRenderableBlock], consumedCount: Int)? {
    if let single = consume(from: children, startingAt: index, configuration: configuration) {
      return ([single.block], single.consumedCount)
    }
    return nil
  }
}

// MARK: - 内置默认 Handler

/// 代码块 → InkCodeBlock（圆角灰背容器 + 等宽字体）。
public struct InkCodeBlockHandler: InkBlockHandler {

  public init() {}

  public func canHandle(_ markup: Markup) -> Bool {
    markup is Markdown.CodeBlock
  }

  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let codeBlock = markup as? Markdown.CodeBlock else { return nil }
    return InkCodeBlock(code: codeBlock.code, language: codeBlock.language, config: configuration.appearance.codeBlock)
  }
}

/// 分割线 → InkThematicBreakBlock（细线 + 下方留白）。
public struct InkThematicBreakHandler: InkBlockHandler {

  public init() {}

  public func canHandle(_ markup: Markup) -> Bool {
    markup is Markdown.ThematicBreak
  }

  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard markup is Markdown.ThematicBreak else { return nil }
    return InkThematicBreakBlock(config: configuration.appearance.thematicBreak)
  }
}

/// 表格 → InkTableBlock（原生 UIView 表格）。
public struct InkTableBlockHandler: InkBlockHandler {
  /// 表格布局模式，默认横向可滑动。
  public var layoutMode: InkTableLayoutMode

  public init(layoutMode: InkTableLayoutMode = .scroll) {
    self.layoutMode = layoutMode
  }

  public func canHandle(_ markup: Markup) -> Bool {
    markup is Markdown.Table
  }

  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let table = markup as? Markdown.Table else { return nil }
    return InkTableBlock.from(table, layoutMode: layoutMode, configuration: configuration)
  }
}
