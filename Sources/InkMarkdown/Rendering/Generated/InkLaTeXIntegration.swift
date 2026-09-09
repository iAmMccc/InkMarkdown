import UIKit
import Markdown

/// LaTeX 图片渲染的公开配置。默认关闭，保持既有 Markdown 文本行为。
public struct InkLaTeXRendering: Equatable, Sendable {
  /// 是否启用 LaTeX 渲染总开关。开启前必须链接 `InkMarkdownLaTeX` product 并调用
  /// `InkMarkdownLaTeX.register()`；未注册时生成图请求会报告 `generatedLoaderUnavailable`。
  /// 开启后默认识别 `\\(...\\)`、`$$...$$` 与 `\\[...\\]`。
  public var isEnabled: Bool = false
  /// 是否识别 `$...$` 行内分隔符。默认 `false`；即使总开关开启，也需显式 opt-in 才会渲染美元符公式。
  public var allowsInlineDollarDelimiter: Bool = false
  /// 行内公式生成图片时使用的字号、颜色和内边距。
  public var inlineStyle: InkLaTeXStyle = .init()
  /// 独占块级公式生成图片时使用的字号、颜色和内边距。
  public var blockStyle: InkLaTeXStyle = .init(fontSize: 20, horizontalPadding: 6, verticalPadding: 6)

  /// 解析与生成失败时使用的本地化提示文案。
  public var errorMessages: ErrorMessages = .init()

  /// LaTeX 解析与图片生成错误的可本地化文案集合。
  public struct ErrorMessages: Equatable, Sendable {
    /// 表达式为空时的提示文案。
    public var emptyExpression: String = "LaTeX expression is empty."
    /// 表达式超过长度限制时的格式；`%d` 替换为允许的字符数。
    public var contentTooLongFormat: String = "LaTeX expression exceeds %d character limit."
    /// 定界符未闭合时的格式；`%@` 替换为起始定界符。
    public var unclosedDelimiterFormat: String = "Unclosed LaTeX delimiter: %@"
    /// 花括号不平衡时的提示文案。
    public var unbalancedBraces: String = "Unbalanced LaTeX braces."
    /// 行内或块级上下文与表达式不匹配时的提示文案。
    public var invalidDisplayContext: String = "Invalid LaTeX display context."
    /// 生成图片超过尺寸限制时的提示文案。
    public var imageTooLarge: String = "LaTeX rendered image exceeds allowed size."
    /// renderer 失败时的格式；`%@` 替换为底层错误说明。
    public var renderingFailedFormat: String = "LaTeX rendering failed: %@"

    /// 创建默认英文错误文案集合。
    public init() {}
  }

  /// 创建默认关闭的 LaTeX 渲染配置。
  public init() {}

  var parseOptions: InkLaTeXParseOptions {
    InkLaTeXParseOptions(
      allowsInlineDollarDelimiter: allowsInlineDollarDelimiter,
      recognizesPreservedBracketDelimiters: true,
      recognizesBackslashBracketDelimiters: false
    )
  }
}

/// 将已注册的 `InkMarkdownLaTeX` renderer 适配进统一图片 Store 的 loader；自身不缓存图片。
/// 未在渲染前调用 `InkMarkdownLaTeX.register()` 时，loader 会抛出
/// `ImageLoadError.generatedLoaderUnavailable(owner: "latex")`。
public struct InkLaTeXGeneratedImageLoader: InkGeneratedImageLoading, InkConfigurationSemanticsProviding {
  /// 当前请求采用的行内或块级渲染模式。
  public let mode: InkLaTeXRenderMode
  /// 传给已注册 addon renderer 的稳定样式快照。
  public let style: InkLaTeXStyle

  /// 创建不持有缓存的 LaTeX 生成图片 loader。
  public init(mode: InkLaTeXRenderMode, style: InkLaTeXStyle) {
    self.mode = mode
    self.style = style
  }

  /// 由 renderer 版本、模式和完整样式派生的稳定语义身份。
  public var semanticIdentity: InkSemanticIdentity? {
    let colorIdentity = style.color.map {
      "\($0.red),\($0.green),\($0.blue),\($0.alpha)"
    } ?? "context"
    return InkSemanticIdentity([
      InkLaTeXImageRenderer.rendererVersion,
      mode.rawValue,
      String(Double(style.fontSize)),
      colorIdentity,
      String(Double(style.horizontalPadding)),
      String(Double(style.verticalPadding)),
      String(Double(style.maxPixelHeight)),
    ].joined(separator: "|"))
  }

  /// 比较另一扩展是否使用相同模式与样式。
  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    guard let other = other as? InkLaTeXGeneratedImageLoader else { return false }
    return mode == other.mode && style == other.style
  }

  /// 将 LaTeX 生成请求转交给已注册的 addon renderer。
  ///
  /// 未注册 `InkMarkdownLaTeX` 或请求 owner 不匹配时抛出明确错误；缓存仍由外层
  /// ``InkImageBackend`` 管理。
  public func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage {
    guard request.owner == "latex" else { throw ImageLoadError.decodeFailed }
    guard let provider = InkGeneratedAddonRuntime.makeLoader(owner: "latex") as? InkLaTeXRenderingProviding else {
      throw ImageLoadError.generatedLoaderUnavailable(owner: "latex")
    }
    return try await provider.renderLaTeX(InkLaTeXRenderRequest(
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
public struct InkLaTeXInlineSyntax: InkInlineSyntax, InkConfigurationSemanticsProviding {
  /// 当前行内语法使用的 LaTeX 配置快照。
  public let rendering: InkLaTeXRendering

  /// 创建只处理完整行内公式集合的语法扩展。
  public init(rendering: InkLaTeXRendering) {
    self.rendering = rendering
  }

  /// 比较另一行内扩展是否使用相同渲染配置。
  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    guard let other = other as? InkLaTeXInlineSyntax else { return false }
    return rendering == other.rendering
  }

  /// 把文本中的完整行内公式转为延迟加载 attachment。
  ///
  /// 配置关闭、无公式或混入块级公式时返回 `nil`，让统一富文本管线继续降级处理。
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
public struct InkLaTeXBlockHandler: InkBlockHandler, InkConfigurationSemanticsProviding {
  /// 创建无状态的块级 LaTeX handler。
  public init() {}

  /// 块级 handler 无实例配置，因此同类型实例始终语义等价。
  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    other is InkLaTeXBlockHandler
  }

  private enum BlockDelimiter {
    case dollar
    case bracket
  }

  /// 判断节点是否是单段内完整闭合的块级公式。
  public func canHandle(_ markup: Markup) -> Bool {
    guard let paragraph = markup as? Paragraph else { return false }
    let text = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.hasPrefix("$$") && text.hasSuffix("$$") && text.count > 4 { return true }
    if text.hasPrefix(InkLaTeXSourcePreservation.blockOpen),
       text.hasSuffix(InkLaTeXSourcePreservation.blockClose),
       text.count > 2 { return true }
    return false
  }

  /// 从当前位置消费单段或跨段块级公式；不完整输入返回 `nil` 交给后续 handler。
  @MainActor
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

  /// 将单个完整块级公式节点转换为生成图片块。
  @MainActor
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

  @MainActor
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
