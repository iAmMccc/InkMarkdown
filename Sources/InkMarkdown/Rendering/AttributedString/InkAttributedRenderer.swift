import UIKit
import Markdown

/// Markdown → NSAttributedString 渲染器（UIKit 通道）。
///
/// 核心设计原则：
/// 1. **固定行高**：所有段落通过 `minimumLineHeight = maximumLineHeight` 双向锁死行高，
///    保证无论行内嵌入何种字体/字号，行高恒定不变。
/// 2. **baselineOffset 居中**：对每个文本 run 计算 `(fixedLineHeight - font.lineHeight) / 2`，
///    使文字在固定行盒中垂直居中。
/// 3. **context 下传**：行内样式（字体/颜色/链接）通过 `InkTextContext` 随递归**向下传递**，
///    叶子节点一次性生成正确的 run，不再"先渲染子节点、父节点回头 enumerate 覆盖"。
///    后处理**仅**做两件事：施加段落级统一 `.paragraphStyle`、按 run 自身 font 派生 `.baselineOffset`——
///    二者都不改写任何 font/color/trait/自定义 attribute 的决定。
///
/// // 为什么 拆分 public struct 与 private InkRenderer：
/// // InkAttributedRenderer 作为公开命名空间，提供纯函数风格的静态方法，对外屏蔽状态；
/// // 内部的 InkRenderer 是实例类型，持有 configuration 及其解包的 appearance，
/// // 避免在整个递归调用链中反复传递配置对象。
public struct InkAttributedRenderer {

  /// 一把渲染完整文本。
  public static func render(
    _ source: String,
    configuration: InkConfiguration = .standard
  ) -> NSAttributedString {
    let filtered = configuration.sourceFilter?(source) ?? source
    let document = InkParser.parse(filtered)
    let renderer = InkRenderer(configuration: configuration)
    return renderer.renderDocument(document)
  }

  /// 渲染已解析的 Document（避免重复解析）。
  public static func render(
    document: Document,
    configuration: InkConfiguration = .standard
  ) -> NSAttributedString {
    let renderer = InkRenderer(configuration: configuration)
    return renderer.renderDocument(document)
  }

  /// 渲染多个已解析的 Markup 节点（InkBlockRenderer 内部使用，消除 AST→String→AST 迂回）。
  public static func render(
    markups: [Markup],
    configuration: InkConfiguration = .standard
  ) -> NSAttributedString {
    let renderer = InkRenderer(configuration: configuration)
    let result = NSMutableAttributedString()
    for (index, markup) in markups.enumerated() {
      result.append(renderer.renderBlock(markup, context: renderer.bodyContext))
      if index < markups.count - 1 {
        result.append(NSAttributedString(string: InkRenderConstants.blockSeparator))
      }
    }

    if !markups.isEmpty {
      // // 为什么 需要尾部哨兵段落：
      // 在块路由拼装场景中，相邻块之间通常只有换行，如果最后一块设置了 paragraphSpacing（段后距），
      // TextKit 需要有一个后续段落作为参照物才能把这段间距渲染出来。
      // 因此在结尾追加一个几乎不可见（高度 0.1pt）的占位段落，专门用来兑现最后一块的底部间距。
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
    let renderer = InkRenderer(configuration: configuration)
    let context = InkTextContext(font: baseFont, foregroundColor: textColor, appearance: configuration.appearance)
    let result = NSMutableAttributedString()
    for child in paragraph.children {
      result.append(renderer.renderInline(child, context: context))
    }
    return result
  }
}

// MARK: - 常量

enum InkRenderConstants {
  static let blockSeparator = "\n"
}

// MARK: - Renderer（context 下传递归）

private struct InkRenderer {

  let configuration: InkConfiguration

  private var appearance: InkAppearance { configuration.appearance }

  /// 正文基准上下文：正文字号系统字体 + 正文色。块级递归的起点。
  var bodyContext: InkTextContext {
    InkTextContext(
      font: UIFont.systemFont(ofSize: appearance.text.fontSize),
      foregroundColor: appearance.text.color,
      appearance: appearance
    )
  }

  // MARK: - Document

