import UIKit
import Markdown

/// Markdown → NSAttributedString 渲染器（UIKit 通道）。
///
/// 核心设计原则：
/// 1. **固定行高**：所有段落通过 `minimumLineHeight = maximumLineHeight` 双向锁死行高，
///    保证无论行内嵌入何种字体/字号，行高恒定不变。
/// 2. **baselineOffset 居中**：对每个文本 run 计算 `(fixedLineHeight - font.lineHeight) / 2`，
///    使文字在固定行盒中垂直居中。
/// 3. **后处理归一化**：段落级 `NSParagraphStyle` 在整段上统一设置，`baselineOffset` 逐 run 设置。
///    任何来源（业务扩展、内联语法）的 attributedString 都会被归一化处理。
public struct InkAttributedRenderer {

  /// 一把渲染完整文本。
  public static func render(
    _ source: String,
    configuration: InkConfiguration = .standard
  ) -> NSAttributedString {
    let filtered = configuration.sourceFilter?(source) ?? source
    let document = InkParser.parse(filtered)
    var visitor = AttributedVisitor(configuration: configuration)
    return visitor.visit(document)
  }

  /// 渲染已解析的 Document（避免重复解析）。
  public static func render(
    document: Document,
    configuration: InkConfiguration = .standard
  ) -> NSAttributedString {
    var visitor = AttributedVisitor(configuration: configuration)
    return visitor.visit(document)
  }

  /// 渲染多个已解析的 Markup 节点（InkBlockRenderer 内部使用，消除 AST→String→AST 迂回）。
  public static func render(
    markups: [Markup],
    configuration: InkConfiguration = .standard
  ) -> NSAttributedString {
    var visitor = AttributedVisitor(configuration: configuration)
    let result = NSMutableAttributedString()
    for (index, markup) in markups.enumerated() {
      result.append(visitor.visit(markup))
      if index < markups.count - 1 {
        result.append(NSAttributedString(string: InkRenderConstants.blockSeparator))
      }
    }

    if !markups.isEmpty {
      let trailingPara = NSMutableParagraphStyle()
      trailingPara.minimumLineHeight = 0.1
      trailingPara.maximumLineHeight = 0.1
      trailingPara.lineSpacing = 0
      trailingPara.paragraphSpacing = 0
      trailingPara.paragraphSpacingBefore = 0
      result.append(NSAttributedString(string: "\n\u{200B}", attributes: [
        .paragraphStyle: trailingPara,
        .font: UIFont.systemFont(ofSize: 0.1),
      ]))
    }

    return result
  }
  /// 只渲染行内元素（加粗、斜体、行内代码、链接、自定义语法等）。
  /// 不设置段落属性，由调用方自行控制行高/对齐/间距。
  public static func renderInline(
    _ text: String,
    configuration: InkConfiguration = .standard,
    baseFont: UIFont,
    textColor: UIColor
  ) -> NSAttributedString {
    let document = InkParser.parse(text)
    guard let paragraph = document.children.first(where: { $0 is Paragraph }) as? Paragraph else {
      return NSAttributedString(string: text, attributes: [
        .font: baseFont,
        .foregroundColor: textColor,
      ])
    }
    var visitor = AttributedVisitor(configuration: configuration)
    visitor.inlineBaseFont = baseFont
    visitor.inlineTextColor = textColor
    let result = NSMutableAttributedString()
    for child in paragraph.children {
      result.append(visitor.visit(child))
    }
    return result
  }
}

// MARK: - 常量

enum InkRenderConstants {
  static let blockSeparator = "\n"
}

// MARK: - Visitor

private struct AttributedVisitor: MarkupVisitor {
  typealias Result = NSAttributedString

  let configuration: InkConfiguration

  /// 行内渲染模式下的基准字体/颜色覆盖（nil 时走 appearance.text）
  var inlineBaseFont: UIFont?
  var inlineTextColor: UIColor?

  private var appearance: InkAppearance { configuration.appearance }

  /// 当前上下文的基准字号
  private var contextFontSize: CGFloat { inlineBaseFont?.pointSize ?? appearance.text.fontSize }
  /// 当前上下文的基准字体（含字号与字重）。行内模式下为容器基准字体，正文模式下为正文字号系统字体。
  private var contextBaseFont: UIFont { inlineBaseFont ?? UIFont.systemFont(ofSize: appearance.text.fontSize) }
  /// 当前上下文的基准颜色
  private var contextTextColor: UIColor { inlineTextColor ?? appearance.text.color }

