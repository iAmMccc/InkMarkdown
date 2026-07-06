import UIKit
import InkMarkdown

/// ExampleApp 侧的「样式 tab」枚举——**演示如何用核心扩展点做业务定制**。
///
/// 重构后核心库只内置「标准 Markdown + 标准样式」，不含任何预设配方。业务定制一律走
/// 三个扩展点，本枚举每个 case 对应其中一种用法：
/// - ``brandedTheme``：自定义 `InkTheme`（覆盖字号 / 颜色）。
/// - ``tagInline``：注册 `InkInlineSyntax` 行内语法插件（`$标签$`）。
/// - ``h1ActionCard``：Block 路由，把整块标题替换成自定义 UIView。
enum DemoStyle {
    /// 标准样式（核心内置，开箱即用）。
    case standard
    /// 自定义主题：放大标题 + 品牌色链接，演示 `InkTheme` 覆盖。
    case brandedTheme
    /// 行内标签语法：`$标签$` 渲染为可点击胶囊，演示 `InkInlineSyntax`。
    case tagInline
    /// 业务卡片：H1 替换成浅紫圆角卡片，演示 Block 路由。
    case h1ActionCard
    /// 表格卡片：Markdown 表格替换成原生 UIView 表格，演示 Table Block 路由。
    case tableCard

    /// Segmented tab 标题。
    var displayName: String {
        switch self {
        case .standard: return "标准"
        case .brandedTheme: return "自定义主题"
        case .tagInline: return "行内标签语法"
        case .h1ActionCard: return "业务卡片"
        case .tableCard: return "表格卡片"
        }
    }

    /// 是否走 Block 路由（独立 UIView 替换整块）。
    var usesBlockRouting: Bool { self == .h1ActionCard || self == .tableCard }

    /// 该样式对应的渲染配置（非 Block 路由路径使用）。
    var configuration: InkConfiguration {
        switch self {
        case .standard, .h1ActionCard, .tableCard:
            return .standard
        case .brandedTheme:
            return InkConfiguration(appearance: .demoBranded)
        case .tagInline:
            return InkConfiguration(inlineSyntaxes: [TagInlineSyntax()])
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
