import UIKit
import Markdown

/// LaTeX 图片渲染的公开配置。默认关闭，保持既有 Markdown 文本行为。
public struct InkLaTeXRendering: Equatable, Sendable {
  /// 是否启用 LaTeX 渲染总开关。开启后默认识别 `\\(...\\)`、`$$...$$` 与 `\\[...\\]`。
  public var isEnabled: Bool = false
  /// 是否识别 `$...$` 行内分隔符。默认 `false`；即使总开关开启，也需显式 opt-in 才会渲染美元符公式。
  public var allowsInlineDollarDelimiter: Bool = false
  public var inlineStyle: InkLaTeXStyle = .init()
  public var blockStyle: InkLaTeXStyle = .init(fontSize: 20, horizontalPadding: 6, verticalPadding: 6)
  
  /// 本地化错误提示信息配置
  public var errorMessages: ErrorMessages = .init()

  public struct ErrorMessages: Equatable, Sendable {
    public var emptyExpression: String = "LaTeX expression is empty."
    public var contentTooLongFormat: String = "LaTeX expression exceeds %d character limit."
    public var unclosedDelimiterFormat: String = "Unclosed LaTeX delimiter: %@"
    public var unbalancedBraces: String = "Unbalanced LaTeX braces."
    public var invalidDisplayContext: String = "Invalid LaTeX display context."
    public var imageTooLarge: String = "LaTeX rendered image exceeds allowed size."
    public var renderingFailedFormat: String = "LaTeX rendering failed: %@"

    public init() {}
  }

  public init() {}

  var parseOptions: InkLaTeXParseOptions {
    InkLaTeXParseOptions(
      allowsInlineDollarDelimiter: allowsInlineDollarDelimiter,
      recognizesPreservedBracketDelimiters: true,
      recognizesBackslashBracketDelimiters: false
    )
  }
}

/// 将 LaTeX renderer 适配进统一图片 Store 的 loader；自身不缓存图片。
public struct InkLaTeXGeneratedImageLoader: InkGeneratedImageLoading {
  public let mode: InkLaTeXRenderMode
  public let style: InkLaTeXStyle

  public init(mode: InkLaTeXRenderMode, style: InkLaTeXStyle) {
    self.mode = mode
    self.style = style
  }

  public func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage {
    guard request.owner == "latex" else { throw ImageLoadError.decodeFailed }
    return try await InkLaTeXImageRenderer().render(InkLaTeXRenderRequest(
      latex: request.source,
      mode: mode,
      display: display,
      style: style
    )).image
  }
}

/// `$...$` 与 `\\(...\\)` 的 attributed-string 接入。
///
/// Attachment 仅持有生成来源；实际图像仍在显示层绑定时经 `InkImageStore` 加载。
public struct InkLaTeXInlineSyntax: InkInlineSyntax {
  public let rendering: InkLaTeXRendering

  public init(rendering: InkLaTeXRendering) {
    self.rendering = rendering
  }

  public func render(text: String, context: InkInlineContext) -> NSAttributedString? {
    guard rendering.isEnabled else { return nil }
    guard case .success(let expressions) = InkLaTeXSyntax.parse(text, options: rendering.parseOptions),
          !expressions.isEmpty else {
      return nil
    }
    guard expressions.allSatisfy({ $0.renderMode == .inline }) else { return nil }

    let resolvedColor = rendering.inlineStyle.color ?? context.resolvedTextColor
    let resolvedStyle = rendering.inlineStyle.resolved(with: resolvedColor)

    let result = NSMutableAttributedString()
    var cursor = 0
    let utf16 = text.utf16
    for expression in expressions {
      guard expression.utf16Range.location >= cursor else { return nil }
      let prefixRange = NSRange(location: cursor, length: expression.utf16Range.location - cursor)
      if prefixRange.length > 0, let range = Range(prefixRange, in: text) {
        result.append(NSAttributedString(string: String(text[range]), attributes: [
          .font: context.baseFont,
          .foregroundColor: context.textColor,
        ]))
      }
      let source = ImageSource(generated: InkGeneratedImageRequest(
        owner: "latex",
        rendererVersion: InkLaTeXImageRenderer.rendererVersion,
        source: InkLaTeXRenderRequest.normalizedLatex(expression.latex),
        styleIdentity: "inline:" + resolvedStyle.stableID(resolvedColor: resolvedColor)
      ))
      var imageRendering = context.appearance.imageRendering
      imageRendering.isEnabled = true
      imageRendering.generatedLoader = InkLaTeXGeneratedImageLoader(mode: .inline, style: resolvedStyle)
      result.append(NSAttributedString(attachment: InkImageAttachment(
        source: source,
        rendering: imageRendering,
        store: nil
      )))
      cursor = expression.utf16Range.location + expression.utf16Range.length
    }
    if cursor < utf16.count, let range = Range(NSRange(location: cursor, length: utf16.count - cursor), in: text) {
      result.append(NSAttributedString(string: String(text[range]), attributes: [
        .font: context.baseFont,
        .foregroundColor: context.textColor,
      ]))
    }
    return result
  }
}

