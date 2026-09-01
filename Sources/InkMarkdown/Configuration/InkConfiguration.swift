import UIKit

/// 为含运行时状态的语法或 block handler 提供配置语义比较。
///
/// 未实现本协议的第三方扩展会被保守视为不等价，避免只按动态类型比较而漏掉状态变化。
public protocol InkConfigurationSemanticsProviding: Sendable, InkSemanticIdentityProviding {
  func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool
}

/// `InkBlockHandler` 在 0.0.1 没有 `Sendable` 约束；第三方实现可能合法持有
/// UIKit service 或其他非 Sendable 引用。只在这一条兼容边界隔离并发检查，
/// handler 的实际路由与 view 构造仍由主线程渲染入口串行调用。
private struct InkBlockHandlerStorage: @unchecked Sendable {
  var handlers: [InkBlockHandler]
}

/// `InkInlineSyntax` 同样是 0.0.1 的开放扩展点，旧实现不必是 `Sendable`。
private struct InkInlineSyntaxStorage: @unchecked Sendable {
  var syntaxes: [InkInlineSyntax]
}

/// 0.0.1 公开闭包允许捕获普通引用。值类型配置仍可跨任务传递，但这些闭包只在
/// 各自既有的渲染执行边界调用；不要把兼容存储误当成可并发调用保证。
private struct InkConfigurationClosureStorage: @unchecked Sendable {
  var sourceFilter: ((String) -> String)?
  var linkTapHandler: ((URL, UIView) -> Bool)?
}

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
public struct InkConfiguration: Sendable {

  /// 样式配置。默认读全局 `InkAppearance.shared`。
  public var appearance: InkAppearance

  /// 已注册的行内语法扩展，按顺序询问；默认空（纯标准 Markdown）。
  public var inlineSyntaxes: [InkInlineSyntax] {
    get { inlineSyntaxStorage.syntaxes }
    set { inlineSyntaxStorage.syntaxes = newValue }
  }

  private var inlineSyntaxStorage: InkInlineSyntaxStorage

  private var sourceFilterSemanticIdentity: InkSemanticIdentity?

  /// 源文本预处理：在交给 Markdown 解析器之前对原始文本做变换。
  ///
  /// 每次顶层 renderer 调用只执行一次。Block handler 接收的 Markup、Thought 正文与
  /// 尾随 suffix 均已跨过解析边界，不会对派生片段再次调用该闭包；因此允许使用非幂等转换。
  ///
  /// 直接赋值会保守地生成新语义身份。若 SwiftUI `body` 每次都重建行为等价的闭包，
  /// 请使用 ``setSourceFilter(_:semanticIdentity:)`` 声明稳定身份。
  public var sourceFilter: ((String) -> String)? {
    get { closureStorage.sourceFilter }
    set {
      closureStorage.sourceFilter = newValue
      sourceFilterSemanticIdentity = newValue == nil ? nil : .unique()
    }
  }

  /// 块级路由处理器列表，按顺序匹配。默认内置思考过程块、代码块、表格和分隔线。
  ///
  /// > 注意：本渲染器（`InkAttributedRenderer`）不会读取此配置；
  /// > 这些 handler 专供 `InkBlockRenderer`（块路由通道）消费，用于决定哪些节点被截获渲染为自定义 UIView。
  public var blockHandlers: [InkBlockHandler] {
    get { blockHandlerStorage.handlers }
    set { blockHandlerStorage.handlers = newValue }
  }

  private var blockHandlerStorage: InkBlockHandlerStorage

  /// 主线程捕获的 trait 快照，供流式后台解析解析动态色；未设置时仅在主线程同步渲染路径自动补全。
  public var renderEnvironment: InkRenderEnvironment = .init()

  private var closureStorage: InkConfigurationClosureStorage
  private var linkTapHandlerSemanticIdentity: InkSemanticIdentity?

  /// 链接点击回调。
  ///
  /// 表格单元格用 `UITextView` 渲染时，命中 `.link` 属性会调用此回调，
  /// 由业务方决定如何处理（例如分发到自定义 Directive 跳转）。
  ///
  /// > 注意：本渲染器只负责给文本挂上 `.link` 属性，并不负责事件拦截；
  /// > 实际点击回调由显示层（如自定义的 TextView 或 `InkAttributedTextBlock`）读取该闭包并触发。
  /// - Parameters:
  ///   - url: 被点击链接的 URL。
  ///   - view: 触发点击的视图（业务方可沿其响应链定位当前 VC）。
  /// - Returns: `true` 表示业务已处理（拦截默认行为）；`false` 交还系统默认处理。
  public var linkTapHandler: ((URL, UIView) -> Bool)? {
    get { closureStorage.linkTapHandler }
    set {
      closureStorage.linkTapHandler = newValue
      linkTapHandlerSemanticIdentity = newValue == nil ? nil : .unique()
    }
  }

  public init(
    appearance: InkAppearance = .shared,
    inlineSyntaxes: [InkInlineSyntax] = [],
    sourceFilter: ((String) -> String)? = nil,
    blockHandlers: [InkBlockHandler] = InkConfiguration.defaultBlockHandlers,
    linkTapHandler: ((URL, UIView) -> Bool)? = nil
  ) {
    self.appearance = appearance
    self.inlineSyntaxStorage = InkInlineSyntaxStorage(syntaxes: inlineSyntaxes)
    self.closureStorage = InkConfigurationClosureStorage(
      sourceFilter: sourceFilter,
      linkTapHandler: linkTapHandler
    )
    self.sourceFilterSemanticIdentity = sourceFilter == nil ? nil : .unique()
    self.blockHandlerStorage = InkBlockHandlerStorage(handlers: blockHandlers)
    self.linkTapHandlerSemanticIdentity = linkTapHandler == nil ? nil : .unique()
  }

