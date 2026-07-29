import UIKit
import Markdown

/// LaTeX 图片渲染的公开配置。默认关闭，保持既有 Markdown 文本行为。
public struct InkLaTeXRendering {
  public var isEnabled: Bool = false
  public var inlineStyle: InkLaTeXStyle = .init()
  public var blockStyle: InkLaTeXStyle = .init(fontSize: 20, horizontalPadding: 6, verticalPadding: 6)

  public init() {}
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
    guard case .success(let expressions) = InkLaTeXSyntax.parse(text), !expressions.isEmpty else {
      return nil
    }
    guard expressions.allSatisfy({ $0.delimiter != .blockDollar }) else { return nil }

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
        styleIdentity: "inline:" + rendering.inlineStyle.stableID
      ))
      var imageRendering = context.appearance.imageRendering
      imageRendering.isEnabled = true
      imageRendering.generatedLoader = InkLaTeXGeneratedImageLoader(mode: .inline, style: rendering.inlineStyle)
      result.append(NSAttributedString(attachment: InkImageAttachment(source: source, rendering: imageRendering)))
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

/// 独占一段的 `$$...$$` 转为图片块；不完整或混合文本保持富文本降级。
public struct InkLaTeXBlockHandler: InkBlockHandler {
  public init() {}

  public func canHandle(_ markup: Markup) -> Bool {
    guard let paragraph = markup as? Paragraph else { return false }
    let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.hasPrefix("$$") && text.hasSuffix("$$") && text.count > 4
  }

  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let paragraph = markup as? Paragraph else { return nil }
    let latexRendering = configuration.appearance.latexRendering
    guard latexRendering.isEnabled else { return nil }
    let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    let latex = String(text.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !latex.isEmpty else { return nil }
    let source = ImageSource(generated: InkGeneratedImageRequest(
      owner: "latex",
      rendererVersion: InkLaTeXImageRenderer.rendererVersion,
      source: InkLaTeXRenderRequest.normalizedLatex(latex),
      styleIdentity: "block:" + latexRendering.blockStyle.stableID
    ))
    var imageRendering = configuration.appearance.imageRendering
    imageRendering.isEnabled = true
    imageRendering.generatedLoader = InkLaTeXGeneratedImageLoader(mode: .block, style: latexRendering.blockStyle)
    return InkImageBlock(source: source, rendering: imageRendering)
  }
}
