# InkMarkdown

[English](README.md)

[![Swift](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2014+-lightgrey.svg)](https://developer.apple.com/ios/)
[![UIKit](https://img.shields.io/badge/Framework-UIKit%20Only-blue.svg)](https://developer.apple.com/documentation/uikit)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

InkMarkdown 是基于 Apple [`swift-markdown`](https://github.com/swiftlang/swift-markdown) 的 **UIKit 专用** Markdown 解析与渲染库。它将 Markup 语法树转换为 iOS 原生 `NSAttributedString` 富文本与块级 `UIView` 组件，并为 AI 流式文本场景提供按帧控制的增量渲染器。

> 📌 **UIKit 定位说明**：InkMarkdown 专为 UIKit 宿主设计，旨在填补已有 Apple Markdown 库对 UIKit 原生视图支持的空白。项目明确不提供 SwiftUI 渲染器（SwiftUI 场景建议使用 MarkdownUI 或 Textual），也不以 WebView/HTML 作为核心路径。

---

## 核心特性

- **双通道渲染管线**：
  - **`InkAttributedRenderer`**：将 Markdown 渲染为 `NSAttributedString`，具备锁死固定行高算法与自顶向下的上下文传递机制。
  - **`InkBlockRenderer`**：将 Markup AST 节点路由至原生 `UIView` 块级组件（涵盖表格、代码块、分割线及图片等）。
- **AI 增量流式渲染器 (`InkStreamRenderer`)**：
  - 解析-显示双缓冲架构（后台串行解析队列 + CADisplayLink 按帧吐字）。
  - 渲染流畅无卡顿，不占用主线程解析，支持直接绑定 `UITextView` 进行差量更新。
- **高可扩展架构**：
  - 支持宿主自定义行内语法扩展（`InkInlineSyntax`）、块路由拦截（`InkBlockHandler`）、源文本预清洗与链接点击拦截。
- **Opt-in 本地公式与图表支持**：
  - 支持 LaTeX 数学公式（`$...$`, `$$...$$`）与 Mermaid 图表离线渲染，生成图片由内存受控的统一图片 Store 管理。

---

## 环境要求

| 工具链 / 平台 | 约束要求 |
| --- | --- |
| Swift 工具链 | 6.2+ (包内采用 Swift 5 语言模式) |
| 目标平台 | iOS 14.0+ |
| UI 框架 | UIKit (无 SwiftUI 依赖) |

---

## 安装说明

在 Swift Package 项目的 `Package.swift` 中添加依赖：

```swift
dependencies: [
  .package(url: "https://github.com/iAmMccc/InkMarkdown.git", branch: "main")
]
```

或在 Xcode 中选择 **File > Add Package Dependencies...** 引入仓库地址。

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

```swift
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
```

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

### 4. 自定义配置与语法扩展

配置自定义外观、行内语法拦截与链接回调：

```swift
struct CustomMentionSyntax: InkInlineSyntax {
    let pattern = #"@(\w+)"#
    func match(in text: String) -> [NSRange] { /* 正则匹配逻辑 */ }
    func apply(to attributedString: NSMutableAttributedString, range: NSRange, context: InkTextContext) {
        attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
    }
}

var config = InkConfiguration(
    inlineSyntaxes: [CustomMentionSyntax()],
    linkTapHandler: { url, hostView in
        print("点击链接: \(url)")
        return true // 返回 true 表示 App 已拦截处理
    }
)

// 开启 Opt-in 本地 LaTeX 与 Mermaid 渲染支持
config.enableLaTeXRendering()
config.appearance.mermaidRendering.isEnabled = true

let attributed = InkAttributedRenderer.render(markdown, configuration: config)
```

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
| 代码块 | 已支持 | `NSAttributedString` / `InkCodeBlockView` |
| 表格 | 已支持 | `InkTableView`（须使用 `InkBlockRenderer`） |
| 分割线 | 已支持 | `InkThematicBreakView` |
| 行内公式 (`$...$`) | 已支持 (Opt-in) | `InkImageAttachment` |
| 块级公式 (`$$...$$`) | 已支持 (Opt-in) | `InkLaTeXBlockView`（须使用 `InkBlockRenderer`） |
| Mermaid 图表 | 已支持 (Opt-in) | `InkMermaidBlockView`（须使用 `InkBlockRenderer`） |
| 图片 | 已支持 (Opt-in) | 默认占位文本；开启后输出 `InkImageBlockView` |

> ℹ️ **说明**：关于完整渲染行为细节与边界边缘情况，请参阅[当前项目状态](docs/current-status.md)与[渲染语义规范](docs/spec/README.md)。

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
├── Tests/InkMarkdownTests/   # 单元测试、快照测试与流式性能测试
├── ExampleApp/               # UIKit 示例程序 (包含 SSE 流式与组件演示)
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
- 📐 [渲染语义规范](docs/spec/README.md)
- 🛣️ [路线图 Roadmap](docs/roadmap.md)
- 📝 [架构决策记录 (ADR)](docs/decisions/README.md)

---

## 贡献指南

欢迎参与 InkMarkdown 贡献！提交 Pull Request 或 Issue 前请阅读 [开源贡献指南](CONTRIBUTING.md) 和 [开发者指南](docs/contributor-guide/README.md)。

---

## 开源协议

本项目基于 [MIT 协议](LICENSE) 开源。