  func renderDocument(_ document: Document) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let blocks = Array(document.children)
    for (index, block) in blocks.enumerated() {
      result.append(renderBlock(block, context: bodyContext))
      if index < blocks.count - 1 {
        result.append(NSAttributedString(string: InkRenderConstants.blockSeparator))
      }
    }
    return result
  }

  // MARK: - Block dispatch

  func renderBlock(_ markup: Markup, context: InkTextContext) -> NSAttributedString {
    switch markup {
    case let h as Markdown.Heading:
      return renderHeading(h, context: context)
    case let p as Paragraph:
      return renderParagraph(p, context: context)
    case let q as BlockQuote:
      return renderBlockQuote(q, context: context)
    case let ol as OrderedList:
      return renderList(items: Array(ol.listItems), ordered: true, start: Int(ol.startIndex), context: context)
    case let ul as UnorderedList:
      return renderList(items: Array(ul.listItems), ordered: false, start: 1, context: context)
    case let cb as Markdown.CodeBlock:
      // // 为什么 不传 context：
      // 围栏代码块和分割线在本通道仅作为富文本 fallback，它们内部的排版完全自给自足（等宽字体/背景色或横线），
      // 不受外层容器（如引用、列表）的字号/颜色派生影响，因此不需要接收 context。
      return renderCodeBlock(cb)
    case is Markdown.ThematicBreak:
      return renderThematicBreak()
    default:
      // 未知块：退化为拼接子块，保持 context。
      let result = NSMutableAttributedString()
      for child in markup.children {
        result.append(renderBlock(child, context: context))
      }
      return result
    }
  }

  // MARK: - Inline dispatch

  func renderInline(_ markup: Markup, context: InkTextContext) -> NSAttributedString {
    switch markup {
    case let t as Markdown.Text:
      return renderText(t, context: context)
    case let c as Markdown.InlineCode:
      return renderInlineCode(c, context: context)
    case let e as Emphasis:
      return renderInlineChildren(of: e, context: context.addingTrait(.traitItalic))
    case let s as Strong:
      return renderInlineChildren(of: s, context: context.addingTrait(.traitBold))
    case let st as Strikethrough:
      return renderInlineChildren(of: st, context: context.striking())
    case let l as Markdown.Link:
      return renderLink(l, context: context)
    case let img as Markdown.Image:
      return renderImage(img, context: context)
    case let html as InlineHTML:
      return renderInlineHTML(html)
    case is LineBreak:
      return NSAttributedString(string: "\n")
    case is SoftBreak:
      return NSAttributedString(string: " ")
    default:
      return renderInlineChildren(of: markup, context: context)
    }
  }

