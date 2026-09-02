import UIKit
import InkMarkdown

/// ExampleApp 侧的「样式 tab」枚举——**演示如何用核心扩展点做业务定制**。
///
/// 重构后核心库只内置「标准 Markdown + 标准样式」，不含任何预设配方。业务定制一律走
/// 扩展点，本枚举每个 case 对应其中一种用法：
/// - ``brandedTheme``：自定义 `InkAppearance`（覆盖字号 / 颜色）。
/// - ``h1ActionCard``：Block 路由，把整块标题替换成自定义 UIView。
enum DemoStyle {
  /// 标准样式（核心内置，开箱即用）。
  case standard
  /// 自定义主题：放大标题 + 品牌色链接，演示 `InkAppearance` 覆盖。
  case brandedTheme
  /// 业务卡片：H1 替换成浅紫圆角卡片，演示 Block 路由。
  case h1ActionCard
  /// 表格卡片：Markdown 表格替换成原生 UIView 表格，演示 Table Block 路由。
  case tableCard
  /// 图片 opt-in：开启 `InkImageRendering.isEnabled`，演示真图行内 / 块通道。
  case imageEnabled
  /// LaTeX opt-in：开启 `InkLaTeXRendering.isEnabled`，演示行内 / 块级公式。
  case latexEnabled
  /// Mermaid opt-in：开启 `InkMermaidRendering.isEnabled`，演示围栏图表。
  case mermaidEnabled

  /// Segmented tab 标题。
  var displayName: String {
    switch self {
    case .standard: return "标准"
    case .brandedTheme: return "自定义主题"
    case .h1ActionCard: return "业务卡片"
    case .tableCard: return "表格卡片"
    case .imageEnabled: return "真图"
    case .latexEnabled: return "公式"
    case .mermaidEnabled: return "图表"
    }
  }

  /// 该样式的基础渲染配置（appearance / inlineSyntaxes）。
  ///
  /// 所有样式统一走块路由；Block 路由的 blockHandlers 由
  /// `RenderedListViewController.makeConfiguration()` 在此基础上叠加。
  var configuration: InkConfiguration {
    switch self {
    case .standard, .h1ActionCard, .tableCard:
      return .standard
    case .brandedTheme:
      return InkConfiguration(appearance: .demoBranded)
    case .imageEnabled:
      return InkConfiguration(appearance: .demoImageEnabled)
    case .latexEnabled:
      return .demoGeneratedContent(
        mode: .latexOnly,
        userInterfaceStyle: UITraitCollection.current.userInterfaceStyle
      )
    case .mermaidEnabled:
      return .demoGeneratedContent(
        mode: .mermaidOnly,
        userInterfaceStyle: UITraitCollection.current.userInterfaceStyle
      )
    }
  }
}

// MARK: - SSOT：公式与图表 Appearance / Configuration 工厂

extension InkAppearance {
  /// Demo 用品牌主题：放大各级标题 + 品牌蓝链接 + 浅紫代码底色。
  /// 演示业务方如何通过自定义 `InkAppearance` 整体改变视觉，而不动核心库。
  static var demoBranded: InkAppearance {
    var a = InkAppearance()
    a.heading.h1FontSize = 28
    a.heading.fontSize = 24
    a.link.color = UIColor(red: 0.12, green: 0.44, blue: 0.92, alpha: 1)
    a.codeBlock.backgroundColor = UIColor(red: 0.93, green: 0.92, blue: 1.0, alpha: 1)
    a.inlineCode.backgroundColor = UIColor(red: 0.93, green: 0.92, blue: 1.0, alpha: 1)
    return a
  }

  /// Demo 用图片 opt-in：开启真图渲染、块通道点击放大，并对演示 CDN 显式 allowlist。
  ///
  /// 这是 ExampleApp 工厂预设，**不是**库默认。库默认：`isEnabled = false`；开启后空
  /// `allowedHosts` + `.allowAll`（业务策略默认开放，ADR-006）。本 Demo 显式收窄到
  /// `placehold.co` / `picsum.photos`，用于验收固定内容与重定向链路。
  /// `onImageTap` 需在持有 presenting VC 处注入（见 ``RenderedListViewController``）。
  static var demoImageEnabled: InkAppearance {
    var a = InkAppearance()
    a.imageRendering.isEnabled = true
    a.imageRendering.promotesToBlock = true
    a.imageRendering.tapAction = .callback
    a.imageRendering.securityPolicy.allowedHosts = ["placehold.co", "picsum.photos"]
    a.imageRendering.securityPolicy.emptyHostPolicy = .rejectAll
    return a
  }

  /// Demo 用 LaTeX opt-in：默认识别 `\(...\)` / `$$...$$` / `\[...\]`。
  ///
  /// `$...$` 在 Demo 样式里默认关闭，避免与货币符号冲突；综合 Demo 若要演示风险，单独场景临时打开。
  static var demoLaTeXEnabled: InkAppearance {
    var a = InkAppearance()
    a.latexRendering.isEnabled = true
    a.latexRendering.allowsInlineDollarDelimiter = false
    return a
  }

  /// Demo 用 Mermaid opt-in：仅接管语言标记为 `mermaid` 的围栏代码块。
  static func demoMermaidEnabled(
    userInterfaceStyle: UIUserInterfaceStyle = UITraitCollection.current.userInterfaceStyle
  ) -> InkAppearance {
    var a = InkAppearance()
    a.mermaidRendering.isEnabled = true
    a.mermaidRendering.theme = userInterfaceStyle == .dark ? .dark : .light
    return a
  }

  /// 综合 / SSE：同时开启 LaTeX 与 Mermaid；`$...$` 保持关闭；Mermaid 主题跟随界面风格。
  static func demoDiagramsEnabled(
    userInterfaceStyle: UIUserInterfaceStyle,
    allowsInlineDollarDelimiter: Bool = false
  ) -> InkAppearance {
    var a = InkAppearance.demoLaTeXEnabled
    a.latexRendering.allowsInlineDollarDelimiter = allowsInlineDollarDelimiter
    a.mermaidRendering.isEnabled = true
    a.mermaidRendering.theme = userInterfaceStyle == .dark ? .dark : .light
    return a
  }
}

extension InkConfiguration {
  /// 组件开启态 / 综合 Demo / SSE 共用的公式与图表配置工厂（SSOT）。
  static func demoGeneratedContent(
    mode: DemoGeneratedContentMode,
    userInterfaceStyle: UIUserInterfaceStyle,
    allowsInlineDollarDelimiter: Bool = false
  ) -> InkConfiguration {
    let appearance: InkAppearance
    switch mode {
    case .latexOnly:
      appearance = .demoLaTeXEnabled
    case .mermaidOnly:
      appearance = .demoMermaidEnabled(userInterfaceStyle: userInterfaceStyle)
    case .diagrams:
      appearance = .demoDiagramsEnabled(
        userInterfaceStyle: userInterfaceStyle,
        allowsInlineDollarDelimiter: allowsInlineDollarDelimiter
      )
    case .disabled:
      appearance = InkAppearance()
    }
    var config = InkConfiguration(appearance: appearance)
    config.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: userInterfaceStyle)
    return config
  }
}

/// Demo 侧公式与图表配置模式。
enum DemoGeneratedContentMode {
  case latexOnly
  case mermaidOnly
  case diagrams
  case disabled
}
