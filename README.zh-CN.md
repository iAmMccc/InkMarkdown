# InkMarkdown

[English](README.md)

InkMarkdown 是基于 Apple
[swift-markdown](https://github.com/swiftlang/swift-markdown) 的 **UIKit 专用**
Markdown 渲染库。它把 Markup 树转换为 `NSAttributedString` 和原生块级
`UIView`，并为 AI 对话等场景提供增量流式渲染。

InkMarkdown 明确不提供 SwiftUI 渲染器。MarkdownUI 与 Textual 已覆盖该生态；
本项目专注 UIKit 宿主，也不以 WebView / HTML 作为主路径。

项目不替代 `swift-markdown` 的解析，而是消费 Markup 树并转为原生 UI：

- `NSAttributedString` 富文本。
- 用于表格、代码块和分割线的块级 `UIView`。
- 面向流式 Markdown 的增量渲染。
- 自定义行内语法、块级组件路由、源清洗过滤、外观设计和链接点击等自定义扩展点。

## 为什么需要 InkMarkdown

| 库类型 | 通常提供 | InkMarkdown 的不同 |
| --- | --- | --- |
| `swift-markdown` | 解析 + Markup AST | 在 AST 之上补 UIKit 原生**渲染层**。 |
| MarkdownUI / Textual | 成熟的 **SwiftUI** 渲染 | 专注 UIKit，不重复其 SwiftUI 范围。 |
| Microsoft SwiftStreamingMarkdown | 流式 + 偏 SwiftUI 的产品能力 | 原生栈 + **块路由**、固定行高、宿主自定义可插拔扩展——先服务可嵌入的 UIKit App。 |
| HTML / WebView 渲染 | HTML 或内嵌网页 | 核心内容走原生文本与视图，不依赖 WebView。 |
| 简单富文本助手 | 行内富文本 | 另有块路由（表格/代码）、流式与自定义扩展点。 |

## 要求

- Swift 6.2+
- iOS 14+（当前 Package 声明）

## 安装

```swift
.package(url: "https://github.com/iAmMccc/InkMarkdown.git", branch: "main")
```

## 使用

渲染为 `NSAttributedString`：

```swift
import InkMarkdown

let markdown = """
# Title

Hello **InkMarkdown**.
"""

let attributed = InkAttributedRenderer.render(markdown)
```

渲染为 UIKit 块级组件：

```swift
let blocks = InkBlockRenderer.render(markdown)
let views = blocks.map { $0.makeView() }
```

流式渲染（AI 对话类）：

```swift
let renderer = InkStreamRenderer()
renderer.bindTextView(textView)
renderer.append("## Streaming title\n")
renderer.append("Markdown content can keep growing.")
renderer.finish()
```

自定义：

```swift
let configuration = InkConfiguration(
  inlineSyntaxes: [MyInlineSyntax()],
  linkTapHandler: { url, view in
    // App 自行处理链接时返回 true。
    false
  }
)

let attributed = InkAttributedRenderer.render(markdown, configuration: configuration)
```

## 当前 Markdown 支持情况

| 能力 | 状态 |
| --- | --- |
| 标题 | 已支持 |
| 段落 | 已支持 |
| 加粗 / 斜体 | 已支持 |
| 行内代码 | 已支持 |
| 链接 | 已支持 |
| 图片 | 文本降级 |
| 固定行高 | 已支持 |
| 有序 / 无序列表 | 已支持 |
| 引用块 | 已支持 |
| 代码块 | 富文本 + UIKit 块 |
| 表格 | UIKit 块 |
| 分割线 | 已支持 |
| 自定义行内语法 | 已支持 |
| 链接点击回调 | 已支持 |
| 流式 Markdown | 已支持 |
| SwiftUI 渲染器 | 不支持（不在项目范围内） |

表格必须使用 `InkBlockRenderer`；纯富文本路径不提供网格布局。图片当前使用文本
降级，删除线会保留内容但尚未应用删除线样式。完整限制见
[当前状态](docs/current-status.md)。

## 文档

- [文档索引](docs/README.md)
- [当前实现状态](docs/current-status.md)
- [贡献者指南](docs/contributor-guide/README.md)
- [渲染语义规范](docs/spec/README.md)
- [路线图](docs/roadmap.md)

## 项目结构

```text
Sources/InkMarkdown/       库源码
Tests/InkMarkdownTests/    单元测试
ExampleApp/                UIKit 示例 App
docs/                      架构、规范、路线图
```

## 构建与测试

InkMarkdown 直接依赖 UIKit，因此在 macOS host 上执行 `swift build` / `swift test`
会报 `no such module 'UIKit'`。测试必须选择 iOS Simulator。

优先使用 [XcodeBuildMCP](https://www.xcodebuildmcp.com/) 发现工程、选择
`InkMarkdown` scheme 和可用 simulator，再运行测试。如果当前 MCP 客户端没有暴露
SwiftPM package test workflow，按[开发指南](docs/contributor-guide/04-development.md#回退到原生-xcodebuild)
使用原生命令回退。

最近验证记录：2026-07-13，`InkMarkdown` scheme，iPhone 17 Pro / iOS 26.5，
32 项通过，0 项失败。

```bash
open ExampleApp/ExampleApp.xcodeproj
```

## 贡献

请先阅读[贡献者指南](docs/contributor-guide/README.md)。公开行为变更应同时补充
测试与对应文档。

## License

见 [LICENSE](LICENSE)。