  private func renderInlineChildren(of markup: Markup, context: InkTextContext) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for child in markup.children {
      result.append(renderInline(child, context: context))
    }
    return result
  }

  // MARK: - Heading

  private func renderHeading(_ h: Markdown.Heading, context: InkTextContext) -> NSAttributedString {
    let level = h.level
    let size = appearance.heading.fontSize(forLevel: level)
    let lh = appearance.heading.lineHeight(forLevel: level)
    let spacing = appearance.heading.spacingAfter(forLevel: level)

    // 标题派生：bold + 标题字号 + 标题色。行内子节点在此基础上再派生
    // （inlineCode 会 monospaced() 重置回等宽、link 会 coloring() 改色），互不覆盖。
    let headingContext = InkTextContext(
      font: UIFont.systemFont(ofSize: size, weight: .bold),
      foregroundColor: appearance.heading.color,
      appearance: appearance
    )
    let mutable = NSMutableAttributedString(attributedString: renderInlineChildren(of: h, context: headingContext))
    applyFixedLineHeight(to: mutable, lineHeight: lh, spacingAfter: spacing)
    return mutable
  }

  // MARK: - Paragraph

  private func renderParagraph(_ paragraph: Paragraph, context: InkTextContext) -> NSAttributedString {
    let mutable = NSMutableAttributedString(attributedString: renderInlineChildren(of: paragraph, context: context))
    applyFixedLineHeight(
      to: mutable,
      lineHeight: appearance.text.lineHeight,
      spacingAfter: appearance.text.paragraphSpacing
    )
    return mutable
  }

  // MARK: - BlockQuote

  private func renderBlockQuote(_ blockQuote: BlockQuote, context: InkTextContext) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let children = Array(blockQuote.children)

    // 引用派生：引用字号 + 引用色。行内 link 仍会 coloring() 覆盖回链接色（两者共存），
    // inlineCode 仍 monospaced()——因为是 context 下传而非事后回写，样式不再互踩。
    let quoteFont = UIFont.systemFont(ofSize: appearance.blockquote.fontSize)
    let quoteContext = context.withFont(quoteFont).coloring(appearance.blockquote.color)
    let indent = appearance.blockquote.barWidth + appearance.blockquote.leftPadding

    for (index, child) in children.enumerated() {
      let isLast = index == children.count - 1
      let spacingAfter: CGFloat = isLast ? appearance.blockquote.spacingAfter : appearance.blockquote.innerSpacing

      let part: NSMutableAttributedString
      if let paragraph = child as? Paragraph {
        // 段落：施加引用块行高 + 缩进（引用块的标准排版）。
        part = NSMutableAttributedString(attributedString: renderInlineChildren(of: paragraph, context: quoteContext))
        applyFixedLineHeight(to: part, lineHeight: appearance.blockquote.lineHeight, spacingAfter: spacingAfter) { para in
          para.firstLineHeadIndent = indent
          para.headIndent = indent
        }
      } else {
        // 非段落（嵌套 list / 代码块）：renderBlock 已设好各自的段落样式
        // （list 悬挂缩进、代码块行高），不再用 applyFixedLineHeight 全 range 覆盖——
        // // 为什么 只叠缩进不盖段落样式：
        // 否则会把子节点（如嵌套列表）特有的悬挂缩进、段后距等抹平成引用块的标准规格。
        // 所以这里只在其既有缩进上叠加引用的左缩进，保持子节点原本的段落几何形态。
        part = NSMutableAttributedString(attributedString: renderBlock(child, context: quoteContext))
        let fullRange = NSRange(location: 0, length: part.length)
        part.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
          guard let existing = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle else { return }
          existing.firstLineHeadIndent += indent
          existing.headIndent += indent
          part.addAttribute(.paragraphStyle, value: existing, range: range)
        }
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
    result.addAttribute(.inkBlockquoteBar, value: barInfo, range: NSRange(location: 0, length: result.length))
    return result
  }

  // MARK: - List

  private func renderList(items: [ListItem], ordered: Bool, start: Int, context: InkTextContext) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let bodyFont = UIFont.systemFont(ofSize: appearance.text.fontSize)

    // 序号/圆点用正文字重（不加粗）。
    let maxMarkerWidth: CGFloat
    if ordered {
      let maxNumber = start + items.count - 1
      let sampleMarker = "\(maxNumber). " as NSString
      maxMarkerWidth = ceil(sampleMarker.size(withAttributes: [.font: bodyFont]).width)
    } else {
      let bullet = "\u{2022} " as NSString
      maxMarkerWidth = ceil(bullet.size(withAttributes: [.font: bodyFont]).width)
    }

    for (index, item) in items.enumerated() {
      let marker: String
      let markerFont: UIFont = bodyFont
      if ordered {
        marker = "\(start + index). "
      } else if let checkbox = item.checkbox {
        marker = checkbox == .checked ? "\u{2611} " : "\u{2610} "
      } else {
        marker = "\u{2022} "
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
          firstParagraphInline = renderInlineChildren(of: paragraph, context: context)
        } else if child is OrderedList || child is UnorderedList {
          nestedBlocks.append((i, renderBlock(child, context: context)))
        } else if let paragraph = child as? Paragraph {
          nestedBlocks.append((i, renderInlineChildren(of: paragraph, context: context)))
        } else {
          nestedBlocks.append((i, renderBlock(child, context: context)))
        }
      }

      let line = NSMutableAttributedString()
      line.append(markerAttr)
      if let inline = firstParagraphInline {
        line.append(inline)
      }

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

  // MARK: - ThematicBreak（保持现状：富文本通道的占位实现；view 版走 InkThematicBreakBlock）

  private func renderThematicBreak() -> NSAttributedString {
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

  // MARK: - CodeBlock（富文本通道 fallback；view 版走 InkCodeBlock）

  private func renderCodeBlock(_ codeBlock: Markdown.CodeBlock) -> NSAttributedString {
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

  private func renderInlineCode(_ inlineCode: Markdown.InlineCode, context: InkTextContext) -> NSAttributedString {
    // 代码身份：等宽 + 环境字号（monospaced() 重置字重/traits），颜色回落到环境色。
    let font = context.monospaced().font
    let color = appearance.inlineCode.textColor ?? context.foregroundColor
    let bgInfo = InkInlineCodeBackgroundInfo(
      color: appearance.inlineCode.backgroundColor,
      cornerRadius: appearance.inlineCode.cornerRadius,
      insets: appearance.inlineCode.insets,
      height: appearance.inlineCode.backgroundHeight
    )

    var codeAttrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
      .backgroundColor: appearance.inlineCode.backgroundColor,
      .inkInlineCodeBackground: bgInfo,
    ]
    // 处于链接内（如 [`code`](url)）时叶子也挂 .link，保持可点击。
    if let url = context.linkURL {
      codeAttrs[.link] = url
    }

    var marginAttrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .kern: appearance.inlineCode.margin,
    ]

    if context.isStrikethrogh {
      codeAttrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
      marginAttrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
    }

    let codeStr = NSAttributedString(string: inlineCode.code, attributes: codeAttrs)
    let leftMargin = NSAttributedString(string: "\u{200B}", attributes: marginAttrs)
    let rightMargin = NSAttributedString(string: "\u{200B}", attributes: marginAttrs)

    let result = NSMutableAttributedString()
    result.append(leftMargin)
    result.append(codeStr)
    result.append(rightMargin)

    return result
  }

  private func renderText(_ textNode: Markdown.Text, context: InkTextContext) -> NSAttributedString {
    if !configuration.inlineSyntaxes.isEmpty || configuration.appearance.latexRendering.isEnabled {
      // // 为什么 inline-syntax 优先：
      // 赋予业务自定义扩展（如 $标签$、@提及）最高优先级去拦截并处理文本。
      // 若某个扩展决定处理该片段并返回结果，就可以直接 early-return，不再走默认属性回落。
      // 用当前 context 的字体/颜色构造行内扩展上下文，使自定义组件与所在容器风格一致。
      let inlineContext = InkInlineContext(
        baseFont: context.font,
        textColor: context.foregroundColor,
        appearance: appearance
      )
      for syntax in configuration.inlineSyntaxes {
        if let rendered = syntax.render(text: textNode.string, context: inlineContext) {
          return rendered
        }
      }
      // LaTeX 是由配置开启的内置语法，而非在 enable 时捕获的一份样式快照。
      // 放在业务自定义语法之后，保留既有扩展点的优先级约定。
      if configuration.appearance.latexRendering.isEnabled,
         let rendered = InkLaTeXInlineSyntax(rendering: configuration.appearance.latexRendering)
           .render(text: textNode.string, context: inlineContext) {
        return rendered
      }
    }
    var attrs: [NSAttributedString.Key: Any] = [
      .font: context.font,
      .foregroundColor: context.foregroundColor,
    ]
    if let url = context.linkURL {
      attrs[.link] = url
    }

    if context.isStrikethrogh {
      attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
    }

    // 斜体兜底：字体无 italic 变体时以人工倾斜模拟（emphasis 内的普通字体）。
    if context.obliqueness != 0 {
      attrs[.obliqueness] = context.obliqueness
    }
    return NSAttributedString(string: textNode.string, attributes: attrs)
  }

  private func renderLink(_ link: Markdown.Link, context: InkTextContext) -> NSAttributedString {
    // 派生：改为链接色 + 置入链接目标，下传给所有子节点的叶子。
    var linkContext = context.coloring(appearance.link.color)
    if let destination = link.destination, let url = URL(string: destination) {
      linkContext = linkContext.linking(url)
    }
    return renderInlineChildren(of: link, context: linkContext)
  }

  private func renderImage(_ image: Markdown.Image, context: InkTextContext) -> NSAttributedString {
    let rendering = appearance.imageRendering

    guard rendering.isEnabled,
          let urlString = image.source,
          let url = URL(string: urlString) else {
      let display = image.plainText.isEmpty ? (image.source ?? "image") : image.plainText
      var attrs: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: context.font.pointSize),
        .foregroundColor: appearance.text.secondaryColor,
      ]
      if let url = context.linkURL {
        attrs[.link] = url
      }
      return NSAttributedString(string: "[\u{1F5BC} \(display)]", attributes: attrs)
    }

    let source = ImageSource(
      url: url,
      stripsQuery: rendering.securityPolicy.stripsQuery,
      stripsFragment: rendering.securityPolicy.stripsFragment
    )

    if checkSecurityPolicy(source: source, rendering: rendering) != nil {
      let display = image.plainText.isEmpty ? (image.source ?? "image") : image.plainText
      return NSAttributedString(
        string: "[\u{1F5BC} \(display)]",
        attributes: [
          .font: UIFont.systemFont(ofSize: context.font.pointSize),
          .foregroundColor: appearance.text.secondaryColor,
        ]
      )
    }

    let attachment = InkImageAttachment(source: source, rendering: rendering, store: nil)

    let result = NSMutableAttributedString(attachment: attachment)
    result.addAttribute(.baselineOffset, value: 0, range: NSRange(location: 0, length: result.length))

    if let linkURL = context.linkURL {
      result.addAttribute(.link, value: linkURL, range: NSRange(location: 0, length: result.length))
    }

    return result
  }

  private func checkSecurityPolicy(source: ImageSource, rendering: InkImageRendering) -> ImageRejectReason? {
    let policy = rendering.securityPolicy

    guard policy.allowedSchemes.contains(source.scheme) else {
      return .schemeNotAllowed(String(describing: source.scheme))
    }

    if source.scheme == .http || source.scheme == .https {
      if let host = source.rawURL.host {
        if policy.allowedHosts.isEmpty {
          switch policy.emptyHostPolicy {
          case .rejectAll:
            return .hostNotAllowed(host)
          case .allowAll:
            break
          }
        } else if !policy.allowedHosts.contains(host) {
          return .hostNotAllowed(host)
        }
      }
    }

    if source.scheme == .data {
      let dataSize = source.rawURL.absoluteString.count
      if dataSize > rendering.storeConfiguration.maxDataURLBytes {
        return .payloadTooLarge(dataSize)
      }
    }

    return nil
  }

  private func renderInlineHTML(_ inlineHTML: InlineHTML) -> NSAttributedString {
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

  // MARK: - 段落度量后处理（唯一允许的后处理：统一段落样式 + 逐 run 派生 baselineOffset）

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

    // 仅派生：baselineOffset 是 run 自身 font 的纯函数，不改写 font/color 决定。
    mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
      // 图片 attachment 由 renderImage 固定 baselineOffset=0，跳过文本居中偏移。
      var skipForImageAttachment = false
      mutable.enumerateAttribute(.attachment, in: range, options: []) { att, _, stop in
        if att is InkImageAttachment {
          skipForImageAttachment = true
          stop.pointee = true
        }
      }
      if skipForImageAttachment { return }

      let font = (value as? UIFont) ?? UIFont.systemFont(ofSize: appearance.text.fontSize)
      let offset = baselineOffset(for: font, in: lineHeight)
      mutable.addAttribute(.baselineOffset, value: offset, range: range)
    }

    mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
      guard let imgAttachment = value as? InkImageAttachment else { return }
      mutable.addAttribute(.baselineOffset, value: CGFloat(0), range: range)
      if imgAttachment.bounds.height > lineHeight {
        let para = NSMutableParagraphStyle()
        para.minimumLineHeight = lineHeight
        para.maximumLineHeight = max(lineHeight, imgAttachment.bounds.height)
        mutable.addAttribute(.paragraphStyle, value: para, range: range)
      }
    }
  }
}
