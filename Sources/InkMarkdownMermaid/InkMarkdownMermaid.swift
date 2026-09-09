import Foundation
import InkMarkdown
import UIKit

/// `InkMarkdownMermaid` addon 入口：宿主须在启动阶段显式调用 ``register()``。
public enum InkMarkdownMermaid {
  /// 供测试或宿主显式访问 addon 资源 bundle。
  public static var bundle: Bundle { Bundle.module }

  /// 向 ``InkGeneratedAddonRuntime`` 注册 Mermaid bridge bundle 与 loader。
  @discardableResult
  public static func register() -> Bool {
    InkGeneratedAddonRuntime.registerResourceBundle(Bundle.module, owner: "mermaid")
    return InkGeneratedAddonRuntime.register(
      owner: "mermaid",
      rendererVersion: InkMermaidImageRenderer.rendererVersion + "/" + InkMermaidImageRenderer.mermaidVersion,
      makeLoader: { InkMermaidAddonGeneratedImageLoader() }
    )
  }
}

/// 注册到核心的 Mermaid 生成型 loader。
private struct InkMermaidAddonGeneratedImageLoader: InkMermaidRenderingProviding {
  func renderMermaid(
    _ request: InkMermaidRenderRequest,
    limits: InkMermaidRenderLimits
  ) async throws -> InkMermaidRenderResult {
    let renderer = await MainActor.run { InkMermaidImageRenderer(limits: limits) }
    return try await renderer.render(request)
  }

  func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage {
    guard request.owner == "mermaid" else { throw ImageLoadError.decodeFailed }
    let theme = InkMermaidTheme(rawValue: request.styleIdentity) ?? .light
    return try await renderMermaid(
      InkMermaidRenderRequest(
        source: request.source,
        display: InkMermaidDisplayContext(
          maxPixelWidth: display.maxPixelWidth,
          scale: display.scale,
          theme: theme
        )
      ),
      limits: .init()
    ).image
  }
}
