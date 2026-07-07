# InkMarkdown

InkMarkdown 是基于 Apple [swift-markdown](https://github.com/swiftlang/swift-markdown) 的 UIKit Markdown 渲染库。它把 Markdown 的 Markup 树渲染为 `NSAttributedString` 和 UIKit 视图组件，面向不使用 SwiftUI 的 iOS 场景。

## 特性

- UIKit only，不引入 SwiftUI。
- 支持 `NSAttributedString` 富文本渲染。
- 支持代码块、表格、分割线等块级 UIKit 组件。
- 支持主题配置、块级路由和链接点击回调。
- 示例 App 展示普通渲染、组件渲染和流式渲染场景。

## 要求

- Swift 6.2+
- iOS 14+

## 安装

通过 Swift Package Manager 引入：

```swift
.package(url: "https://github.com/<owner>/InkMarkdown.git", branch: "main")
```

本仓库当前依赖 `swift-markdown`：

```swift
.package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main")
```

## 使用

```swift
import InkMarkdown

let markdown = """
# Title

Hello **InkMarkdown**.
"""

let attributed = InkAttributedRenderer.render(markdown)
```

块级组件渲染：

```swift
let blocks = InkBlockRenderer.render(markdown)
let views = blocks.map { $0.makeView() }
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

## 项目结构

```text
Sources/InkMarkdown/       库源码
Tests/InkMarkdownTests/    单元测试
ExampleApp/                UIKit 示例 App
```

## 定位

InkMarkdown 不做 SwiftUI 封装。SwiftUI 场景已有 MarkdownUI / Textual 等方案，本项目专注 UIKit 和 `NSAttributedString`。