  /// 设置源文本过滤器，并显式声明其渲染语义身份。
  ///
  /// 只有过滤逻辑与所有捕获状态均等价时，才能复用同一 `semanticIdentity`。
  public mutating func setSourceFilter(
    _ sourceFilter: ((String) -> String)?,
    semanticIdentity: InkSemanticIdentity
  ) {
    closureStorage.sourceFilter = sourceFilter
    sourceFilterSemanticIdentity = sourceFilter == nil ? nil : semanticIdentity
  }

  /// 设置链接点击回调，并显式声明其交互语义身份。
  ///
  /// 适用于 SwiftUI 反复构造同一业务回调的场景。捕获状态改变时必须更换身份。
  public mutating func setLinkTapHandler(
    _ linkTapHandler: ((URL, UIView) -> Bool)?,
    semanticIdentity: InkSemanticIdentity
  ) {
    closureStorage.linkTapHandler = linkTapHandler
    linkTapHandlerSemanticIdentity = linkTapHandler == nil ? nil : semanticIdentity
  }

  /// 启用内置 LaTeX 渲染总开关。
  ///
  /// 调用前，宿主必须链接并导入 `InkMarkdownLaTeX` product，然后在首次
  /// 渲染前调用 `InkMarkdownLaTeX.register()`。未注册时生成图请求会失败并报告
  /// `generatedLoaderUnavailable(owner: "latex")`，而不会隐式引入 addon 实现。
  ///
  /// 开启后默认识别 `\\(...\\)`、`$$...$$` 与 `\\[...\\]`；`$...$` 行内分隔符
  /// 需额外设置 ``InkLaTeXRendering/allowsInlineDollarDelimiter``。
  /// 行内语法由渲染器在每次 render 时根据当前 `appearance.latexRendering` 注入，
  /// 因此调用此方法后仍可安全修改样式或 opt-in 选项，无需重复注册语法。
  /// 块级公式须由宿主在终态调用 ``InkBlockRenderer`` 渲染。
  public mutating func enableLaTeXRendering() {
    appearance.latexRendering.isEnabled = true
  }

  /// 核心库内置的默认块级路由（思考过程块 + 代码块 + 表格 + 分割线）。
  public static var defaultBlockHandlers: [InkBlockHandler] {
    [
      InkThoughtBlockHandler(),
      InkCodeBlockHandler(),
      InkTableBlockHandler(),
      InkThematicBreakHandler(),
    ]
  }

  /// 标准配置：全局样式 + 无行内扩展 + 默认块级路由。
  public static var standard: InkConfiguration { InkConfiguration() }

  /// 判断两个配置是否在渲染语义上等价（包含样式、环境、语法扩展与处理器）。
  ///
  /// 比较策略：样式与环境按值比较；行内语法与块处理器先核对动态类型与顺序，
  /// 再通过 ``InkConfigurationSemanticsProviding`` 比较完整内部状态。未声明语义比较
  /// 能力的扩展保守视为不等价，避免 Coordinator 错误跳过更新。
  /// 闭包（``sourceFilter`` / ``linkTapHandler``）按 ``InkSemanticIdentity`` 比较：值拷贝保留身份，
  /// 直接重新赋值保守地视为新语义，宿主也可通过显式 setter 声明稳定等价性。
  public func isSemanticallyEqualTo(_ other: InkConfiguration) -> Bool {
    appearance == other.appearance &&
    renderEnvironment == other.renderEnvironment &&
    inlineSyntaxes.count == other.inlineSyntaxes.count &&
    zip(inlineSyntaxes, other.inlineSyntaxes).allSatisfy {
      Self.extensionsAreSemanticallyEqual($0, $1)
    } &&
    blockHandlers.count == other.blockHandlers.count &&
    zip(blockHandlers, other.blockHandlers).allSatisfy {
      Self.extensionsAreSemanticallyEqual($0, $1)
    } &&
    InkSemanticComparator.opaqueValuesAreEquivalent(
      lhsIsPresent: sourceFilter != nil,
      rhsIsPresent: other.sourceFilter != nil,
      lhsIdentity: sourceFilterSemanticIdentity,
      rhsIdentity: other.sourceFilterSemanticIdentity
    ) &&
    InkSemanticComparator.opaqueValuesAreEquivalent(
      lhsIsPresent: linkTapHandler != nil,
      rhsIsPresent: other.linkTapHandler != nil,
      lhsIdentity: linkTapHandlerSemanticIdentity,
      rhsIdentity: other.linkTapHandlerSemanticIdentity
    )
  }

  var linkTapSemanticIdentityForBlockReuse: InkSemanticIdentity? {
    linkTapHandlerSemanticIdentity
  }

  private static func extensionsAreSemanticallyEqual(
    _ lhs: Any,
    _ rhs: Any
  ) -> Bool {
    guard let lhs = lhs as? any InkConfigurationSemanticsProviding,
          let rhs = rhs as? any InkConfigurationSemanticsProviding else {
      return false
    }
    return InkSemanticComparator.extensionsAreEquivalent(lhs, rhs)
  }
}
