# InkMarkdown

[English](README.md)

InkMarkdown 是一个基于 Apple
[swift-markdown](https://github.com/swiftlang/swift-markdown) 的 Markdown 渲染库，目前只支持 UIKit。

项目不尝试替代 `swift-markdown` 的解析能力，而是复用它产出的 Markup 树，并将其转换为 UIKit 原生输出：

- 用于文本渲染的 `NSAttributedString`。
- 用于复杂内容的 UIKit 块级组件。
- 用于 AI 对话等场景的流式 Markdown 渲染。

## 为什么需要 InkMarkdown

多数现代 Swift Markdown 库主要面向 SwiftUI、解析层或 HTML 输出。InkMarkdown 聚焦 UIKit 场景的空缺：

| 库类型 | 通常提供什么 | InkMarkdown 的不同点 |
| --- | --- | --- |
| `swift-markdown` | CommonMark 解析和 Markup AST | InkMarkdown 在 AST 之上补 UIKit 渲染层。 |
| MarkdownUI / Textual | SwiftUI Markdown 渲染 | InkMarkdown 目前只支持 UIKit。 |
| HTML / WebView 渲染器 | HTML 输出或 WebView 展示 | InkMarkdown 渲染原生 UIKit 视图和富文本。 |
| 简单富文本 Markdown 库 | 行内富文本 | InkMarkdown 还支持块级路由、表格、代码块和流式输出。 |

## 要求

- Swift 6.2+
- iOS 14+

## 安装

通过 Swift Package Manager 引入：

```swift
.package(url: "https://github.com/<owner>/InkMarkdown.git", branch: "main")
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

用于 AI 对话类场景的流式渲染：

```swift
let renderer = InkStreamRenderer()
renderer.bindTextView(textView)
renderer.append("## Streaming title\n")
renderer.append("Markdown content can keep growing.")
renderer.finish()
```

自定义渲染：

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
| 图片 | 已支持文本降级 |
| 固定行高 | 已支持 |
| 有序 / 无序列表 | 已支持 |
| 引用块 | 已支持 |
| 代码块 | 支持富文本和 UIKit 块级组件 |
| 表格 | 支持 UIKit 块级组件 |
| 分割线 | 已支持 |
| 自定义行内语法 | 已支持 |
| 链接点击回调 | 已支持 |
| 流式 Markdown | 已支持 |
| SwiftUI 渲染器 | 不支持 |

## 项目结构

```text
Sources/InkMarkdown/       库源码
Tests/InkMarkdownTests/    单元测试
ExampleApp/                UIKit 示例 App
```

## 构建与测试

```bash
swift build
swift test
```

打开示例 App：

```bash
open ExampleApp/ExampleApp.xcodeproj
```

## License

见 [LICENSE](LICENSE)。
