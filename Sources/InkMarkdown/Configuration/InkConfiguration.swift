import UIKit

/// InkMarkdown 渲染配置容器。
///
/// 聚合一次渲染所需的全部可插拔要素：
/// - ``appearance``：样式配置（字号 / 间距 / 颜色），默认读全局 `InkAppearance.shared`。
/// - ``inlineSyntaxes``：行内语法扩展（`$标签$`、`@提及` 等），由业务方注册。
/// - ``blockHandlers``：块级路由处理器，决定哪些 Markup 节点渲染为自定义 UIView。
/// - ``sourceFilter``：源文本预处理，在解析前对原始文本做变换。
///
/// ```swift
/// // 最简用法：全部走默认
/// let attr = InkAttributedRenderer.render(source)
///
/// // 自定义行内语法 + 源文本过滤
/// let config = InkConfiguration(
///     inlineSyntaxes: [MyInlineSyntax()],
///     sourceFilter: { $0.replacingOccurrences(of: "<ref />", with: "") }
/// )
/// let attr = InkAttributedRenderer.render(source, configuration: config)
/// ```
public struct InkConfiguration {

  /// 样式配置。默认读全局 `InkAppearance.shared`。
  public var appearance: InkAppearance

  /// 已注册的行内语法扩展，按顺序询问；默认空（纯标准 Markdown）。
  public var inlineSyntaxes: [InkInlineSyntax]

  /// 源文本预处理：在交给 Markdown 解析器之前对原始文本做变换。
  public var sourceFilter: ((String) -> String)?

  /// 块级路由处理器列表，按顺序匹配。默认内置代码块和表格。
  public var blockHandlers: [InkBlockHandler]

  /// 链接点击回调。
  ///
  /// 表格单元格用 `UITextView` 渲染时，命中 `.link` 属性会调用此回调，
  /// 由业务方决定如何处理（例如分发到自定义 Directive 跳转）。
  /// - Parameters:
  ///   - url: 被点击链接的 URL。
  ///   - view: 触发点击的视图（业务方可沿其响应链定位当前 VC）。
  /// - Returns: `true` 表示业务已处理（拦截默认行为）；`false` 交还系统默认处理。
  public var linkTapHandler: ((URL, UIView) -> Bool)?

  public init(
    appearance: InkAppearance = .shared,
    inlineSyntaxes: [InkInlineSyntax] = [],
    sourceFilter: ((String) -> String)? = nil,
    blockHandlers: [InkBlockHandler] = InkConfiguration.defaultBlockHandlers,
    linkTapHandler: ((URL, UIView) -> Bool)? = nil
  ) {
    self.appearance = appearance
    self.inlineSyntaxes = inlineSyntaxes
    self.sourceFilter = sourceFilter
    self.blockHandlers = blockHandlers
    self.linkTapHandler = linkTapHandler
  }

  /// 核心库内置的默认块级路由（代码块 + 表格 + 分割线）。
  public static let defaultBlockHandlers: [InkBlockHandler] = [
    InkCodeBlockHandler(),
    InkTableBlockHandler(),
    InkThematicBreakHandler(),
  ]

  /// 标准配置：全局样式 + 无行内扩展 + 默认块级路由。
  public static var standard: InkConfiguration { InkConfiguration() }
}
