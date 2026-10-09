import UIKit

/// 0.0.1 的复制反馈闭包允许捕获普通 UIKit/service 引用。
private struct InkCopyFeedbackStorage: @unchecked Sendable {
  var handler: ((UIView) -> Void)?
}

/// InkMarkdown 统一样式配置，按 Markdown 语法元素分类。
///
/// 支持两种用法：
/// - **全局单例**：App 启动时设置 `InkAppearance.shared`，后续渲染自动读取
/// - **per-instance**：某次渲染需要特殊样式时，传入自定义实例
///
/// ```swift
/// // 全局配置
/// InkAppearance.shared.text.fontSize = 16
/// InkAppearance.shared.table.cornerRadius = 12
///
/// // 渲染自动读 shared
/// let attr = InkAttributedRenderer.render(source)
///
/// // 某次特殊样式
/// var custom = InkAppearance.shared
/// custom.heading.h1FontSize = 32
/// let attr = InkAttributedRenderer.render(source, configuration: InkConfiguration(appearance: custom))
/// ```
public struct InkAppearance: Sendable {

  private final class SharedStorage: @unchecked Sendable {
    let lock = NSLock()
    var value: InkAppearance?
  }

  private static let sharedStorage = SharedStorage()

  /// 全局默认样式（可变单例）。App 启动时配置一次，后续渲染自动读取。
  ///
  /// 使用惰性锁存储保留 0.0.1 的非隔离调用方式，同时避免测试发现或模块加载线程
  /// 提前构造 UIKit 颜色值。宿主仍应在 App 启动主线程完成全局配置。
  public static var shared: InkAppearance {
    get {
      sharedStorage.lock.lock()
      defer { sharedStorage.lock.unlock() }
      if let value = sharedStorage.value {
        return value
      }
      let value = InkAppearance()
      sharedStorage.value = value
      return value
    }
    set {
      sharedStorage.lock.lock()
      sharedStorage.value = newValue
      sharedStorage.lock.unlock()
    }
  }

  // MARK: - 子配置

  /// 正文段落样式。
  public var text: Text = .init()
  /// 标题样式（H1~H5）。
  public var heading: Heading = .init()
  /// 引用块样式。
  public var blockquote: Blockquote = .init()
  /// 列表样式。
  public var list: List = .init()
  /// 围栏代码块样式（渲染为自定义 View）。
  public var codeBlock: CodeBlock = .init()
  /// 行内代码样式（渲染为富文本）。
  public var inlineCode: InlineCode = .init()
  /// 表格样式（渲染为自定义 View）。
  public var table: Table = .init()
  /// 分割线样式。
  public var thematicBreak: ThematicBreak = .init()
  /// 链接样式。
  public var link: Link = .init()
  /// 图片渲染配置。
  public var imageRendering: InkImageRendering = .init()
  /// Mermaid 围栏生成图片的配置；默认关闭以保留代码块行为。
  public var mermaidRendering: InkMermaidRendering = .init()
  /// LaTeX 行内/块级公式配置；默认关闭以保持原始文本降级。
  public var latexRendering: InkLaTeXRendering = .init()
  /// 思考过程块样式（<think>...</think> 或 <thought>...</thought>）。
  public var thought: Thought = .init()

  /// 是否支持系统动态字号（Dynamic Type）。默认为 `true`。
  /// 开启时，所有基于基础磅值的字号/行高均会根据当前系统的 `UIContentSizeCategory` 自动缩放。
  public var supportsDynamicType: Bool = true

  /// 创建全部语法元素的默认样式。
  public init() {}
}

// MARK: - Text（正文段落）

public extension InkAppearance {

  struct Text: Sendable {
    /// 正文字号。
    public var fontSize: CGFloat = 17
    /// 正文行高（min=max 双向锁死）。
    public var lineHeight: CGFloat = 28
    /// 正文颜色。
    public var color: UIColor = .label
    /// 次要文字颜色（图片占位等非主要内容）。
    public var secondaryColor: UIColor = .secondaryLabel
    /// 段落间距（段落之间）。
    public var paragraphSpacing: CGFloat = 12
    /// 块级富文本容器的内边距。默认 `.zero`：**库不占用任何屏幕边距**——
    /// 垂直间距由各元素自身下间距（经 render(markups:) 尾部哨兵撑出）承担，
    /// 水平边距由接入方（宿主容器）统一决定，从而文本块与表格/代码块等 view 块左右对齐。
    /// 接入方可覆盖此值为自己想要的内容内边距。
    public var blockInsets: UIEdgeInsets = .zero

