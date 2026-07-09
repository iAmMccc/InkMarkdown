# InkMarkdown

[English](README.md)

InkMarkdown 是基于 Apple
[swift-markdown](https://github.com/swiftlang/swift-markdown) 的 Markdown 渲染库。

**定位：** Apple 平台原生 Markdown 渲染，管线可插拔（解析 → 变换 → 渲染）。
**当前交付 UIKit；SwiftUI 在路线图中**（同一中间模型、独立后端）。不以
WebView / HTML 作为主路径。

项目不替代 `swift-markdown` 的解析，而是消费 Markup 树并转为原生 UI：

- **当前（UIKit）：** `NSAttributedString`、块级 `UIView`、面向 AI 对话的流式渲染。
- **规划（SwiftUI）：** 在同一管线 / IR 上增加 SwiftUI 后端；不要求纯 UIKit 宿主为
  核心路径强依赖 SwiftUI。

## 为什么需要 InkMarkdown

| 库类型 | 通常提供 | InkMarkdown 的不同 |
| --- | --- | --- |
| `swift-markdown` | 解析 + Markup AST | 在 AST 之上补原生**渲染层**，并规划可变换的 IR。 |
| MarkdownUI / Textual | 成熟的 **SwiftUI** 渲染 | **UIKit 优先**；SwiftUI 作为**第二后端**，不照搬其 API。 |
| Microsoft SwiftStreamingMarkdown | 流式 + 偏 SwiftUI 的产品能力 | 原生栈 + **块路由**、固定行高、宿主可插拔扩展——先服务可嵌入的 UIKit App。 |
| HTML / WebView 渲染 | HTML 或内嵌网页 | 核心内容走原生文本与视图，不依赖 WebView。 |
| 简单富文本助手 | 行内富文本 | 另有块路由（表格/代码）、流式与扩展点。 |

## 要求

- Swift 6.2+
- iOS 14+（当前 Package 声明）

## 安装

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
| SwiftUI 渲染器 | 路线图（未交付） |

## 项目结构

```text
Sources/InkMarkdown/       库源码
Tests/InkMarkdownTests/    单元测试
ExampleApp/                UIKit 示例 App
docs/                      架构、规范、路线图
```

## 构建与测试

```bash
swift build
swift test
```

```bash
open ExampleApp/ExampleApp.xcodeproj
```

## License

见 [LICENSE](LICENSE)。
