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
  /// // 注意：本渲染器 (InkAttributedRenderer) 不会读取此配置。
  /// // 这些 handler 专供 InkBlockRenderer (块路由通道) 消费，用于决定哪些节点被截获渲染为自定义 UIView。
  public var blockHandlers: [InkBlockHandler]

  /// 主线程捕获的 trait 快照，供流式后台解析解析动态色；未设置时仅在主线程同步渲染路径自动补全。
  public var renderEnvironment: InkRenderEnvironment = .init()

  /// 链接点击回调。
  ///
  /// 表格单元格用 `UITextView` 渲染时，命中 `.link` 属性会调用此回调，
  /// 由业务方决定如何处理（例如分发到自定义 Directive 跳转）。
  /// // 注意：本渲染器只负责给文本挂上 `.link` 属性，并不负责事件拦截。
  /// // 实际点击回调由显示层（如自定义的 TextView 或 InkAttributedTextBlock）读取该闭包并触发。
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

  /// 启用内置 LaTeX 渲染总开关。
  ///
  /// 开启后默认识别 `\\(...\\)`、`$$...$$` 与 `\\[...\\]`；`$...$` 行内分隔符
  /// 需额外设置 ``InkLaTeXRendering/allowsInlineDollarDelimiter``。
  /// 行内语法由渲染器在每次 render 时根据当前 `appearance.latexRendering` 注入，
  /// 因此调用此方法后仍可安全修改样式或 opt-in 选项，无需重复注册语法。
  /// 块级公式须由宿主在终态调用 ``InkBlockRenderer`` 渲染。
  public mutating func enableLaTeXRendering() {
    appearance.latexRendering.isEnabled = true
  }

  /// 核心库内置的默认块级路由（代码块 + 表格 + 分割线）。
  public static let defaultBlockHandlers: [InkBlockHandler] = [
    InkCodeBlockHandler(),
    InkTableBlockHandler(),
    InkThematicBreakHandler(),
  ]

  /// 标准配置：全局样式 + 无行内扩展 + 默认块级路由。
  public static var standard: InkConfiguration { InkConfiguration() }

  /// 判断两个配置是否在渲染语义上等价（包含样式、环境、语法扩展与处理器）。
  public func isSemanticallyEqualTo(_ other: InkConfiguration) -> Bool {
    appearance == other.appearance &&
    renderEnvironment == other.renderEnvironment &&
    inlineSyntaxes.count == other.inlineSyntaxes.count &&
    blockHandlers.count == other.blockHandlers.count &&
    (sourceFilter == nil) == (other.sourceFilter == nil) &&
    (linkTapHandler == nil) == (other.linkTapHandler == nil)
  }
}

