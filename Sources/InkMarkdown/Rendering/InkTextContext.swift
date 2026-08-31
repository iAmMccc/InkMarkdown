import UIKit

/// 行内渲染的样式上下文，随行内递归**向下传递**（context 下传，取代旧的 render-then-rewrite）。
///
/// 设计要义：每个行内节点基于父级 context **派生**出新 context 交给子节点；叶子节点
/// （Text / InlineCode / Image）在生成 run 时**一次性**挂上正确的 font / color / link，
/// 不再存在"先渲染子节点、父节点回头 enumerate 覆盖"的过程——样式互踩的 bug 从根上消除
/// （如标题里的行内代码不再被标题字体抹掉、链接色与引用色不再互相覆盖）。
///
/// 纯值语义：所有派生方法返回新实例，不修改自身。
struct InkTextContext {
  /// 是否有删除线
  var isStrikethrough: Bool = false

  /// 当前列表内容起点的累计缩进。根列表为 0；嵌套列表在父级内容起点上
  /// 叠加父级 marker 宽度，使列表排版不依赖固定层级常量。
  var listIndent: CGFloat = 0

  /// 当前基准字体：字号 / 字重 / traits / family 全部编码在内。
  var font: UIFont
  /// 当前前景色。
  var foregroundColor: UIColor
  /// 已在 trait 快照下解析的前景色 RGBA。
  var resolvedForegroundColor: InkLaTeXColor
  /// 若非 nil，表示当前处于某个链接内，叶子应挂 `.link`。随 context 下传，
  /// 使 `[**加粗**](url)`、`[`代码`](url)` 里的子节点都能带上链接目标。
  var linkURL: URL?
  /// 斜体兜底：当字体本身无 italic 变体（`withSymbolicTraits` 求不到）时，
  /// 记录一个 `.obliqueness` 值，由叶子 emit 时挂上，人工倾斜模拟斜体。
  /// 系统字体有 italic 变体、走不到这里；仅无 italic 变体的自定义字体需要。
  var obliqueness: CGFloat
  /// 完整样式配置，供叶子读取其它样式项（如 inlineCode / link 色）。
  let appearance: InkAppearance
  /// 解析动态色时使用的 trait 快照。
  let renderEnvironment: InkRenderEnvironment

  init(
    font: UIFont,
    foregroundColor: UIColor,
    linkURL: URL? = nil,
    obliqueness: CGFloat = 0,
    appearance: InkAppearance,
    renderEnvironment: InkRenderEnvironment
  ) {
    self.font = font
    self.foregroundColor = foregroundColor
    self.resolvedForegroundColor = InkLaTeXColor(resolving: foregroundColor, environment: renderEnvironment)
    self.linkURL = linkURL
    self.obliqueness = obliqueness
    self.appearance = appearance
    self.renderEnvironment = renderEnvironment
  }

  // MARK: - 派生

  /// **叠加** trait（emphasis→italic，strong→bold），保留字号 / family / 其它 trait。
  /// 与 `monospaced()` 语义相反：那是重置，这是叠加。
  /// 若字体无该变体（`withSymbolicTraits` 返回 nil）则保持原字体——系统字体不会走到这。
  func addingTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> InkTextContext {
    var traits = font.fontDescriptor.symbolicTraits
    traits.insert(trait)
    var copy = self
    if let desc = font.fontDescriptor.withSymbolicTraits(traits) {
      copy.font = UIFont(descriptor: desc, size: font.pointSize)
    } else if trait == .traitItalic {
      // 字体无 italic 变体：退回人工倾斜（与旧 applyTrait 的 obliqueness 兜底一致）。
      copy.obliqueness = 0.25
    }
    return copy
  }

  /// **重置**到"代码身份"：换等宽 family + regular 字重，丢弃继承来的 bold/italic，
  /// 仅保留当前环境**字号**（标题里的行内代码 = 标题字号的等宽字，正文里 = 正文字号）。
  ///
  /// 注意与 `addingTrait` 语义相反——因此调用顺序无关：`**加粗里的 `code`**` 中，
  /// strong 先派生出 bold，inlineCode 再 `monospaced()` 会把 bold 丢弃，代码不加粗。
  ///
  /// 颜色不在此处理——由 inlineCode 渲染按 `appearance.inlineCode` 决定，
  /// 因为"是否回落到环境色"是样式策略，不该埋进字体派生。
  func monospaced() -> InkTextContext {
    var copy = self
    copy.font = UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
    // 代码身份：即便处于 emphasis 内也不倾斜，清掉斜体兜底。
    copy.obliqueness = 0
    return copy
  }

  /// 派生新前景色（link 上色等）。
  func coloring(_ color: UIColor) -> InkTextContext {
    var copy = self
    copy.foregroundColor = color
    copy.resolvedForegroundColor = InkLaTeXColor(resolving: color, environment: renderEnvironment)
    return copy
  }

  /// 置入链接目标，下传给所有子节点的叶子。
  func linking(_ url: URL) -> InkTextContext {
    var copy = self
    copy.linkURL = url
    return copy
  }

  /// 替换基准字体（block 节点派生子上下文时用，如 heading → bold + 标题字号）。
  func withFont(_ newFont: UIFont) -> InkTextContext {
    var copy = self
    copy.font = newFont
    return copy
  }

  /// 派生嵌套列表的内容起点，保留其它行内渲染状态。
  func withListIndent(_ indent: CGFloat) -> InkTextContext {
    var copy = self
    copy.listIndent = indent
    return copy
  }

  func striking() -> InkTextContext {
    var copy = self
    copy.isStrikethrough = true
    return copy
  }
}
