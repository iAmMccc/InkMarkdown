import UIKit
import InkMarkdown

/// ExampleApp 侧 `InkConfiguration` 工厂，复用 ``DemoStyle`` / ``InkAppearance`` 已有 SSOT。
enum DemoInkConfigurationBuilder {

  /// 组件 / 富媒体 Demo 配置：按开关组合 LaTeX、Mermaid、图片，并注入链接 handler。
  static func makeComponentsConfiguration(
    enableLaTeX: Bool,
    enableMermaid: Bool,
    enableImage: Bool,
    userInterfaceStyle: UIUserInterfaceStyle = UITraitCollection.current.userInterfaceStyle
  ) -> InkConfiguration {
    var appearance: InkAppearance
    switch (enableLaTeX, enableMermaid) {
    case (true, true):
      appearance = .demoDiagramsEnabled(userInterfaceStyle: userInterfaceStyle)
    case (true, false):
      appearance = .demoLaTeXEnabled
    case (false, true):
      appearance = .demoMermaidEnabled(userInterfaceStyle: userInterfaceStyle)
    case (false, false):
      appearance = InkAppearance()
    }

    if enableImage {
      appearance.imageRendering = InkAppearance.demoImageEnabled.imageRendering
    }
    // Ticket 08：组件页文案承诺「长按复制」，须在配置层真正开启。
    appearance.table.enableLongPressCopy = true

    var config = InkConfiguration(appearance: appearance)
    config.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: userInterfaceStyle)
    DemoLinkOpening.configure(&config)
    return config
  }

  /// 静态 Markdown Demo 配置：标准 appearance + 链接 handler。
  static func makeStaticConfiguration(
    userInterfaceStyle: UIUserInterfaceStyle = UITraitCollection.current.userInterfaceStyle
  ) -> InkConfiguration {
    var config = InkConfiguration.standard
    config.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: userInterfaceStyle)
    DemoLinkOpening.configure(&config)
    return config
  }

  /// Chat Demo 配置：LaTeX + Mermaid 全开，演示 CDN 图片 allowlist，统一链接 handler。
  static func makeChatConfiguration(
    userInterfaceStyle: UIUserInterfaceStyle = UITraitCollection.current.userInterfaceStyle
  ) -> InkConfiguration {
    var appearance = InkAppearance.demoDiagramsEnabled(userInterfaceStyle: userInterfaceStyle)
    appearance.imageRendering = InkAppearance.demoImageEnabled.imageRendering

    var config = InkConfiguration(appearance: appearance)
    config.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: userInterfaceStyle)
    DemoLinkOpening.configure(&config)
    return config
  }
}