    /// 创建默认正文样式。
    public init() {}
  }
}

// MARK: - Heading（标题）

public extension InkAppearance {

  struct Heading: Sendable {
    /// H1 字号。
    public var h1FontSize: CGFloat = 19
    /// H2~H5 统一字号。
    public var fontSize: CGFloat = 17
    /// H1 行高。
    public var h1LineHeight: CGFloat = 30
    /// H2~H5 行高。
    public var lineHeight: CGFloat = 28
    /// H1 距下方内容间距。
    public var h1SpacingAfter: CGFloat = 16
    /// H2~H5 距下方内容间距。
    public var spacingAfter: CGFloat = 8
    /// 标题颜色。
    public var color: UIColor = .label

    /// 创建默认标题样式。
    public init() {}

    /// 取指定标题级别的字号。
    /// // 为什么 H1 特殊、H2–H5 与正文同值：
    /// // 默认设计上，仅 H1 作为主要大标题被着重放大；H2–H5 在字号上与正文保持一致（17pt），
    /// // 通过字重（加粗）和上下文留白来区分层级，实现克制而精巧的排版。
    public func fontSize(forLevel level: Int) -> CGFloat {
      level == 1 ? h1FontSize : fontSize
    }

    /// 取指定标题级别的行高。
    public func lineHeight(forLevel level: Int) -> CGFloat {
      level == 1 ? h1LineHeight : lineHeight
    }

    /// 取指定标题级别的下方间距。
    public func spacingAfter(forLevel level: Int) -> CGFloat {
      level == 1 ? h1SpacingAfter : spacingAfter
    }
  }
}

// MARK: - Blockquote（引用块）

public extension InkAppearance {

  struct Blockquote: Sendable {
    /// 引用块文字字号。
    public var fontSize: CGFloat = 15
    /// 引用块行高。
    public var lineHeight: CGFloat = 24
    /// 引用块文字颜色。
    public var color: UIColor = .secondaryLabel
    /// 内容距左侧竖线的间距。
    public var leftPadding: CGFloat = 12
    /// 引用块距下方元素间距。
    public var spacingAfter: CGFloat = 12
    /// 引用块内多段落之间的间距。
    public var innerSpacing: CGFloat = 12
    /// 左侧竖线宽度。
    public var barWidth: CGFloat = 3
    /// 左侧竖线颜色。
    public var barColor: UIColor = UIColor(red: 0x66/255.0, green: 0x66/255.0, blue: 0x66/255.0, alpha: 0.1)

    /// 创建默认引用块样式。
    public init() {}
  }
}

// MARK: - List（列表）

public extension InkAppearance {

  struct List: Sendable {
    /// 列表条目之间间距。
    public var itemSpacing: CGFloat = 12
    /// 列表结束后距下方内容间距。
    public var spacingAfter: CGFloat = 24

    /// 创建默认列表样式。
    public init() {}
  }
}

// MARK: - CodeBlock（围栏代码块）

public extension InkAppearance {

  struct CodeBlock: Sendable {
    /// 代码字号。
    public var fontSize: CGFloat = 14
    /// 代码行高。
    public var lineHeight: CGFloat = 24
    /// 容器圆角。
    public var cornerRadius: CGFloat = 4
    /// 代码左右内边距。
    public var horizontalPadding: CGFloat = 8
    /// 代码上下内边距。
    public var verticalPadding: CGFloat = 8
    /// 代码块与前后文本的间距。
    public var spacingToText: CGFloat = 4
    /// 代码文字颜色。
    public var textColor: UIColor = .label
    /// 代码块背景色。
    public var backgroundColor: UIColor = .secondarySystemFill

    /// 已知代码语言时的 VoiceOver 标签格式；`%@` 会替换为语言名称。
    public var accessibilityLabelFormat: String = "%@ code block"
    /// 未指定代码语言时使用的 VoiceOver 标签。
    public var defaultAccessibilityLabel: String = "Code block"

    /// 创建默认围栏代码块样式。
    public init() {}
  }
}

// MARK: - InlineCode（行内代码）

public extension InkAppearance {

