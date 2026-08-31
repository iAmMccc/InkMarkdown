import Foundation
import InkMarkdown

/// `InkMarkdownLaTeX` addon 入口：宿主须在启动阶段显式调用 ``register()``。
public enum InkMarkdownLaTeX {
  /// 向 ``InkGeneratedAddonRuntime`` 注册 LaTeX renderer 与 loader。
  @discardableResult
  public static func register() -> Bool {
    InkGeneratedAddonRuntime.register(
      owner: "latex",
      rendererVersion: InkLaTeXAddonRenderer.rendererVersion,
      makeLoader: { InkLaTeXAddonGeneratedImageLoader() }
    )
  }
}
