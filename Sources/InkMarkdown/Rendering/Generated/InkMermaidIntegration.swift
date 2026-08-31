import UIKit
import Markdown

/// Mermaid 的公共开关与主题。默认关闭，因而不会接管既有 `mermaid` 代码围栏。
public struct InkMermaidRendering: Equatable, Sendable {
  /// 是否启用 Mermaid 渲染。开启前必须链接 `InkMarkdownMermaid` product 并调用
  /// `InkMarkdownMermaid.register()`；未注册的生成图请求会报告对应 owner 不可用。
  public var isEnabled: Bool = false
  /// 生成图使用的 Mermaid 主题。
  public var theme: InkMermaidTheme = .light
  /// 源码长度、输出尺寸和超时限制。
  public var limits: InkMermaidRenderLimits = .init()

  /// 创建默认关闭的 Mermaid 渲染配置。
  public init() {}
}

/// 已注册的 Mermaid addon → 现有图片 Store 的 adapter。它不保留任何位图缓存。
/// 在构造 loader 或 renderer 前调用 `InkMarkdownMermaid.register()`；注册会提供固定版本的
/// bridge 资源 bundle。
public final class InkMermaidGeneratedImageLoader: InkGeneratedImageLoading, InkConfigurationSemanticsProviding, @unchecked Sendable {
  private let limits: InkMermaidRenderLimits

  /// 创建不持有位图缓存的 Mermaid loader。
  public init(limits: InkMermaidRenderLimits = .init()) {
    self.limits = limits
  }

  /// 由 renderer 版本、Mermaid 版本和全部限制派生的稳定语义身份。
  public var semanticIdentity: InkSemanticIdentity? {
    InkSemanticIdentity([
      InkMermaidImageRenderer.rendererVersion,
      InkMermaidImageRenderer.mermaidVersion,
      String(limits.maximumSourceCharacters),
      String(Double(limits.minimumPixelWidth)),
      String(Double(limits.maximumPixelWidth)),
      String(Double(limits.maximumPixelHeight)),
      String(limits.timeout),
    ].joined(separator: "|"))
  }

  /// 比较另一 loader 是否使用相同限制。
  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    guard let other = other as? InkMermaidGeneratedImageLoader else { return false }
    return limits == other.limits
  }

  /// 将 Mermaid 请求交给已注册 addon，并返回生成图片。
  ///
  /// 未注册 `InkMarkdownMermaid` 或请求 owner 不匹配时抛出明确错误；缓存由外层
  /// ``InkImageStore`` 管理。
  public func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage {
    guard request.owner == "mermaid" else { throw ImageLoadError.decodeFailed }
    guard let provider = InkGeneratedAddonRuntime.makeLoader(owner: "mermaid") as? InkMermaidRenderingProviding else {
      throw ImageLoadError.generatedLoaderUnavailable(owner: "mermaid")
    }
    let theme = InkMermaidTheme(rawValue: request.styleIdentity) ?? .light
    let result = try await provider.renderMermaid(InkMermaidRenderRequest(
      source: request.source,
      display: InkMermaidDisplayContext(
        maxPixelWidth: display.maxPixelWidth,
        scale: display.scale,
        theme: theme
      )
    ), limits: limits)
    return result.image
  }
}

/// 将精确标记为 `mermaid` 的围栏代码转为图片块。
/// 宿主须在首次渲染前调用 `InkMarkdownMermaid.register()`。
public struct InkMermaidBlockHandler: InkBlockHandler, InkConfigurationSemanticsProviding {
  /// 创建无状态的 Mermaid 围栏 handler。
  public init() {}

  /// Mermaid handler 无实例配置，因此同类型实例始终语义等价。
  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    other is InkMermaidBlockHandler
  }

  /// 判断节点是否为语言标记精确匹配 Mermaid 的围栏代码块。
  public func canHandle(_ markup: Markup) -> Bool {
    guard let code = markup as? Markdown.CodeBlock else { return false }
    return InkMermaidFence.isMermaid(language: code.language)
  }

  /// 将已启用的 Mermaid 围栏转换为生成图片块；配置关闭或类型不匹配时返回 `nil`。
  @MainActor
  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let code = markup as? Markdown.CodeBlock else { return nil }
    let mermaid = configuration.appearance.mermaidRendering
    guard mermaid.isEnabled else { return nil }

    let source = ImageSource(generated: InkGeneratedImageRequest(
      owner: "mermaid",
      rendererVersion: InkMermaidImageRenderer.rendererVersion + "/" + InkMermaidImageRenderer.mermaidVersion,
      source: code.code,
      styleIdentity: mermaid.theme.rawValue
    ))
    var imageRendering = configuration.appearance.imageRendering
    imageRendering.isEnabled = true
    imageRendering.generatedLoader = InkMermaidGeneratedImageLoader(limits: mermaid.limits)
    imageRendering.failureFallback = .sourceCode(code.code, language: code.language)
    imageRendering.failureCodeBlockStyle = configuration.appearance.codeBlock
    return InkImageBlock(source: source, rendering: imageRendering)
  }
}