  struct InlineCode: Sendable {
    /// 行内代码字号。
    public var fontSize: CGFloat = 14
    /// 背景圆角。
    public var cornerRadius: CGFloat = 4
    /// 内边距（文字到背景边缘）。
    public var insets: CGFloat = 6
    /// 外边距（背景边缘到相邻文字）。
    public var margin: CGFloat = 8
    /// 背景高度（小于行高避免上下行连接）。
    public var backgroundHeight: CGFloat = 24
    /// 文字颜色。`nil` 表示跟随所在上下文的前景色（正文色 / 标题色 / 引用色…），
    /// 使行内代码在"字号 + 颜色"上跟随环境，仅在"等宽 + 背景"上保持代码身份。
    /// 显式设色则始终用该色。
    public var textColor: UIColor? = nil
    /// 背景色。
    public var backgroundColor: UIColor = .secondarySystemFill

    /// 创建默认行内代码样式。
    public init() {}
  }
}

// MARK: - Table（表格）

public extension InkAppearance {

  struct Table: Sendable {
    /// 表头字号。
    public var headerFontSize: CGFloat = 14
    /// 数据行字号。
    public var bodyFontSize: CGFloat = 14
    /// 表头文字颜色。
    public var headerColor: UIColor = UIColor.label.withAlphaComponent(0.9)
    /// 数据行文字颜色。
    public var bodyColor: UIColor = .label
    /// 分割线颜色。
    public var separatorColor: UIColor = .separator
    /// 表头背景色。
    public var headerBackgroundColor: UIColor = .secondarySystemBackground
    /// 单元格内文字左右间距。
    public var horizontalPadding: CGFloat = 10
    /// 单元格内文字上下间距。
    public var verticalPadding: CGFloat = 12
    /// 文字行高。
    public var lineHeight: CGFloat = 20
    /// 表格外层左右边距。
    public var horizontalInset: CGFloat = 0
    /// 表格下方间距（规范总纲：上方 0，此值仅作用于下方）。
    public var verticalInset: CGFloat = 24
    /// 表格圆角。
    public var cornerRadius: CGFloat = 8
    /// 边框宽度。
    public var borderWidth: CGFloat = 0.5
    /// 分割线粗细。
    public var separatorThickness: CGFloat = 0.5
    /// 单列最大宽度占屏幕宽度比例。
    public var columnMaxWidthRatio: CGFloat = 0.5
    /// 是否支持长按复制。
    public var enableLongPressCopy: Bool = false
    private var copyFeedbackStorage = InkCopyFeedbackStorage()
    private var copyFeedbackSemanticIdentity: InkSemanticIdentity?

    /// 复制成功后的 UI 反馈回调。传入触发复制的 view，由调用方决定如何展示 toast。
    /// 为 nil 时使用内置默认 toast。直接赋值会保守地生成新语义身份；
    /// SwiftUI 反复构造等价回调时使用 ``setCopyFeedback(_:semanticIdentity:)``。
    public var onCopyFeedback: ((UIView) -> Void)? {
      get { copyFeedbackStorage.handler }
      set {
        copyFeedbackStorage.handler = newValue
        copyFeedbackSemanticIdentity = newValue == nil ? nil : .unique()
      }
    }

    /// 创建默认表格样式。
    public init() {}

    /// 设置复制反馈回调，并显式声明其交互语义身份。
    public mutating func setCopyFeedback(
      _ feedback: ((UIView) -> Void)?,
      semanticIdentity: InkSemanticIdentity
    ) {
      copyFeedbackStorage.handler = feedback
      copyFeedbackSemanticIdentity = feedback == nil ? nil : semanticIdentity
    }
  }
}

// MARK: - ThematicBreak（分割线）

public extension InkAppearance {

  struct ThematicBreak: Sendable {
    /// 分割线粗细。
    public var lineThickness: CGFloat = 1
    /// 分割线颜色。
    public var color: UIColor = UIColor(red: 0x21/255.0, green: 0x21/255.0, blue: 0x21/255.0, alpha: 0.1)
    /// 分割线下方间距。
    public var spacingAfter: CGFloat = 24

    /// 创建默认分割线样式。
    public init() {}
  }
}

// MARK: - Link（链接）

public extension InkAppearance {

  struct Link: Sendable {
    /// 链接颜色。
    public var color: UIColor = .link

    /// 创建默认链接样式。
    public init() {}
  }
}

// MARK: - Thought（思考过程块）

public extension InkAppearance {

