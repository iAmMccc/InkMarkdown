import Foundation

/// 主列表中的一个 Section（对应 UITableView section）。
struct DemoSection {
  /// Section 标题，显示在 header。
  let title: String
  /// Section 说明，显示在 footer。
  let footer: String
  /// 本 Section 下的演示条目。
  let rows: [DemoEntry]
}

/// 单条演示入口；根据 case 决定推入 Pager 或实战场景 VC。
enum DemoEntry {
  /// 基础组件 row → ComponentPagerViewController
  case component(MarkdownComponent)
  /// 实战场景 row → 各自专属 VC
  case scenario(Scenario)
}

/// 场景类型。
enum Scenario {
  case comprehensiveReadme
  case localFile
  case serverJSON
  case sseStreaming
  case streamingPerformance
  case imageRendering
  case imageRenderingDemo
  case diagramRenderingDemo
  case swiftUIStatic
  case swiftUIConfiguration
  case swiftUIStreaming

  var title: String {
    switch self {
    case .comprehensiveReadme: return "综合长文"
    case .localFile: return "本地 .md 文件"
    case .serverJSON: return "服务端 JSON"
    case .sseStreaming: return "SSE 流式吐字"
    case .streamingPerformance: return "增量渲染性能对比"
    case .imageRendering: return "图片渲染"
    case .imageRenderingDemo: return "图片渲染 Demo"
    case .diagramRenderingDemo: return "公式与图表 Demo"
    case .swiftUIStatic: return "静态 Markdown View"
    case .swiftUIConfiguration: return "配置与 Environment"
    case .swiftUIStreaming: return "流式 Markdown View"
    }
  }

  var subtitle: String {
    switch self {
    case .comprehensiveReadme: return "README 风格混排，标准样式"
    case .localFile: return "演示 Bundle 加载路径"
    case .serverJSON: return "从 API 响应字段渲染"
    case .sseStreaming: return "对话发送，边收边逐字渲染"
    case .streamingPerformance: return "对比每片全量解析与增量解析"
    case .imageRendering: return "块级可点放大，行内图文混排演示"
    case .imageRenderingDemo: return "10 个场景：网络图、Asset、Base64、块通道等"
    case .diagramRenderingDemo: return "LaTeX 公式 + Mermaid 26 种图表类型本地渲染"
    case .swiftUIStatic: return "InkMarkdownView + 宿主 ScrollView"
    case .swiftUIConfiguration: return "显式配置与 .inkConfiguration(...)"
    case .swiftUIStreaming: return "RenderSession + InkStreamMarkdownView"
    }
  }
}