/// 独占一段的 `$$...$$` 或 `\\[...\\]` 转为图片块；不完整或混合文本保持富文本降级。
public struct InkLaTeXBlockHandler: InkBlockHandler {
  public init() {}

  private enum BlockDelimiter {
    case dollar
    case bracket
  }

  public func canHandle(_ markup: Markup) -> Bool {
    guard let paragraph = markup as? Paragraph else { return false }
    let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.hasPrefix("$$") && text.hasSuffix("$$") && text.count > 4 { return true }
    if text.hasPrefix(InkLaTeXSourcePreservation.blockOpen),
       text.hasSuffix(InkLaTeXSourcePreservation.blockClose),
       text.count > 2 { return true }
    return false
  }

  public func consume(
    from children: [Markup],
    startingAt index: Int,
    configuration: InkConfiguration
  ) -> (block: InkRenderableBlock, consumedCount: Int)? {
    guard index < children.count else { return nil }
    let latexRendering = configuration.appearance.latexRendering
    guard latexRendering.isEnabled else { return nil }

    let markup = children[index]

    if canHandle(markup), let block = makeBlock(from: markup, configuration: configuration) {
      return (block, 1)
    }

    guard let opening = openingDelimiter(in: markup) else { return nil }

    var latexParts: [String] = []
    var scanIndex = index + 1

    while scanIndex < children.count {
      guard let paragraph = children[scanIndex] as? Paragraph else { return nil }
      let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)

      if isClosingDelimiter(text, for: opening) {
        let latex = latexParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latex.isEmpty,
              let block = makeLaTeXImageBlock(latex: latex, configuration: configuration) else {
          return nil
        }
        return (block, scanIndex - index + 1)
      }

      latexParts.append(paragraph.plainText)
      scanIndex += 1
    }

    return nil
  }

  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let paragraph = markup as? Paragraph else { return nil }
    let latexRendering = configuration.appearance.latexRendering
    guard latexRendering.isEnabled else { return nil }
    let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    let latex: String
    if text.hasPrefix("$$") && text.hasSuffix("$$") {
      latex = String(text.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
    } else if text.hasPrefix(InkLaTeXSourcePreservation.blockOpen),
              text.hasSuffix(InkLaTeXSourcePreservation.blockClose) {
      latex = String(text.dropFirst(1).dropLast(1)).trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      return nil
    }
    guard !latex.isEmpty else { return nil }
    return makeLaTeXImageBlock(latex: latex, configuration: configuration)
  }

  /// 独占段落且 trim 后恰为 opening 定界符（跨段块级公式的起始段）。
  private func openingDelimiter(in markup: Markup) -> BlockDelimiter? {
    guard let paragraph = markup as? Paragraph else { return nil }
    let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    if text == "$$" { return .dollar }
    if text == InkLaTeXSourcePreservation.blockOpen { return .bracket }
    return nil
  }

  private func isClosingDelimiter(_ text: String, for opening: BlockDelimiter) -> Bool {
    switch opening {
    case .dollar: text == "$$"
    case .bracket: text == InkLaTeXSourcePreservation.blockClose
    }
  }

  private func makeLaTeXImageBlock(
    latex: String,
    configuration: InkConfiguration
  ) -> InkRenderableBlock? {
    let latexRendering = configuration.appearance.latexRendering
    let resolvedColor = latexRendering.blockStyle.color ?? InkLaTeXColor(
      resolving: configuration.appearance.text.color,
      environment: configuration.renderEnvironment
    )
    let resolvedStyle = latexRendering.blockStyle.resolved(with: resolvedColor)
    let source = ImageSource(generated: InkGeneratedImageRequest(
      owner: "latex",
      rendererVersion: InkLaTeXImageRenderer.rendererVersion,
      source: InkLaTeXRenderRequest.normalizedLatex(latex),
      styleIdentity: "block:" + resolvedStyle.stableID(resolvedColor: resolvedColor)
    ))
    var imageRendering = configuration.appearance.imageRendering
    imageRendering.isEnabled = true
    imageRendering.generatedLoader = InkLaTeXGeneratedImageLoader(mode: .block, style: resolvedStyle)
    return InkImageBlock(source: source, rendering: imageRendering)
  }
}
