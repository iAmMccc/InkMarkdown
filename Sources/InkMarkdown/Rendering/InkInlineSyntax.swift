import UIKit
import Markdown

/// 行内渲染上下文。
///
/// 描述**当前文本片段所处容器**的排版基准，随渲染位置向下传递：
/// 正文段落里 `baseFont` 是正文字号，表格单元格里 `baseFont` 是表格数据行字号，
/// 表头里则是表头字号（含字重）。行内语法扩展应基于此上下文渲染，
/// 从而与所在容器的整体风格保持一致，而非各自硬读全局样式。
public struct InkInlineContext {

  /// 当前上下文的基准字体（含字号与字重）。
  public let baseFont: UIFont

  /// 当前上下文的基准文字颜色。
  public let textColor: UIColor

  /// 已在 trait 快照下解析的前景色 RGBA，后台 LaTeX 等路径只消费此值。
  public let resolvedTextColor: InkLaTeXColor

  /// 完整样式配置，供扩展读取其它样式项（如 `link.color`）。
  public let appearance: InkAppearance

  public init(
    baseFont: UIFont,
    textColor: UIColor,
    resolvedTextColor: InkLaTeXColor,
    appearance: InkAppearance
  ) {
    self.baseFont = baseFont
    self.textColor = textColor
    self.resolvedTextColor = resolvedTextColor
    self.appearance = appearance
  }
}

/// 行内语法扩展点。
///
/// 核心库只渲染标准 Markdown 行内元素（强调、链接、行内代码等）。任何**业务自定义的
/// 行内语法**（例如 `$标签$`、`@提及`、`:emoji:`）都应由业务方实现本协议，注册进
/// `InkConfiguration.inlineSyntaxes`，从而在不修改核心库的前提下插入文本流。
///
/// 渲染器在处理纯文本节点（`Text`）时，会依次询问每个已注册的 `InkInlineSyntax`：
/// 由实现方扫描文本、产出 `NSAttributedString` 片段；返回 `nil` 表示「这段不归我管」，
/// 交还给下一个扩展或默认渲染。
///
/// 扩展应基于传入的 `InkInlineContext.baseFont` / `textColor` 渲染，使产出片段与所在容器
/// （正文 / 表格单元格 / 表头等）风格一致；若自身信息不足以完成渲染，应内部降级为普通文本。
///
/// > 与块级扩展点 `InkBlockHandler` 互补：一个管行内文字流，一个管整块替换为 UIView。
public protocol InkInlineSyntax {

  /// 扫描一段纯文本，将命中的自定义语法渲染为属性字符串。
  ///
  /// - Parameters:
  ///   - text: 当前 `Text` 节点的字面内容。
  ///   - context: 当前文本所处容器的渲染上下文（基准字体 / 颜色 / 完整样式）。
  /// - Returns: 渲染好的片段；
  ///   // 为什么 用返回 nil 来交出控制权：
  ///   // 因为行内扩展是一个责任链模型，返回 nil 明确表达了"虽然扫描了，但未命中我的规则"，
  ///   // 渲染器据此知道应该继续询问链上的下一个扩展，或者回落到默认的普通文本渲染。
  ///   返回 `nil` 表示本扩展不处理该段文本。
  func render(text: String, context: InkInlineContext) -> NSAttributedString?
}
