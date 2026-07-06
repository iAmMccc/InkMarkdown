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

  var title: String {
    switch self {
    case .comprehensiveReadme: return "综合长文"
    case .localFile: return "本地 .md 文件"
    case .serverJSON: return "服务端 JSON"
    case .sseStreaming: return "SSE 流式吐字"
    }
  }

  var subtitle: String {
    switch self {
    case .comprehensiveReadme: return "README 风格混排，标准样式"
    case .localFile: return "演示 Bundle 加载路径"
    case .serverJSON: return "从 API 响应字段渲染"
    case .sseStreaming: return "对话发送，边收边逐字渲染"
    }
  }
}
