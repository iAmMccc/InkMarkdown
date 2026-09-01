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
///
/// struct MyFancyCodeCard: InkRenderableBlock {
///   let code: String
///   func makeView() -> UIView { /* ... */ }
/// }
/// ```
public protocol InkBlockHandler {
  /// 判断本 handler 是否能处理该 Markup 节点。
  func canHandle(_ markup: Markup) -> Bool

  /// 将 Markup 节点渲染为独立 Block。返回 nil 表示回落到富文本通道。
  ///
  /// 传入的 Markup 已跨过 String → AST 的解析边界；Block 内部若需递归渲染其派生内容，
  /// 不得再次执行 `sourceFilter`。调用方应在构造 Markup 前完成源码预处理。
  ///
  /// - Parameter configuration: 完整渲染配置。Block 内部仍应透传此配置以复用
  ///   `inlineSyntaxes` / `linkTapHandler` 等解析后语义。
  @preconcurrency @MainActor
  func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock?

  /// 从文档子节点序列中消费一个或多个 Markup 并产出 Block。
  ///
  /// 默认实现仅处理单节点：``canHandle(_:)`` 为真且 ``makeBlock(from:configuration:)`` 成功时
  /// 返回 `(block, 1)`；否则返回 `nil` 以回落富文本。多段块（如跨段 LaTeX）可覆写此方法。
  @preconcurrency @MainActor
  func consume(
    from children: [Markup],
    startingAt index: Int,
    configuration: InkConfiguration
  ) -> (block: InkRenderableBlock, consumedCount: Int)?

  /// 从文档子节点序列中消费一个或多个 Markup 并产出零个或多个 Block（支持拆解卡片与续接正文）。
  ///
  /// 默认实现转发至 ``consume(from:startingAt:configuration:)`` 并封装为单元素数组。
  @preconcurrency @MainActor
  func consumeBlocks(
    from children: [Markup],
    startingAt index: Int,
    configuration: InkConfiguration
  ) -> (blocks: [InkRenderableBlock], consumedCount: Int)?
}

public extension InkBlockHandler {
  @preconcurrency @MainActor
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

  @preconcurrency @MainActor
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
public struct InkCodeBlockHandler: InkBlockHandler, InkConfigurationSemanticsProviding {

  public init() {}

  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    other is InkCodeBlockHandler
  }

  public func canHandle(_ markup: Markup) -> Bool {
    markup is Markdown.CodeBlock
  }

  @preconcurrency @MainActor
  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let codeBlock = markup as? Markdown.CodeBlock else { return nil }
    return InkCodeBlock(code: codeBlock.code, language: codeBlock.language, config: configuration.appearance.codeBlock, renderConfiguration: configuration)
  }
}

/// 分割线 → InkThematicBreakBlock（细线 + 下方留白）。
public struct InkThematicBreakHandler: InkBlockHandler, InkConfigurationSemanticsProviding {

  public init() {}

  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    other is InkThematicBreakHandler
  }

  public func canHandle(_ markup: Markup) -> Bool {
    markup is Markdown.ThematicBreak
  }

  @preconcurrency @MainActor
  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard markup is Markdown.ThematicBreak else { return nil }
    return InkThematicBreakBlock(config: configuration.appearance.thematicBreak)
  }
}

/// 表格 → InkTableBlock（原生 UIView 表格）。
public struct InkTableBlockHandler: InkBlockHandler, InkConfigurationSemanticsProviding {
  /// 表格布局模式，默认横向可滑动。
  public var layoutMode: InkTableLayoutMode

  public init(layoutMode: InkTableLayoutMode = .scroll) {
    self.layoutMode = layoutMode
  }

  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    guard let other = other as? InkTableBlockHandler else { return false }
    return layoutMode == other.layoutMode
  }

  public func canHandle(_ markup: Markup) -> Bool {
    markup is Markdown.Table
  }

  @preconcurrency @MainActor
  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let table = markup as? Markdown.Table else { return nil }
    return InkTableBlock.from(table, layoutMode: layoutMode, configuration: configuration)
  }
}