  /// Thought 卡片的文字、容器、折叠能力与间距配置。
  struct Thought: Sendable {
    /// 思考中状态标题。
    public var title: String = "思考过程"
    /// 思考完成状态标题。
    public var completedTitle: String = "已深度思考"
    /// 思考正文字号。
    public var fontSize: CGFloat = 14
    /// 思考正文行高。
    public var lineHeight: CGFloat = 22
    /// 思考正文颜色。
    public var textColor: UIColor = .secondaryLabel
    /// 头部标题字号。
    public var headerFontSize: CGFloat = 13
    /// 头部标题颜色。
    public var headerColor: UIColor = .secondaryLabel
    /// 卡片背景色。
    public var backgroundColor: UIColor = .secondarySystemFill
    /// 卡片圆角。
    public var cornerRadius: CGFloat = 8
    /// 内边距（整个卡片内部与四周的间距）。
    public var insets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
    /// 头部高度。
    public var headerHeight: CGFloat = 28
    /// 是否支持点击折叠/展开。
    public var isCollapsible: Bool = true
    /// 初始状态是否折叠。
    public var isInitiallyCollapsed: Bool = false
    /// 卡片下方间距。
    public var spacingAfter: CGFloat = 12

    /// 创建默认可折叠、初始展开的 Thought 样式。
    public init() {}
  }
}

// MARK: - Equatable

extension InkAppearance.Text: Equatable {}
extension InkAppearance.Heading: Equatable {}
extension InkAppearance.Blockquote: Equatable {}
extension InkAppearance.List: Equatable {}
extension InkAppearance.CodeBlock: Equatable {}
extension InkAppearance.InlineCode: Equatable {}
extension InkAppearance.Thought: Equatable {}

extension InkAppearance.Table: Equatable {
  /// 比较表格视觉、交互回调存在性与稳定语义身份。
  public static func == (lhs: InkAppearance.Table, rhs: InkAppearance.Table) -> Bool {
    lhs.headerFontSize == rhs.headerFontSize &&
    lhs.bodyFontSize == rhs.bodyFontSize &&
    lhs.headerColor == rhs.headerColor &&
    lhs.bodyColor == rhs.bodyColor &&
    lhs.separatorColor == rhs.separatorColor &&
    lhs.headerBackgroundColor == rhs.headerBackgroundColor &&
    lhs.horizontalPadding == rhs.horizontalPadding &&
    lhs.verticalPadding == rhs.verticalPadding &&
    lhs.lineHeight == rhs.lineHeight &&
    lhs.horizontalInset == rhs.horizontalInset &&
    lhs.verticalInset == rhs.verticalInset &&
    lhs.cornerRadius == rhs.cornerRadius &&
    lhs.borderWidth == rhs.borderWidth &&
    lhs.separatorThickness == rhs.separatorThickness &&
    lhs.columnMaxWidthRatio == rhs.columnMaxWidthRatio &&
    lhs.enableLongPressCopy == rhs.enableLongPressCopy &&
    InkSemanticComparator.opaqueValuesAreEquivalent(
      lhsIsPresent: lhs.onCopyFeedback != nil,
      rhsIsPresent: rhs.onCopyFeedback != nil,
      lhsIdentity: lhs.copyFeedbackSemanticIdentity,
      rhsIdentity: rhs.copyFeedbackSemanticIdentity
    )
  }
}

extension InkAppearance.ThematicBreak: Equatable {}
extension InkAppearance.Link: Equatable {}
extension InkAppearance: Equatable {}

// MARK: - Dynamic Type Helpers

public extension InkAppearance {
  /// 根据给定的文本样式和原始字体，返回经过 Dynamic Type 缩放的字体（若开启了支持）。
  func scaledFont(
    _ font: UIFont,
    textStyle: UIFont.TextStyle = .body,
    compatibleWith traitCollection: UITraitCollection? = nil
  ) -> UIFont {
    guard supportsDynamicType else { return font }
    return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font, compatibleWith: traitCollection)
  }

  /// 根据给定的文本样式和原始标量，返回经过 Dynamic Type 缩放的标量值（若开启了支持）。
  func scaledValue(
    _ value: CGFloat,
    textStyle: UIFont.TextStyle = .body,
    compatibleWith traitCollection: UITraitCollection? = nil
  ) -> CGFloat {
    guard supportsDynamicType else { return value }
    return UIFontMetrics(forTextStyle: textStyle).scaledValue(for: value, compatibleWith: traitCollection)
  }
}
