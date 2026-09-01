# InkMarkdown

[English](README.md)

[![Swift](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Deployment](https://img.shields.io/badge/Deployment-iOS%2014.0-lightgrey.svg)](https://developer.apple.com/ios/)
[![UIKit](https://img.shields.io/badge/Framework-UIKit%20First-blue.svg)](https://developer.apple.com/documentation/uikit)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

InkMarkdown 是基于 Apple [`swift-markdown`](https://github.com/swiftlang/swift-markdown) 的 **UIKit-first** Markdown 解析与渲染库。它将 Markup 语法树转换为 iOS 原生 `NSAttributedString` 富文本与块级 `UIView` 组件，并为 AI 流式文本场景提供按帧控制的增量渲染器。

> 📌 **产品范围**：已发布的 `0.0.1` public beta 支持 UIKit 宿主；尚未发布的 `0.0.2` 分支已包含可选 `InkMarkdownSwiftUI` adapter product，使 SwiftUI 宿主复用同一套渲染语义，而不是开发第二套 native SwiftUI renderer。Manifest 将 iOS/iPadOS 14.0 声明为部署边界并排除其他 Apple 平台，但这尚不代表已交付最低系统运行支持。SwiftUI ExampleApp 已以 14.0 部署目标完成编译验证，但 iOS/iPadOS 14 运行验证、可访问性覆盖与性能基线仍是 `0.0.2` 的 release blocker。详见 [总体技术设计](docs/contributor-guide/08-swiftui-adapter-architecture.md) 与 [ADR-008](docs/decisions/ADR-008-swiftui-adapter-architecture.md)。WebView/HTML 仍不作为核心路径。

---

## 核心特性

- **双通道渲染管线**：
  - **`InkAttributedRenderer`**：将 Markdown 渲染为 `NSAttributedString`，具备锁死固定行高算法与自顶向下的上下文传递机制。
  - **`InkBlockRenderer`**：将 Markup AST 节点路由至原生 `UIView` 块级组件（涵盖表格、代码块、分割线及图片等）。
- **AI 增量流式渲染器 (`InkStreamRenderer`)**：
  - 解析-显示双缓冲架构（后台串行解析队列 + CADisplayLink 按帧吐字）。
  - 后台解析队列配合按帧显示，支持直接绑定 `UITextView` 进行差量更新；性能结论以可复现 benchmark 为准。
- **思考过程块**：
  - 以前缀 `<think>` / `<thought>` 输出的流式内容会成为可折叠原生 `InkThoughtBlock`；仅同名闭标签会结束思考过程，闭标签后的 Markdown 后缀保持原样。
- **高可扩展架构**：
  - 支持宿主自定义行内语法扩展（`InkInlineSyntax`）、块路由拦截（`InkBlockHandler`）、源文本预清洗与链接点击拦截。
  - 每次顶层渲染只在解析前执行一次源文本预清洗；Thought 正文及其尾随 Markdown 复用已预处理源码，不会再次调用 filter。
- **Opt-in 本地公式与图表支持**：
  - 支持 LaTeX 数学公式（`$...$`, `$$...$$`）与 Mermaid 图表离线渲染，生成图片由内存受控的统一图片 Store 管理。
- **SwiftUI Adapter（尚未发布的 `0.0.2`）**：
  - 通过独立 `InkMarkdownSwiftUI` product 在 SwiftUI 中托管 UIKit rendering engine，并在流式与终态 block routing 间保持同一 configuration snapshot。

---

## 环境要求

| 工具链 / 平台 | 约束要求 |
| --- | --- |
| Swift 工具链 | 6.2+ (包内采用 Swift 5 语言模式) |
| 部署范围 | Manifest 最低声明：iOS / iPadOS 14.0；尚未发布的 `0.0.2` 仍待完成最低系统运行验证 |
| UI 框架 | UIKit rendering engine；尚未发布的 `0.0.2` 提供可选 SwiftUI adapter |

---

## 安装说明

接入已发布的 `0.0.1` 时，在 Swift Package 项目的 `Package.swift` 中添加依赖：

```swift
dependencies: [
  .package(url: "https://github.com/iAmMccc/InkMarkdown.git", from: "0.0.1")
]
```

或在 Xcode 中选择 **File > Add Package Dependencies...** 引入仓库地址。

### 版本与产品边界

`0.0.1` 是已发布的 UIKit public beta。该版本的 package 只暴露 `InkMarkdown` product。本 README 中的 UIKit 核心示例只使用该 product，适用于 `0.0.1` 接入。

`0.0.2` 尚未发布。当前分支新增以下独立 product：

- `InkMarkdownSwiftUI`：托管 UIKit rendering engine 的 SwiftUI adapter。
- `InkMarkdownLaTeX`：可选 LaTeX renderer 与生成图片 loader。
- `InkMarkdownMermaid`：可选 Mermaid renderer、资源与生成图片 loader。

API 边界也按版本区分：已发布的 `0.0.1` 提供 UIKit 核心符号，包括 `InkAttributedRenderer`、`InkBlockRenderer`、`InkStreamRenderer`、`InkConfiguration` 和 `InkInlineSyntax`；尚未发布的 `0.0.2` 新增 `InkMarkdownView`、`InkStreamMarkdownView`、`InkMarkdownRenderSession`、`.inkConfiguration(...)` 以及独立 `InkMarkdownLaTeX.register()` / `InkMarkdownMermaid.register()` API。

暂时不要使用 `.package(..., from: "0.0.2")`。验证未发布分支时，应明确选择 branch 或 revision，并只加入该验证所需的 product。下方 SwiftUI 与独立 addon 章节仅适用于 `0.0.2`；依赖已发布 `0.0.1` 的 App 不要复制其中的 import。

---

## 快速上手

### 1. 富文本渲染

直接将 Markdown 字符串渲染为 `NSAttributedString`：

```swift
import InkMarkdown
import UIKit

let markdown = """
# InkMarkdown 示例

Hello **UIKit**，这是 *NSAttributedString* 文本。
"""

let attributedString = InkAttributedRenderer.render(markdown)
label.attributedText = attributedString
```

### 2. 块级视图渲染

将 Markdown 渲染为 UIKit 原生块级组件数组：

````swift
let markdown = """
| 表头 1 | 表头 2 |
| ------ | ------ |
| 内容 1 | 内容 2 |

```swift
print("Hello World")
```
"""

let blocks = InkBlockRenderer.render(markdown)
for block in blocks {
    let view = block.makeView()
    stackView.addArrangedSubview(view)
}
````

### 3. AI 流式增量渲染

绑定 SSE/WebSocket 接收到的 Markdown 分片至 `UITextView`：

```swift
let streamRenderer = InkStreamRenderer(configuration: .standard)
streamRenderer.bindTextView(textView)

// 收到 SSE 分片时追加文本
streamRenderer.append("## 流式响应标题\n")
streamRenderer.append("正在思考并生成解答内容...")

// 数据流结束
streamRenderer.finish()
```

### 4. 自定义配置与语法扩展（`0.0.1` 及以后）

配置自定义外观、行内语法拦截与链接回调：

```swift
import Foundation
import InkMarkdown
import UIKit

struct CustomMentionSyntax: InkInlineSyntax {
    private let mentionPattern = try! NSRegularExpression(pattern: #"@\w+"#)

    func render(text: String, context: InkInlineContext) -> NSAttributedString? {
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        let matches = mentionPattern.matches(in: text, range: fullRange)
        guard !matches.isEmpty else { return nil }

        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: context.baseFont,
                .foregroundColor: context.textColor,
            ]
        )
        for match in matches {
            result.addAttribute(
                .foregroundColor,
                value: UIColor.systemBlue,
                range: match.range
            )
        }
        return result
    }
}

var configuration = InkConfiguration(inlineSyntaxes: [CustomMentionSyntax()])
configuration.linkTapHandler = { url, _ in
    print("点击链接: \(url)")
    return true // 返回 true 表示 App 已拦截处理
}

let attributed = InkAttributedRenderer.render(
    "Hello @InkMarkdown",
    configuration: configuration
)
```

`InkInlineSyntax` 接收一段纯文本及其 `InkInlineContext`。扩展未命中时返回 `nil`；使用上下文中的字体和颜色，才能跟随所在段落或表格单元格的样式。

### 4.1 可选 LaTeX 与 Mermaid（仅限尚未发布的 `0.0.2`）

当前未发布分支将这些 addon 从核心 product 中拆出。加入并导入独立 product，在首次渲染前完成注册，再开启对应配置：

```swift
import InkMarkdown
import InkMarkdownLaTeX
import InkMarkdownMermaid

_ = InkMarkdownLaTeX.register()
_ = InkMarkdownMermaid.register()

var configuration = InkConfiguration.standard
configuration.enableLaTeXRendering()
configuration.appearance.mermaidRendering.isEnabled = true

let attributed = InkAttributedRenderer.render(
    "Inline formula: $x^2$",
    configuration: configuration
)
```

### 5. SwiftUI Adapter（尚未发布的 `0.0.2`）

本节仅适用于尚未发布的 `InkMarkdownSwiftUI` product。依赖已发布 `0.0.1` 的 App 无法导入此模块。

接入 SwiftUI 宿主时，请在 Xcode 中同时添加 `InkMarkdownSwiftUI` product。adapter 继续复用 UIKit rendering engine；滚动和网络 transport 仍由宿主负责：

```swift
import SwiftUI
import InkMarkdown
import InkMarkdownSwiftUI

struct MarkdownScreen: View {
    // 由本地持有 session；promotion 状态驱动 adapter 换树。
    @StateObject private var session = InkMarkdownRenderSession()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                InkMarkdownView("# SwiftUI 示例")
                InkStreamMarkdownView(session: session)
            }
        }
    }
}
```

配置既可以显式传给视图，也可以注入一整棵子树：

```swift
var configuration = InkConfiguration.standard
configuration.appearance.text.fontSize = 18

InkMarkdownView(markdown)
    .inkConfiguration(configuration)
```

流式场景由宿主把收到的 delta 交给 `session.append(_:)`，并在适当时调用 `finish()`、`cancel()` 或 `reset()`。六个对称 adapter 示例的入口和说明见 [SwiftUI ExampleApp 指南](docs/contributor-guide/10-swiftui-example-app.md)。

---

## 语法支持与限制矩阵

| Markdown 语法 | 实现状态 | 产物类型 |
| --- | --- | --- |
| 标题 (H1–H6) | 已支持 | `NSAttributedString` |
| 段落与强调 (加粗/斜体) | 已支持 | `NSAttributedString` |
| 行内代码 | 已支持 | `NSAttributedString` |
| 链接与点击拦截 | 已支持 | `NSAttributedString` + `linkTapHandler` |
| 有序 / 无序列表 | 已支持 | `NSAttributedString` |
| 引用块 | 已支持 | `NSAttributedString` |
| 代码块 | 已支持 | `NSAttributedString` / `InkCodeBlock` 生成的代码块 `UIView` |
| 表格 | 已支持 | `InkTableBlock` 生成的表格 `UIView`（须使用 `InkBlockRenderer`） |
| 分割线 | 已支持 | `InkThematicBreakBlock` 生成的分割线 `UIView` |
| 行内公式 (`$...$`) | 已支持 (Opt-in) | `InkImageAttachment` |
| 块级公式 (`$$...$$`) | 已支持 (Opt-in) | 生成的 `InkImageBlock`（须使用 `InkBlockRenderer`） |
| Mermaid 图表 | 已支持 (Opt-in) | 生成的 `InkImageBlock`（须使用 `InkBlockRenderer`） |
| 图片 | 已支持 (Opt-in) | 默认占位文本；开启后行内图片为 `InkImageAttachment`，独占块为 `InkImageBlock` |
| 思考过程 (`<think>` / `<thought>`) | 已支持 | `InkBlockRenderer` 输出可折叠 `InkThoughtBlock`；支持流式前缀 |

> ℹ️ **说明**：关于完整渲染行为细节与边界边缘情况，请参阅[当前项目状态](docs/current-status.md)与[渲染语义规范](docs/spec/README.md)。

> 版本说明：已发布的 `0.0.1` 将 LaTeX 与 Mermaid 能力包含在单一 `InkMarkdown` product 中；尚未发布的 `0.0.2` 才需要使用上方独立 product 与注册流程。

---

## 项目结构

```text
InkMarkdown/
├── Sources/InkMarkdown/
│   ├── Configuration/       # InkConfiguration, InkAppearance 与 RenderEnvironment
│   ├── Parser/              # InkParser (swift-markdown AST 薄封装)
│   └── Rendering/
│       ├── AttributedString/# InkAttributedRenderer (TextKit 富文本管线)
│       ├── Block/           # InkBlockRenderer 与 InkBlockHandler 路由
│       ├── Components/      # 原生 UIKit 视图组件 (表格, 代码块, 分割线)
│       ├── Image/           # 图片 Store、下载器与 Attachment 处理器
│       ├── LaTeX/           # LaTeX 公式图片生成器与 Handler
│       ├── Mermaid/         # Mermaid 图表生成器与 Handler
│       └── InkStreamRenderer.swift # CADisplayLink 双缓冲流式渲染器
├── Sources/InkMarkdownSwiftUI/ # 尚未发布的 v0.0.2 SwiftUI adapter target
├── Tests/InkMarkdownTests/   # 单元测试、快照测试与流式性能测试
├── ExampleApp/               # UIKit + SwiftUI 示例程序 (包含流式与组件演示)
└── docs/                     # 架构决策 (ADR)、语义规范与开发指南
```

---

## 构建与测试

InkMarkdown 源码直接引用 `UIKit`，因此在 macOS 主机环境直接执行 `swift build` 或 `swift test` 会提示 `no such module 'UIKit'`。测试必须运行在 **iOS Simulator** 环境下。

### 运行测试

推荐使用 [XcodeBuildMCP](https://www.xcodebuildmcp.com/) 或指定模拟器的 `xcodebuild` 命令运行测试：

```bash
xcodebuild test \
  -scheme InkMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```

### 打开 ExampleApp 示例工程

```bash
open ExampleApp/ExampleApp.xcodeproj
```

---

## 文档索引

- 📖 [文档中心入口](docs/README.md)
- 📊 [当前交付状态](docs/current-status.md)
- 🏗️ [架构设计原理](docs/contributor-guide/02-architecture.md)
- 🧩 [SwiftUI Adapter 总体技术设计](docs/contributor-guide/08-swiftui-adapter-architecture.md)
- 📐 [渲染语义规范](docs/spec/README.md)
- 🛣️ [路线图 Roadmap](docs/roadmap.md)
- 📝 [架构决策记录 (ADR)](docs/decisions/README.md)
- 🆘 [支持说明](SUPPORT.md)
- 🤝 [行为准则](CODE_OF_CONDUCT.md)

---

## 贡献指南

欢迎参与 InkMarkdown 贡献！提交 Pull Request 或 Issue 前请阅读[开源贡献指南](CONTRIBUTING.md)、[支持说明](SUPPORT.md)、[行为准则](CODE_OF_CONDUCT.md)和[开发者指南](docs/contributor-guide/README.md)。

---

## 开源协议

本项目基于 [MIT 协议](LICENSE) 开源。
