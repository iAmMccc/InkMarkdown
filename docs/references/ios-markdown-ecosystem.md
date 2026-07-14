# iOS Markdown 库定位对比

本页是 Reference，用统一问题对比 swift-markdown、MarkdownUI、Textual、SwiftStreamingMarkdown 与 InkMarkdown。它用于架构选型和源码阅读，不做综合排名。

> 核对日期：2026-07-14。外部库信息使用 Context7 的当前仓库文档索引核对，每个结论仍以链接的上游仓库为最终来源。

## 先问五个问题

看到一个 Markdown 库时，先确认它处理管线的哪一段。

1. 它负责解析，还是负责显示？
2. 解析后的中间数据是什么？
3. 对宿主公开的输出是 SwiftUI `View`、`NSAttributedString`、`UIView`，还是其他类型？
4. 样式和复杂块如何扩展？
5. 流式是首要能力，还是调用方每次传入完整文本？

## 对比表

表中的“公开边界”指应用代码直接使用的主要类型，不是库内部是否偶尔调用 UIKit。

| 库 | 主要职责 | 中间模型 | 公开显示边界 | 流式定位 |
| --- | --- | --- | --- | --- |
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | 解析、构建、遍历和改写 Markdown | `Document` / `Markup` 树 | 不提供 UI 渲染器 | 未把增量 UI 流式作为公开职责 |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | 在 SwiftUI 中显示和定制 GFM | `MarkdownContent` 与块序列 | 只读 SwiftUI `Markdown` view | 常规内容渲染，非专用流式管线 |
| [Textual](https://github.com/gonzalezreal/textual) | SwiftUI 富文本引擎，Markdown 是支持的标记之一 | 带 `PresentationIntent` 的 Swift `AttributedString` | `InlineText` / `StructuredText` SwiftUI view | 文档未把 LLM 流式作为主入口 |
| [SwiftStreamingMarkdown](https://github.com/microsoft/SwiftStreamingMarkdown) | 针对 LLM 响应的高性能流式渲染 | `RenderableDocument` 等内部渲染模型 | SwiftUI 入口；段落内部使用 `UITextView` | `StreamedMarkdownSource` / `StreamedMarkdownView` 是主要能力 |
| InkMarkdown | UIKit Markdown 解析适配与渲染 | swift-markdown `Markup` | `NSAttributedString` / `InkRenderableBlock` / `UIView` | `InkStreamRenderer` 管理稳定前缀、活跃后缀和逐帧显示 |

## swift-markdown：只解决结构

swift-markdown 基于 cmark-gfm，把字符串解析为不可变、线程安全、写时复制的 `Markup` 值树。它提供三类树操作：

- `MarkupVisitor`：遍历后返回自定义结果。
- `MarkupWalker`：遍历并累计状态，例如统计链接。
- `MarkupRewriter`：返回改写后的新树，返回 `nil` 可删除节点。

它不决定字号、行高、UIKit 视图或交互。InkMarkdown 使用它做解析层，不重写 CommonMark 解析。

## MarkdownUI：SwiftUI Markdown 渲染器

MarkdownUI 的公开 `Markdown` 类型是只读 SwiftUI view。它支持图片、标题、列表、引用、代码块、表格和分割线，并把行内样式与块样式分开定制。

主要扩展边界是 `Theme`、`markdownTextStyle`、`markdownBlockStyle` 和 `CodeSyntaxHighlighter`。这些 API 的思路可用于学习样式分层，但输出仍是 SwiftUI view，不是 UIKit `NSAttributedString` 或 `UIView` 路由。

## Textual：文本引擎优先

Textual 将自己定位为 SwiftUI 文本渲染引擎，Markdown 只是一种输入。它使用 Foundation `AttributedString` 的 Markdown 解析能力，通过 `MarkupParser` 允许其他标记转换为带 `PresentationIntent` 的富文本。

`InlineText` 处理行内内容，`StructuredText` 处理标题、段落、列表、代码块和表格。`TextProperty`、`InlineStyle` 和 `StructuredText.Style` 表达可组合样式。InkMarkdown 可借鉴这种样式职责分解，但不能直接复用它的 SwiftUI 输出边界。

## SwiftStreamingMarkdown：流式产品路径

SwiftStreamingMarkdown 面向 LLM 输出，公开 `StreamedMarkdownView` 接收 `StreamedMarkdownSource` 产生的逐步增长快照。它支持常见 CommonMark/GFM 子集、表格、代码块、数学公式和引用 UI。

它的公开组装以 SwiftUI 为主，但段落渲染内部使用 `UITextView`。这能帮助区分两件事：“内部使用 UIKit”不等于“向 UIKit 宿主公开富文本和块路由 API”。

## InkMarkdown 为什么仍有独立边界

InkMarkdown 组合三个明确选择：

1. 用 swift-markdown 保留结构化 `Markup` 树。
2. 向 UIKit 宿主直接返回 `NSAttributedString` 或可创建 `UIView` 的块。
3. 把不适合线性富文本的表格、代码块和分割线交给 block handler。

因此，选型时不应只问“是否支持 Markdown”。先问宿主是 UIKit 还是 SwiftUI，再问需要的公开输出、块交互和流式语义。

## 来源与局限

Context7 使用以下库 ID 查询仓库文档：

- `/swiftlang/swift-markdown`
- `/gonzalezreal/swift-markdown-ui`
- `/gonzalezreal/textual`
- `/microsoft/swiftstreamingmarkdown`

主要上游来源：

- [swift-markdown：Parsing, Building, and Modifying Markup Trees](https://github.com/swiftlang/swift-markdown/blob/main/Sources/Markdown/Markdown.docc/Parsing-Building-and-Modifying%20Markup-Trees.md)
- [swift-markdown：Visitors, Walkers, and Rewriters](https://github.com/swiftlang/swift-markdown/blob/main/Sources/Markdown/Markdown.docc/Visitors-Walkers-and-Rewriters.md)
- [MarkdownUI README](https://github.com/gonzalezreal/swift-markdown-ui/blob/main/README.md)
- [MarkdownUI `Markdown` view](https://github.com/gonzalezreal/swift-markdown-ui/blob/main/Sources/MarkdownUI/Views/Markdown.swift)
- [Textual README](https://github.com/gonzalezreal/textual/blob/main/README.md)
- [Textual System Overview](https://github.com/gonzalezreal/textual/blob/main/Contributor%20Documentation/System%20Overview.md)
- [SwiftStreamingMarkdown README](https://github.com/microsoft/SwiftStreamingMarkdown/blob/main/README.md)

Context7 本次没有正确解析 `johnxnguyen/Down`，而是返回了同名 Ruby 库。因此本页不对 Down 作未经验证的引用或对比。

## 维护规则

外部库的公开 UI 边界、解析依赖、最低平台或流式 API 变化时，更新本页，再复查[学习路径第 8 章](../learning-path/08-library-landscape-and-design-tradeoffs.md)与[项目概述](../contributor-guide/01-overview.md)。