  // MARK: - 行高工具

  private func baselineOffset(for font: UIFont, in fixedLineHeight: CGFloat) -> CGFloat {
    let delta = fixedLineHeight - font.lineHeight
    guard delta > 0 else { return 0 }
    return delta / 2
  }

  private func lockedParagraphStyle(
    lineHeight: CGFloat,
    spacingBefore: CGFloat = 0,
    spacingAfter: CGFloat = 0
  ) -> NSMutableParagraphStyle {
    let para = NSMutableParagraphStyle()
    para.minimumLineHeight = lineHeight
    para.maximumLineHeight = lineHeight
    para.lineSpacing = 0
    para.paragraphSpacingBefore = spacingBefore
    para.paragraphSpacing = spacingAfter
    return para
  }

  private func applyFixedLineHeight(
    to mutable: NSMutableAttributedString,
    lineHeight: CGFloat,
    spacingBefore: CGFloat = 0,
    spacingAfter: CGFloat = 0,
    extraParagraphConfig: ((NSMutableParagraphStyle) -> Void)? = nil
  ) {
    guard mutable.length > 0 else { return }
    let fullRange = NSRange(location: 0, length: mutable.length)

    let para = lockedParagraphStyle(
      lineHeight: lineHeight,
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter
    )
    extraParagraphConfig?(para)
    mutable.addAttribute(.paragraphStyle, value: para, range: fullRange)

    mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
      let font = (value as? UIFont) ?? UIFont.systemFont(ofSize: appearance.text.fontSize)
      let offset = baselineOffset(for: font, in: lineHeight)
      mutable.addAttribute(.baselineOffset, value: offset, range: range)
    }
  }

  // MARK: - Document

  mutating func defaultVisit(_ markup: Markup) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for child in markup.children {
      result.append(visit(child))
    }
    return result
  }

  mutating func visitDocument(_ document: Document) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let blocks = Array(document.children)
    for (index, block) in blocks.enumerated() {
      result.append(visit(block))
      if index < blocks.count - 1 {
        result.append(NSAttributedString(string: InkRenderConstants.blockSeparator))
      }
    }
    return result
  }

  // MARK: - Heading

  mutating func visitHeading(_ h: Markdown.Heading) -> NSAttributedString {
    let level = h.level
    let size = appearance.heading.fontSize(forLevel: level)
    let lh = appearance.heading.lineHeight(forLevel: level)
    let spacing = appearance.heading.spacingAfter(forLevel: level)

    let inline = renderInlineChildren(of: h)
    let mutable = NSMutableAttributedString(attributedString: inline)
    let fullRange = NSRange(location: 0, length: mutable.length)

    // 标题以 bold + 标题字号为基准，但**合并而非覆盖**行内元素自身的字体特征：
    // 直接对全 range 强设 .font 会把行内代码的等宽字体一并抹掉（`# 标题里的 `代码``
    // 会退化成 bold 系统字体）。因此逐 run 读取既有字体，保留其等宽/斜体特征，
    // 只把字号与基础字重归一化到标题规格。
    mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
      let existing = (value as? UIFont) ?? UIFont.systemFont(ofSize: contextFontSize)
      let traits = existing.fontDescriptor.symbolicTraits

      let headingFont: UIFont
      if traits.contains(.traitMonoSpace) {
        // 行内代码：保持等宽，缩放到标题字号（bold 与标题一致）。
        headingFont = UIFont.monospacedSystemFont(ofSize: size, weight: .bold)
      } else {
        // 普通文字：bold + 标题字号；若原本命中 emphasis(italic) 则保留斜体。
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        if traits.contains(.traitItalic),
           let desc = base.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
          headingFont = UIFont(descriptor: desc, size: size)
        } else {
          headingFont = base
        }
      }
      mutable.addAttribute(.font, value: headingFont, range: range)
    }

    // 颜色维持原行为：标题色覆盖全段。仅本次修复字体 clobber，不改动颜色语义。
    mutable.addAttribute(.foregroundColor, value: appearance.heading.color, range: fullRange)

    applyFixedLineHeight(to: mutable, lineHeight: lh, spacingAfter: spacing)
    return mutable
  }

  // MARK: - Paragraph

  mutating func visitParagraph(_ paragraph: Paragraph) -> NSAttributedString {
    let inline = renderInlineChildren(of: paragraph)
    let mutable = NSMutableAttributedString(attributedString: inline)
    ensureBodyFont(mutable)
    applyFixedLineHeight(
      to: mutable,
      lineHeight: appearance.text.lineHeight,
      spacingAfter: appearance.text.paragraphSpacing
    )
    return mutable
  }

  // MARK: - BlockQuote

  mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let children = Array(blockQuote.children)

    let quoteFont = UIFont.systemFont(ofSize: appearance.blockquote.fontSize)
    let indent = appearance.blockquote.barWidth + appearance.blockquote.leftPadding

    for (index, child) in children.enumerated() {
      let part = NSMutableAttributedString(attributedString: visit(child))
      let fullRange = NSRange(location: 0, length: part.length)

      part.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
        let existing = (value as? UIFont) ?? UIFont.systemFont(ofSize: appearance.text.fontSize)
        let traits = existing.fontDescriptor.symbolicTraits
        let newFont: UIFont
        if let desc = quoteFont.fontDescriptor.withSymbolicTraits(traits) {
          newFont = UIFont(descriptor: desc, size: appearance.blockquote.fontSize)
        } else {
          newFont = quoteFont
        }
        part.addAttribute(.font, value: newFont, range: range)
      }

      part.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
        if value == nil {
          part.addAttribute(.foregroundColor, value: appearance.blockquote.color, range: range)
        }
      }

      let isLast = index == children.count - 1
      let spacingAfter: CGFloat = isLast ? appearance.blockquote.spacingAfter : appearance.blockquote.innerSpacing

      applyFixedLineHeight(to: part, lineHeight: appearance.blockquote.lineHeight, spacingAfter: spacingAfter) { para in
        para.firstLineHeadIndent = indent
        para.headIndent = indent
      }

      result.append(part)
      if !isLast {
        result.append(NSAttributedString(string: "\n"))
      }
    }

    let barInfo = InkBlockquoteBarInfo(
      color: appearance.blockquote.barColor,
      width: appearance.blockquote.barWidth
    )
    let fullRange = NSRange(location: 0, length: result.length)
    result.addAttribute(.inkBlockquoteBar, value: barInfo, range: fullRange)

    return result
  }

  // MARK: - List

  mutating func visitOrderedList(_ orderedList: OrderedList) -> NSAttributedString {
    let items = Array(orderedList.listItems)
    return renderList(items: items, ordered: true, start: Int(orderedList.startIndex))
  }

  mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSAttributedString {
    let items = Array(unorderedList.listItems)
    return renderList(items: items, ordered: false, start: 1)
  }

  mutating func visitListItem(_ listItem: ListItem) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for child in listItem.children {
      result.append(visit(child))
    }
    return result
  }

  private mutating func renderList(items: [ListItem], ordered: Bool, start: Int) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let bodyFont = UIFont.systemFont(ofSize: appearance.text.fontSize)
    let boldFont = UIFont.systemFont(ofSize: appearance.text.fontSize, weight: .bold)

    let maxMarkerWidth: CGFloat
    if ordered {
      let maxNumber = start + items.count - 1
      let sampleMarker = "\(maxNumber). " as NSString
      maxMarkerWidth = ceil(sampleMarker.size(withAttributes: [.font: boldFont]).width)
    } else {
      let bullet = "\u{2022} " as NSString
      maxMarkerWidth = ceil(bullet.size(withAttributes: [.font: bodyFont]).width)
    }

    for (index, item) in items.enumerated() {
      let marker: String
      let markerFont: UIFont
      if ordered {
        marker = "\(start + index). "
        markerFont = bodyFont
      } else if let checkbox = item.checkbox {
        marker = checkbox == .checked ? "\u{2611} " : "\u{2610} "
        markerFont = bodyFont
      } else {
        marker = "\u{2022} "
        markerFont = bodyFont
      }

      let markerAttr = NSAttributedString(
        string: marker,
        attributes: [
          .font: markerFont,
          .foregroundColor: appearance.text.color,
        ]
      )

      let children = Array(item.children)
      var firstParagraphInline: NSAttributedString?
      var nestedBlocks: [(index: Int, content: NSAttributedString)] = []

      for (i, child) in children.enumerated() {
        if let paragraph = child as? Paragraph, firstParagraphInline == nil {
          firstParagraphInline = renderInlineChildren(of: paragraph)
        } else if child is OrderedList || child is UnorderedList {
          nestedBlocks.append((i, visit(child)))
        } else if let paragraph = child as? Paragraph {
          nestedBlocks.append((i, renderInlineChildren(of: paragraph)))
        } else {
          nestedBlocks.append((i, visit(child)))
        }
      }

      let line = NSMutableAttributedString()
      line.append(markerAttr)
      if let inline = firstParagraphInline {
        line.append(inline)
      }

      ensureBodyFont(line)

      let hasNested = !nestedBlocks.isEmpty
      let itemSpacing: CGFloat = hasNested ? 0 : ((index < items.count - 1) ? appearance.list.itemSpacing : appearance.list.spacingAfter)

      applyFixedLineHeight(to: line, lineHeight: appearance.text.lineHeight, spacingAfter: itemSpacing) { para in
        para.firstLineHeadIndent = 0
        para.headIndent = maxMarkerWidth
      }

      result.append(line)

      if hasNested {
        for (blockIdx, block) in nestedBlocks.enumerated() {
          result.append(NSAttributedString(string: "\n"))
          let nested = NSMutableAttributedString(attributedString: block.content)
          if blockIdx == nestedBlocks.count - 1 {
            let nestedSpacing: CGFloat = (index < items.count - 1) ? appearance.list.itemSpacing : appearance.list.spacingAfter
            let fullRange = NSRange(location: 0, length: nested.length)
            nested.enumerateAttribute(.paragraphStyle, in: fullRange, options: [.reverse]) { value, range, stop in
              if let para = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle {
                para.paragraphSpacing = nestedSpacing
                nested.addAttribute(.paragraphStyle, value: para, range: range)
                stop.pointee = true
              }
            }
          }
          result.append(nested)
        }
      }

      if index < items.count - 1 {
        result.append(NSAttributedString(string: "\n"))
      }
    }
    return result
  }

  // MARK: - ThematicBreak

  mutating func visitThematicBreak(_ thematicBreak: Markdown.ThematicBreak) -> NSAttributedString {
    let para = NSMutableParagraphStyle()
    para.minimumLineHeight = appearance.thematicBreak.lineThickness
    para.maximumLineHeight = appearance.thematicBreak.lineThickness
    para.lineSpacing = 0
    para.paragraphSpacingBefore = 0
    para.paragraphSpacing = 0

    return NSAttributedString(
      string: "\u{200B}",
      attributes: [
        .font: UIFont.systemFont(ofSize: 1),
        .foregroundColor: UIColor.clear,
        .paragraphStyle: para,
        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
        .strikethroughColor: appearance.thematicBreak.color,
        .baselineOffset: 0,
      ]
    )
  }

  // MARK: - CodeBlock (富文本通道 fallback)

  mutating func visitCodeBlock(_ codeBlock: Markdown.CodeBlock) -> NSAttributedString {
    let codeAppearance = appearance.codeBlock
    let raw = codeBlock.code
    let trimmed = raw.hasSuffix("\n") ? String(raw.dropLast()) : raw

    let padded = trimmed
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { " \($0) " }
      .joined(separator: "\n")

    let font = UIFont.monospacedSystemFont(ofSize: codeAppearance.fontSize, weight: .regular)

    let para = lockedParagraphStyle(
      lineHeight: codeAppearance.lineHeight,
      spacingBefore: codeAppearance.spacingToText,
      spacingAfter: codeAppearance.spacingToText
    )

    let offset = baselineOffset(for: font, in: codeAppearance.lineHeight)

    return NSAttributedString(
      string: padded,
      attributes: [
        .font: font,
        .foregroundColor: codeAppearance.textColor,
        .backgroundColor: codeAppearance.backgroundColor,
        .paragraphStyle: para,
        .baselineOffset: offset,
      ]
    )
  }

  // MARK: - Inline Elements

  mutating func visitInlineCode(_ inlineCode: Markdown.InlineCode) -> NSAttributedString {
    let font = UIFont.monospacedSystemFont(ofSize: contextFontSize, weight: .regular)
    let bgInfo = InkInlineCodeBackgroundInfo(
      color: appearance.inlineCode.backgroundColor,
      cornerRadius: appearance.inlineCode.cornerRadius,
      insets: appearance.inlineCode.insets,
      height: appearance.inlineCode.backgroundHeight
    )

    let result = NSMutableAttributedString()

    let codeStr = NSAttributedString(
      string: inlineCode.code,
      attributes: [
        .font: font,
        .foregroundColor: appearance.inlineCode.textColor,
        .backgroundColor: appearance.inlineCode.backgroundColor,
        .inkInlineCodeBackground: bgInfo,
      ]
    )

    let leftMargin = NSAttributedString(
      string: "\u{200B}",
      attributes: [
        .font: font,
        .kern: appearance.inlineCode.margin,
      ]
    )
    let rightMargin = NSAttributedString(
      string: "\u{200B}",
      attributes: [
        .font: font,
        .kern: appearance.inlineCode.margin,
      ]
    )

    result.append(leftMargin)
    result.append(codeStr)
    result.append(rightMargin)
    return result
  }

  mutating func visitText(_ textNode: Markdown.Text) -> NSAttributedString {
    if !configuration.inlineSyntaxes.isEmpty {
      // 用当前上下文（正文 / 表格单元格 / 表头…）的基准字体与颜色构造上下文，
      // 交由行内扩展渲染，使自定义组件与所在容器风格一致。
      let context = InkInlineContext(
        baseFont: contextBaseFont,
        textColor: contextTextColor,
        appearance: appearance
      )
      for syntax in configuration.inlineSyntaxes {
        if let rendered = syntax.render(text: textNode.string, context: context) {
          return rendered
        }
      }
    }
    return NSAttributedString(
      string: textNode.string,
      attributes: [
        .font: contextBaseFont,
        .foregroundColor: contextTextColor,
      ]
    )
  }

  mutating func visitEmphasis(_ emphasis: Emphasis) -> NSAttributedString {
    applyTrait(.traitItalic, to: renderInlineChildren(of: emphasis))
  }

  mutating func visitStrong(_ strong: Strong) -> NSAttributedString {
    applyTrait(.traitBold, to: renderInlineChildren(of: strong))
  }

  mutating func visitLink(_ link: Markdown.Link) -> NSAttributedString {
    let inline = renderInlineChildren(of: link)
    let mutable = NSMutableAttributedString(attributedString: inline)
    let fullRange = NSRange(location: 0, length: mutable.length)
    mutable.addAttribute(.foregroundColor, value: appearance.link.color, range: fullRange)
    if let destination = link.destination, let url = URL(string: destination) {
      mutable.addAttribute(.link, value: url, range: fullRange)
    }
    return mutable
  }

  mutating func visitImage(_ image: Markdown.Image) -> NSAttributedString {
    let display = image.plainText.isEmpty ? (image.source ?? "image") : image.plainText
    return NSAttributedString(
      string: "[\u{1F5BC} \(display)]",
      attributes: [
        .font: UIFont.systemFont(ofSize: contextFontSize),
        .foregroundColor: appearance.text.secondaryColor,
      ]
    )
  }

  mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> NSAttributedString {
    let html = inlineHTML.rawHTML
    if Self.isCustomEmptyTag(html) {
      return NSAttributedString()
    }
    if html.lowercased().hasPrefix("<br") {
      return NSAttributedString(string: "\n")
    }
    return NSAttributedString()
  }

  private static let customEmptyTagPattern = try! NSRegularExpression(
    pattern: #"^<[a-zA-Z]+\s[^>]*/>$"#
  )

  private static func isCustomEmptyTag(_ html: String) -> Bool {
    let range = NSRange(html.startIndex..., in: html)
    return customEmptyTagPattern.firstMatch(in: html, range: range) != nil
  }

  mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSAttributedString {
    NSAttributedString(string: "\n")
  }

  mutating func visitSoftBreak(_ softBreak: SoftBreak) -> NSAttributedString {
    NSAttributedString(string: " ")
  }

  // MARK: - Private Helpers

  private mutating func renderInlineChildren<M: Markup>(of markup: M) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for child in markup.children {
      result.append(visit(child))
    }
    return result
  }

  private func ensureBodyFont(_ mutable: NSMutableAttributedString) {
    let fullRange = NSRange(location: 0, length: mutable.length)
    mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
      if value == nil {
        mutable.addAttribute(
          .font,
          value: UIFont.systemFont(ofSize: contextFontSize),
          range: range
        )
      }
    }
  }

  private func applyTrait(_ trait: UIFontDescriptor.SymbolicTraits, to attr: NSAttributedString) -> NSAttributedString {
    let mutable = NSMutableAttributedString(attributedString: attr)
    let fullRange = NSRange(location: 0, length: mutable.length)
    mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
      let baseFont = (value as? UIFont) ?? UIFont.systemFont(ofSize: contextFontSize)
      var traits = baseFont.fontDescriptor.symbolicTraits
      traits.insert(trait)
      if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
        let newFont = UIFont(descriptor: descriptor, size: baseFont.pointSize)
        mutable.addAttribute(.font, value: newFont, range: range)
      } else if trait == .traitItalic {
        mutable.addAttribute(.obliqueness, value: 0.25, range: range)
      }
    }
    return mutable
  }
}
