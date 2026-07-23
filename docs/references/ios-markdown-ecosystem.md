# iOS Markdown 库定位对比

对比 swift-markdown、MarkdownUI、Textual、SwiftStreamingMarkdown 与 InkMarkdown 的设计选型与技术边界，供架构选型与源码阅读参考。

> 核对日期：2026-07-14。信息基于各项目开源代码与官方文档。

## 评估维度

评估 Markdown 渲染库时，需明确以下技术细节：

1. 职责边界：专注于 AST 解析，还是包含 UI 渲染？
2. 数据模型：解析后生成的中间数据结构形态。
3. 输出接口：对宿主公开的是 SwiftUI `View`、`NSAttributedString`、`UIView` 还是其他类型？
4. 扩展机制：样式配置与自定义复杂块的扩展方式。
5. 流式支持：是否原生支持 LLM 增量流式渲染。

## 对比表

注：“公开边界”指宿主代码直接调用的主要类型，非库内部实现细节。

| 库 | 主要职责 | 中间模型 | 公开显示边界 | 流式定位 |
| --- | --- | --- | --- | --- |
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | 解析、构建、遍历和改写 Markdown | `Document` / `Markup` 树 | 不提供 UI 渲染器 | 未把增量 UI 流式作为公开职责 |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | 在 SwiftUI 中显示和定制 GFM | `MarkdownContent` 与块序列 | 只读 SwiftUI `Markdown` view | 常规内容渲染，非专用流式管线 |
| [Textual](https://github.com/gonzalezreal/textual) | SwiftUI 富文本引擎，Markdown 是支持的标记之一 | 带 `PresentationIntent` 的 Swift `AttributedString` | `InlineText` / `StructuredText` SwiftUI view | 未将 LLM 流式作为主要 API |
| [SwiftStreamingMarkdown](https://github.com/microsoft/SwiftStreamingMarkdown) | 针对 LLM 响应的高性能流式渲染 | `RenderableDocument` 等内部渲染模型 | SwiftUI 入口；段落内部使用 `UITextView` | 以 `StreamedMarkdownSource` / `StreamedMarkdownView` 为核心功能 |
| InkMarkdown | UIKit Markdown 解析适配与渲染 | swift-markdown `Markup` | `NSAttributedString` / `InkRenderableBlock` / `UIView` | `InkStreamRenderer` 管理稳定前缀、活跃后缀与逐帧渲染 |

## swift-markdown：AST 结构层

基于 cmark-gfm，将字符串解析为不可变、线程安全、写时复制的 `Markup` 树。提供三类遍历操作：

- `MarkupVisitor`：遍历并返回自定义结果。
- `MarkupWalker`：遍历并累加状态（如提取链接）。
- `MarkupRewriter`：返回修改后的 AST 树（返回 `nil` 可删除节点）。

只负责语法树解析与操作，不涉及样式、排版与视图渲染。InkMarkdown 直接使用其作为解析层。

## MarkdownUI：SwiftUI 渲染库

输出视图为只读 SwiftUI `View`。支持标题、列表、引用、代码块、表格等 GFM 元素，样式与块样式解耦配置。

主要扩展点包含 `Theme`、`markdownTextStyle`、`markdownBlockStyle` 以及 `CodeSyntaxHighlighter`。由于输出为 SwiftUI `View`，无法直接向 UIKit 导出 `NSAttributedString` 或 `UIView`。

## Textual：富文本引擎

定位为通用 SwiftUI 文本渲染引擎，将 Markdown 作为一种输入格式。基于 Foundation `AttributedString` 的解析能力，通过 `MarkupParser` 转换为带有 `PresentationIntent` 的富文本。

通过 `InlineText` 处理行内元素，`StructuredText` 处理块级元素，配合 `TextProperty` 与 `InlineStyle` 实现组合样式。

## SwiftStreamingMarkdown：流式渲染

面向 LLM 增量生成场景，对外提供 `StreamedMarkdownView` 接收 `StreamedMarkdownSource` 产生的文本快照。支持常见 CommonMark/GFM 规范、表格、代码块及数学公式。

UI 入口基于 SwiftUI，内部段落使用 `UITextView` 渲染。说明“内部实现使用 UIKit”不等于“向宿主公开富文本与块路由接口”。

## InkMarkdown 技术定位

InkMarkdown 的设计核心：

1. 基于 swift-markdown 维护结构化 AST。
2. 原生面向 UIKit 宿主，直接导出 `NSAttributedString` 与可构建 `UIView` 的块数据。
3. 将表格、代码块、分割线等非纯文本元素解耦至 block handler 自定义渲染。

选型时需结合宿主环境（UIKit / SwiftUI）、所需的公开接口形态、块级交互诉求及流式渲染场景综合评估。

## 参考来源

上游官方文档：

- [swift-markdown：Parsing, Building, and Modifying Markup Trees](https://github.com/swiftlang/swift-markdown/blob/main/Sources/Markdown/Markdown.docc/Parsing-Building-and-Modifying%20Markup-Trees.md)
- [swift-markdown：Visitors, Walkers, and Rewriters](https://github.com/swiftlang/swift-markdown/blob/main/Sources/Markdown/Markdown.docc/Visitors-Walkers-and-Rewriters.md)
- [MarkdownUI README](https://github.com/gonzalezreal/swift-markdown-ui/blob/main/README.md)
- [MarkdownUI `Markdown` view](https://github.com/gonzalezreal/swift-markdown-ui/blob/main/Sources/MarkdownUI/Views/Markdown.swift)
- [Textual README](https://github.com/gonzalezreal/textual/blob/main/README.md)
- [Textual System Overview](https://github.com/gonzalezreal/textual/blob/main/Contributor%20Documentation/System%20Overview.md)
- [SwiftStreamingMarkdown README](https://github.com/microsoft/SwiftStreamingMarkdown/blob/main/README.md)

注：本文档未对 `johnxnguyen/Down` 进行对比。

## 维护规则

当外部库的公开 UI 接口、解析依赖或流式 API 变更时，请同步更新本文档，并复查[项目概述](../contributor-guide/01-overview.md)。
