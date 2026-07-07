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

    /// Segmented tab 标题。
    var displayName: String {
        switch self {
        case .standard: return "标准"
        case .brandedTheme: return "自定义主题"
        case .h1ActionCard: return "业务卡片"
        case .tableCard: return "表格卡片"
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
        }
    }
}

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
}
