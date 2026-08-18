import UIKit
import Markdown

/// Mermaid 的公共开关与主题。默认关闭，因而不会接管既有 `mermaid` 代码围栏。
public struct InkMermaidRendering: Equatable {
  public var isEnabled: Bool = false
  public var theme: InkMermaidTheme = .light
  public var limits: InkMermaidRenderLimits = .init()

  public init() {}
}

/// Mermaid → 现有图片 Store 的 adapter。它不保留任何位图缓存。
public final class InkMermaidGeneratedImageLoader: InkGeneratedImageLoading, @unchecked Sendable {
  private let limits: InkMermaidRenderLimits

  public init(limits: InkMermaidRenderLimits = .init()) {
    self.limits = limits
  }

  public func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage {
    guard request.owner == "mermaid" else { throw ImageLoadError.decodeFailed }
    let theme = InkMermaidTheme(rawValue: request.styleIdentity) ?? .light
    let renderer = await MainActor.run { InkMermaidImageRenderer(limits: limits) }
    let result = try await renderer.render(InkMermaidRenderRequest(
      source: request.source,
      display: InkMermaidDisplayContext(
        maxPixelWidth: display.maxPixelWidth,
        scale: display.scale,
        theme: theme
      )
    ))
    return result.image
  }
}

/// 将精确标记为 `mermaid` 的围栏代码转为图片块。
public struct InkMermaidBlockHandler: InkBlockHandler {
  public init() {}

  public func canHandle(_ markup: Markup) -> Bool {
    guard let code = markup as? Markdown.CodeBlock else { return false }
    return InkMermaidFence.isMermaid(language: code.language)
  }

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
    return MainActor.assumeIsolated {
      InkImageBlock(source: source, store: .shared, rendering: imageRendering)
    }
  }
}
