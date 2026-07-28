import Foundation

/// 第一层分类入口。
enum DemoCategory: CaseIterable {
  case markdownStandard
  case customComponent
  case streaming
  case integration

  var title: String {
    switch self {
    case .markdownStandard: return "Markdown 标准样式"
    case .customComponent: return "自定义样式"
    case .streaming: return "流式渲染"
    case .integration: return "集成测试"
    }
  }

  var subtitle: String {
    switch self {
    case .markdownStandard: return "标准 Markdown 语法的默认渲染效果"
    case .customComponent: return "表格等业务自定义组件"
    case .streaming: return "SSE 逐字吐字渲染"
    case .integration: return "综合长文、本地文件、服务端 JSON"
    }
  }
}

/// 第二层列表数据源。
enum DemoCatalog {

  // MARK: - Markdown 标准样式

  static func markdownStandardSections() -> [DemoSection] {
    [
      DemoSection(
        title: "结构组件",
        footer: "决定文档骨架的块级组件。",
        rows: MarkdownComponent.structuralComponents.map { .component($0) }
      ),
      DemoSection(
        title: "内容元素",
        footer: "嵌在结构内的行内组件。",
        rows: MarkdownComponent.inlineComponents.map { .component($0) }
      ),
    ]
  }

  // MARK: - 自定义样式

  static func customComponentSections() -> [DemoSection] {
    [
      DemoSection(
        title: "自定义组件",
        footer: "通过 Block 路由或独立组件实现的业务定制样式。",
        rows: [
          .component(.table),
        ]
      ),
      DemoSection(
        title: "图片渲染",
        footer: "网络图、本地 Asset、Base64、块通道、行内混排、全屏预览等场景。",
        rows: [
          .scenario(.imageRenderingDemo),
        ]
      ),
    ]
  }

  // MARK: - 流式渲染

  static func streamingSections() -> [DemoSection] {
    [
      DemoSection(
        title: "流式渲染",
        footer: "模拟 AI 对话场景的实时渲染。",
        rows: [
          .scenario(.sseStreaming),
          .scenario(.streamingPerformance),
        ]
      ),
    ]
  }

  // MARK: - 集成测试

  static func integrationSections() -> [DemoSection] {
    [
      DemoSection(
        title: "集成场景",
        footer: "常见接入路径验证。",
        rows: [
          .scenario(.comprehensiveReadme),
          .scenario(.localFile),
          .scenario(.serverJSON),
        ]
      ),
    ]
  }
}
