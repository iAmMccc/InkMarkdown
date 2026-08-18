# SwiftUI Markdown 生态研究

> 访问日期：**2026-08-17（UTC）**。
> 本文只把用户指定的上游仓库作为资料源：当前 `HEAD` 的 README、`Package.swift`、公开源入口，以及对应的 immutable commit URL。研究对象被作为比较集合记录；本文不据此断言市场地位。

## 证据规则

- **官方事实**：由下方固定 commit 的上游 README、manifest 或源代码直接表达的事实。README 中的项目自述会注明为“项目自述”，不把宣传性形容词改写成独立结论。
- **快照观察**：只描述“在该 commit 的 README / 源码中看到或没有看到什么”，不外推未来版本或所有下游用法。
- **UNVERIFIED**：本次研究没有一手证据、没有复现，或不能从仓库内容单独证明的断言。性能、内存、包体积、市场份额、优越性和实际跨平台构建结果均不在本文中作结论。

## 固定上游快照

| 项目 | 访问时 `HEAD` commit | 主要固定来源 |
| --- | --- | --- |
| MarkdownUI | [`8371aeb32f35795a9e559029fb08613355733626`](https://github.com/gonzalezreal/swift-markdown-ui/commit/8371aeb32f35795a9e559029fb08613355733626) | [README][MUI-R]、[Package.swift][MUI-P]、[`Markdown`][MUI-V] |
| Textual | [`01b51875a5406eefc95f52a058cb059e7bc94dc4`](https://github.com/gonzalezreal/textual/commit/01b51875a5406eefc95f52a058cb059e7bc94dc4) | [README][TXT-R]、[Package.swift][TXT-P]、[`StructuredText`][TXT-S] |
| SwiftStreamingMarkdown | [`b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4`](https://github.com/microsoft/SwiftStreamingMarkdown/commit/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4) | [README][SSM-R]、[Package.swift][SSM-P]、[`StreamedMarkdownView`][SSM-SV] |
| swift-markdown | [`27b7fc1a19068bcea3d2072db0ce86360d1400ed`](https://github.com/swiftlang/swift-markdown/commit/27b7fc1a19068bcea3d2072db0ce86360d1400ed) | [README][SM-R]、[Package.swift][SM-P]、[`Document`][SM-D]、[`Markup`][SM-M] |

上表的 commit 是访问日通过各仓库的 `HEAD` 解析得到的；正文中的文件链接也都固定在这些 commit，而不是可变的 `main` / `HEAD` URL。

## 证据标记与总览

| 项目 | manifest 声明的平台 / 工具链 | 对外渲染输出 | 流式定位（固定快照） | 主要扩展面 | UIKit 证据 |
| --- | --- | --- | --- | --- | --- |
| MarkdownUI | macOS 12、iOS 15、tvOS 15、Mac Catalyst 15、watchOS 8；Swift tools 5.6 | SwiftUI `Markdown: View`；内部组合 SwiftUI `View` / `Text` | README 标为 maintenance mode；公开入口中未出现流式输入类型 | `Theme`、SwiftUI style modifiers、Markdown content builder、image provider、code highlighter | 公开渲染入口是 SwiftUI；图片 provider 对 UIKit / AppKit 做条件分支，不是 UIKit-only 证据 |
| Textual | macOS 15、iOS 18、tvOS 18、watchOS 11、visionOS 2；Swift tools 6.0 | `InlineText` / `StructuredText: View`；`AttributedString` → SwiftUI `Text` 与附件 | 公开入口以静态 `String` / `MarkupParser` 为主；该快照没有 `Streamed...` 公共入口 | `MarkupParser`、`AttributedString` syntax extensions、inline / block styles、attachment loaders、`openURL` | 源码明确有条件编译的 UIKit 和 AppKit 实现；不是 UIKit-only |
| SwiftStreamingMarkdown | iOS 16、macOS 14；Swift tools 5.9 | SwiftUI `MarkdownView` / `StreamedMarkdownView`；中间有 `RenderableDocument` | `AsyncStream<String>` 每次发出“截至目前的完整快照”，控制器每次解析后刷新 | `MarkdownRenderConfig`、`MarkdownParser`、`MarkdownListener`、预解析 `DocumentView` | 源码明确有 `ParagraphUIView: UITextView` 与 AppKit 对应实现；是 SwiftUI + 平台原生文本视图 |
| swift-markdown | `Package.swift` 未声明 UI 平台列表；Swift tools 6.2，Swift language mode v5 | `Markdown.Document` / `Markup` 树，不是 UI renderer | 非流式 UI；提供解析树给消费者 | `MarkupVisitor`、`MarkupWalker`、rewriter、解析选项 | 相关 parser / tree 源码没有 UIKit 或 SwiftUI 输出类型 |

> `[官方事实]` manifest 的平台字段是“声明的部署约束”，不是本次研究对每个平台成功构建的独立验证。实际跨平台构建状态见文末 **UNVERIFIED**。

## 1. MarkdownUI

### 定位与部署约束

- **官方事实（项目自述）**：README 顶部明确写着 MarkdownUI 处于 **maintenance mode**，新开发发生在 Textual；README 同时把库描述为在 SwiftUI 中显示和定制 Markdown。[MUI-R]
- **官方事实**：`Package.swift` 声明 macOS 12、iOS 15、tvOS 15、Mac Catalyst 15、watchOS 8；README 另注明表格或多图段落等部分能力需要 macOS 13、iOS 16、tvOS 16、watchOS 9。[MUI-P][MUI-R]
- **官方事实**：manifest 的 target 依赖 `swift-cmark` 的 `cmark-gfm` / `cmark-gfm-extensions`，并依赖 `NetworkImage`；解析入口的实现使用 cmark GFM 节点转换为库内 `BlockNode` / `InlineNode`。[MUI-P][MUI-MP]

### 输出模型

- **官方事实**：公开入口是 `public struct Markdown: View`。它接收 `String` 或 `MarkdownContent`，并通过 `BlockSequence` 生成块级 SwiftUI 视图。[MUI-V][MUI-BS]
- **官方事实**：`MarkdownContent` 是可在 model layer 预先创建的值；它保存内部块节点，并提供 `renderMarkdown()`、`renderPlainText()`、`renderHTML()` 等序列化方法。它不是 `NSAttributedString` 输出 API。[MUI-C]
- **官方事实**：行内 renderer 的结果类型是 SwiftUI `Text`，图片则组合为 SwiftUI `Image` / `Text`；块级路径同样以 SwiftUI `View` 组合。[MUI-IT][MUI-TIR][MUI-BN]

### 流式定位

- **快照观察**：README 的当前顶注将维护状态和 Textual 迁移作为项目定位；本文检视的 README、公开 `Markdown` 入口和 `MarkdownContent` 入口没有声明 `AsyncSequence`、chunk source 或 streamed Markdown view。[MUI-R][MUI-V][MUI-C]
- 这只表示“该 commit 的公开入口没有记录这种 API”，不等同于对所有历史版本、分支或外部包装器作“不支持”的普遍断言。

### 扩展与定制模型

- **官方事实**：`Theme` 把 inline text style、六级标题、段落、引用、代码块、图片、列表、表格和 thematic break 等样式聚合起来；`markdownTheme`、`markdownTextStyle`、`markdownBlockStyle` 通过 SwiftUI environment 覆盖样式。[MUI-T][MUI-ET]
- **官方事实**：`MarkdownContentBuilder` / `InlineContentBuilder` 允许用字符串和 DSL 组合 Markdown 内容；这是一条“构造内容”的扩展路径。[MUI-MCB][MUI-ICB]
- **官方事实**：公开协议包括 `ImageProvider`、`InlineImageProvider` 和 `CodeSyntaxHighlighter`；对应的 SwiftUI modifiers 将 provider / highlighter 注入 view hierarchy。[MUI-IP][MUI-CSH][MUI-EIP][MUI-ECSH]
- **官方事实**：`Markdown` 的文档和实现使用 SwiftUI 的 `openURL` environment 处理链接行为。[MUI-V]

### UIKit 证据

- **官方事实**：公开 `Markdown` 源文件直接 `import SwiftUI`。[MUI-V]
- **官方事实**：`AssetImageProvider` 在 `#if canImport(UIKit)` 分支使用 `UIImage`，在 `#elseif canImport(AppKit)` 分支使用 `NSImage`，随后转换为 SwiftUI `Image`。[MUI-AIP]
- 因此，一手源码证明的是 SwiftUI 公共渲染 + 条件化平台图片适配；它**没有证明 MarkdownUI 是 UIKit-only**。

## 2. Textual

### 定位与部署约束

- **官方事实（项目自述）**：README 称 Textual 是 MarkdownUI 的 successor，并把它定位为“SwiftUI text rendering engine that happens to support Markdown”；README 的公开入口是 `InlineText` 和 `StructuredText`。[TXT-R]
- **官方事实**：`Package.swift` 声明 macOS 15、iOS 18、tvOS 18、watchOS 11、visionOS 2，Swift tools 6.0。[TXT-P]

### 输出模型

- **官方事实**：`InlineText` 和 `StructuredText` 都是 SwiftUI `View`。两者持有 `AttributedString` state，并把解析结果交给附件解析和文本 fragment 视图。[TXT-I][TXT-S]
- **官方事实**：`MarkupParser` 的公共协议返回 `AttributedString`；文档明确要求结构化输出携带 Foundation `PresentationIntent` / `InlinePresentationIntent` 等属性。[TXT-MP]
- **官方事实**：内置 `AttributedStringMarkdownParser` 调用 Foundation 的 `AttributedString(markdown:including:options:baseURL:)`，之后用 pattern processor 展开 emoji / math 等扩展。[TXT-AMP]
- **官方事实**：`WithAttachments` 异步解析图片和 emoji attachment；`TextBuilder` 将 attributed runs 构成 SwiftUI `Text`，并用自定义 attachment 属性保留附件布局信息。[TXT-WA][TXT-TB]
- 该模型与“直接返回 `NSAttributedString` 给 UIKit 宿主”不同：Textual 的公开显示对象是 SwiftUI view，解析协议的值类型是 Swift `AttributedString`。

### 流式定位

- **快照观察**：本 commit 的 README 和公开 source entry points 展示的是 `InlineText(markdown:)`、`StructuredText(markdown:)` 及自定义 `MarkupParser`；检视到的公开 API 没有 `Streamed...` view、chunk source 或 streaming protocol。[TXT-R][TXT-I][TXT-S][TXT-MP]
- `InlineText` / `StructuredText` 在输入字符串变化时重新调用 parser；这能证明其输入更新路径，但不能据此推导一个未声明的流式产品承诺。

### 扩展与定制模型

- **官方事实**：`MarkupParser` 是格式适配 seam；只要实现 `attributedString(for:)` 并提供正确的 presentation intents，就能让 `InlineText` / `StructuredText` 渲染非 Markdown 格式。[TXT-MP][TXT-S]
- **官方事实**：`SyntaxExtension` 支持在 Markdown 解析后展开 emoji、math 等语法；Markdown initializer 公开接收 syntax extensions。[TXT-AMP][TXT-I][TXT-S]
- **官方事实**：Textual 通过 `.textual` namespace 暴露 inline style、heading / paragraph / block quote / list / code block / table / thematic break 等 style protocol 和 modifier；也提供整体 `StructuredText.Style`。[TXT-V][TXT-S]
- **官方事实**：图片与 emoji 通过 `AttachmentLoader` 注入；链接使用 SwiftUI `openURL`，文本选择通过 `textSelection` modifier 控制。[TXT-R][TXT-V][TXT-S]

### UIKit 证据

- **官方事实**：源码有明确的 `#if ... canImport(UIKit)` UIKit text-selection 实现，例如 `UITextInteractionView: UIView`；同时存在 `canImport(AppKit)` 的 AppKit selection 实现。[TXT-UIKIT][TXT-APPKIT]
- **官方事实**：`PlatformFont` 在 AppKit 和 UIKit 之间做条件化字体适配，且 `Package.swift` 同时声明 macOS、iOS、tvOS、watchOS、visionOS。[TXT-P][TXT-PF]
- 因此，源码证明的是跨平台 SwiftUI renderer 中包含 UIKit / AppKit platform paths；它**不是 UIKit-only 实现**。

## 3. SwiftStreamingMarkdown

### 定位与部署约束

- **官方事实（项目自述）**：README 将其描述为提供 streaming experiences 的 iOS / macOS Markdown renderer，并把 `MarkdownView`、`StreamedMarkdownView`、theme customization、listener 等列为公开使用路径。[SSM-R]
- **官方事实**：`Package.swift` 声明 iOS 16、macOS 14，Swift tools 5.9；target 依赖 `swift-markdown` 版本 `0.7.3`，另有 LaTeX、代码高亮、动画和测试依赖。[SSM-P]

### 输出模型

- **官方事实**：`MarkdownView` 是 SwiftUI `View`，内部异步调用 parser，再把 `RenderableDocument` 交给 `DocumentView`；`StreamedMarkdownView` 也把不断更新的 `RenderableDocument` 交给同一个文档视图。[SSM-MV][SSM-SV][SSM-DV]
- **官方事实**：`RenderableDocument` 是经过配置转换、准备交给 SwiftUI view 的中间表示；其内部的 `MarkdownRenderable` 具有 paragraph、heading、list、code block、table、blockquote、LaTeX、thematic break 和 image 等 block cases。paragraph / heading / table 内容使用 `NSMutableAttributedString`。[SSM-RENDERABLE]
- **官方事实**：`MarkdownParser.parse(text:config:)` 的结果是 `RenderableDocument`；内置 `MarkdownParserImpl` 先创建 swift-markdown `Document`，再做部分语法重写、图片重写和 renderable conversion。[SSM-PARSER][SSM-IMPL][SSM-RENDERABLE]

### 流式定位与输入语义

- **官方事实**：`StreamedMarkdownSource` 的 `text` 类型是 `AsyncStream<String>`，而源文件文档明确规定每次 yield 的是“截至目前的完整 Markdown source snapshot”，不是 delta。[SSM-SV]
- **官方事实**：`StreamedMarkdownController.start()` 对每个 snapshot 调用 `parser.parse(text:config:)`，随后在 `MainActor` 上更新 `markdownToRender`；流结束或 view 消失时取消任务。[SSM-SV]
- **官方事实**：README 给出的 `StreamedMarkdownView` 示例同样把 source 设计成逐渐变大的完整文本；如果直接驱动 `DocumentView`，调用方可以自己解析每个 snapshot 后传入 `RenderableDocument`。[SSM-R][SSM-DV]
- 这确立了一个清晰的流式 API 语义：**上游提供完整快照，库负责异步重复解析和替换文档表示**。它不是 `append(delta:)` 的公开输入协议。

### 扩展与定制模型

- **官方事实**：`MarkdownRenderConfig` 集中承载 typography、inline、heading、paragraph、table、citation、code block、text selection、thematic break 和 image 等配置；`shouldAnimateText` 也在该 value 中。[SSM-CONFIG]
- **官方事实**：`MarkdownParser` 是 async parser protocol；`DocumentView` / `RenderableDocument` 允许调用方把预解析结果与配置分开使用。[SSM-PARSER][SSM-DV][SSM-RENDERABLE]
- **官方事实**：`MarkdownListener` 提供 render、table copy / download、context menu、image tap 和 bundled-resource resolution 等事件 seam，并通过 `DocumentView` 的 SwiftUI environment controller 传递。[SSM-LISTENER][SSM-DV]
- **官方事实**：README 将图片支持标为 experimental；源码的 `MarkdownParseOption.imageSupport` 也明确写出实验性和行为可能变化。[SSM-R][SSM-OPTION]

### UIKit 证据

- **官方事实**：源码在多个文件中使用 `#if canImport(UIKit) import UIKit #elseif canImport(AppKit) import AppKit`；iOS 路径的 `ParagraphUIView` 明确继承 `UITextView`，macOS 路径的 `ParagraphNSView` 明确继承 `NSTextView`。[SSM-RENDERABLE][SSM-PUI][SSM-PNS]
- 因此，SwiftUI 是其公开 view 层，但一手源码明确证明 iOS 内部使用 UIKit 文本视图；同一仓库也有 AppKit 路径。把它概括为“UIKit-only”会超出来源证据。

### 性能证据边界

- **官方事实（项目自述）**：README 有 “Streaming Performance” 小节和一张以 iPhone XS、sample app、持续 streaming / scrolling 为上下文的图表。[SSM-R]
- **UNVERIFIED**：本次没有复现该 profiling、没有获取其原始数据或独立测试，因此本文不把“smooth”“high-performance”、与其他库的性能差异、或 README 的任何性能 / 包体积数字作为结论。

## 4. swift-markdown：只记录与渲染器相关的边界

- **官方事实（项目自述）**：swift-markdown 是用于 parsing、building、editing、analyzing Markdown documents 的 Swift package；README 说明 parser 由 cmark-gfm 驱动，并提供 `Document(parsing:)` 示例。[SM-R]
- **官方事实**：`Package.swift` 的 product 是 `Markdown`，Swift tools 6.2，Swift language mode v5；manifest 没有声明 UI 平台列表。[SM-P]
- **官方事实**：`Document` 是顶层文档节点，`Document(parsing:options:)` 返回解析树；`Markup` 是节点协议，提供 visitor、children、parent、root 等树访问能力。[SM-D][SM-M]
- **官方事实**：`ParseOptions` 当前公开了 block directives、symbol links、smart options、Doxygen 和 source-position 等解析选项。[SM-O]
- 这些入口提供的是 **Markup AST / value-tree 层**，不是 SwiftUI `View`、UIKit `UIView` 或 `NSAttributedString` renderer。具体显示模型由上层库决定：SwiftStreamingMarkdown 在其 parser 中消费 `Document`，InkMarkdown 的 `InkParser` 也以 `Document(parsing:)` 为入口。[SSM-PARSER][INK-PARSER]

## InkMarkdown UIKit core 对照基线

> 这里引用的是本仓库当前 UIKit core 源码，不是已发布版本或 immutable commit。先前的 SwiftUI spike 已被拒绝并移出仓库；它不是本节证据，也不构成 public interface。

- **官方事实（本仓库源码）**：`InkAttributedRenderer.render` 的公开结果是 `NSAttributedString`；实现文件直接 `import UIKit`，并把 Markup 节点递归写入 UIKit attributed-string attributes。[INK-ATTR]
- **官方事实**：`InkBlockRenderer.render` 返回 `[InkRenderableBlock]`；`InkRenderableBlock.makeView()` 返回 `UIView`。`InkBlockHandler` 允许按 `Markup` 节点匹配并生成独立 UIView block。[INK-BLOCK][INK-RENDERABLE][INK-HANDLER]
- **官方事实**：`InkStreamRenderer.append(_:)` 接收增长中的 chunk，内部绑定 `UITextView`；`finish()` 的本通道结果仍是最终 `NSAttributedString`，块级 block 需要另行走 `InkBlockRenderer`。[INK-STREAM]
- **官方事实**：`InkConfiguration` 的扩展点包括 `sourceFilter`、`inlineSyntaxes`、`blockHandlers` 和链接回调；`InkAppearance` 按文本、标题、引用、代码、表格、分割线、图片等语法元素组织样式。[INK-CONFIG][INK-APPEAR]

## 对 InkMarkdown 的事实差异化空间（非建议）

以下只把源码已经形成的差异列为“空间”，不把它写成推荐或优越性结论：

1. **UIKit 输出契约**：MarkdownUI、Textual、SwiftStreamingMarkdown 的公开显示入口都是 SwiftUI `View`；InkMarkdown 的核心公开入口是 `NSAttributedString`，块级复杂内容则是 `UIView` block。Textual 和 SwiftStreamingMarkdown 的内部也有 UIKit 路径，因此差异点是 **InkMarkdown 的公开 UIKit-first contract**，不是“其他项目完全不使用 UIKit”。
2. **Attributed string + UIView block 双通道**：InkMarkdown 明确把能进入富文本的内容放入 `NSAttributedString`，把代码块、表格等通过 `InkBlockHandler` 路由为 `UIView`；这与 MarkdownUI 的 SwiftUI block style、Textual 的 `AttributedString` / SwiftUI block style、SwiftStreamingMarkdown 的 `RenderableDocument` / SwiftUI block view 组合方式形成可核验的 API 形状差异。
3. **流式输入单位**：InkMarkdown 当前 `append(_:)` 直接接收 delta chunk；SwiftStreamingMarkdown 的公开 `StreamedMarkdownSource` 要求每次发送完整 source snapshot。MarkdownUI 和 Textual 的本快照公开入口没有对应 streaming source 类型。这个区别是输入协议语义差异，不是性能结论。
4. **解析层的共享与差异**：InkMarkdown 与 SwiftStreamingMarkdown 都以 swift-markdown `Document` 为解析边界；MarkdownUI 的当前实现直接使用 cmark-gfm，Textual 的内置 Markdown parser 使用 Foundation `AttributedString` Markdown parser。InkMarkdown 因而同时具备“swift-markdown AST 消费者”和“UIKit renderer”这两个由源码直接支持的定位事实，但 swift-markdown 本身并非 InkMarkdown 独占能力。
5. **扩展 seam 的形状**：InkMarkdown 的公开配置把源文本预处理、行内语法、Markup → UIView block handler 和链接回调集中在 `InkConfiguration`；对照项目的公开 seam 分别更偏向 SwiftUI theme/style/provider、`MarkupParser` 返回 `AttributedString`、或 parser/config/listener/value-document 组合。这里记录的是 API 边界差异，不是可用性或维护成本判断。

## UNVERIFIED 与未作结论项

- **UNVERIFIED**：没有在本次研究中对四个上游的所有声明平台逐一构建或运行，因此不把 manifest 声明改写为“已验证支持”。
- **UNVERIFIED**：没有独立复现任何性能、滚动流畅度、内存、包体积或延迟数据；本文不作 Big-O、benchmark 或性能排序。
- **UNVERIFIED**：没有市场份额、采用量、维护质量或“最佳 / 更快 / 更强”证据；本文不作市场或竞品优越性判断。
- **UNVERIFIED**：MarkdownUI / Textual 在当前快照公开入口中未出现 streaming API，只能支持“该快照未声明 / 未检视到该入口”，不能推导其未来版本、私有 API 或外部包装器的能力边界。

## 一手资料索引（均为 immutable commit URL）

### MarkdownUI（`8371aeb32f35795a9e559029fb08613355733626`）

[MUI-R]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/README.md
[MUI-P]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Package.swift
[MUI-V]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Views/Markdown.swift
[MUI-C]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/DSL/Blocks/MarkdownContent.swift
[MUI-T]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Theme/Theme.swift
[MUI-ET]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Views/Environment/Environment%2BTheme.swift
[MUI-MP]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Parser/MarkdownParser.swift
[MUI-BS]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Views/Blocks/BlockSequence.swift
[MUI-BN]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Parser/BlockNode.swift
[MUI-IT]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Views/Inlines/InlineText.swift
[MUI-TIR]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Renderer/TextInlineRenderer.swift
[MUI-MCB]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/DSL/Blocks/MarkdownContentBuilder.swift
[MUI-ICB]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/DSL/Inlines/InlineContentBuilder.swift
[MUI-IP]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Extensibility/ImageProvider.swift
[MUI-EIP]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Views/Environment/Environment%2BImageProvider.swift
[MUI-CSH]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Extensibility/CodeSyntaxHighlighter.swift
[MUI-ECSH]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Views/Environment/Environment%2BCodeSyntaxHighlighter.swift
[MUI-AIP]: https://github.com/gonzalezreal/swift-markdown-ui/blob/8371aeb32f35795a9e559029fb08613355733626/Sources/MarkdownUI/Extensibility/AssetImageProvider.swift

### Textual（`01b51875a5406eefc95f52a058cb059e7bc94dc4`）

[TXT-R]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/README.md
[TXT-P]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Package.swift
[TXT-I]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/InlineText/InlineText.swift
[TXT-S]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/StructuredText/StructuredText.swift
[TXT-MP]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/MarkupParser.swift
[TXT-AMP]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/MarkdownParser/AttributedStringMarkdownParser.swift
[TXT-V]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/View%2BTextual.swift
[TXT-WA]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/Internal/Attachment/WithAttachments.swift
[TXT-TB]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/Internal/TextFragment/TextBuilder.swift
[TXT-UIKIT]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/Internal/TextInteraction/UIKit/UITextInteractionView.swift
[TXT-APPKIT]: https://github.com/gonzalezreal/textual/tree/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/Internal/TextInteraction/AppKit
[TXT-PF]: https://github.com/gonzalezreal/textual/blob/01b51875a5406eefc95f52a058cb059e7bc94dc4/Sources/Textual/Internal/Font/PlatformFont.swift

### SwiftStreamingMarkdown（`b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4`）

[SSM-R]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/README.md
[SSM-P]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Package.swift
[SSM-MV]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/MarkdownView.swift
[SSM-SV]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/StreamedMarkdownView.swift
[SSM-DV]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/UI/DocumentView.swift
[SSM-PARSER]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/Parser/MarkdownParser.swift
[SSM-IMPL]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/Parser/MarkdownParserImpl.swift
[SSM-RENDERABLE]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/Models/RenderableDocument.swift
[SSM-CONFIG]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/Models/MarkdownRenderConfig.swift
[SSM-LISTENER]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/Utilities/MarkdownListener.swift
[SSM-OPTION]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/Parser/MarkdownParseOption.swift
[SSM-PUI]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/UI/Paragraph/UIKit/ParagraphUIView.swift
[SSM-PNS]: https://github.com/microsoft/SwiftStreamingMarkdown/blob/b7b82b6a63e33cd3d41366ac76de6216d1bcf1a4/Sources/MarkdownText/UI/Paragraph/AppKit/ParagraphNSView.swift

### swift-markdown（`27b7fc1a19068bcea3d2072db0ce86360d1400ed`）

[SM-R]: https://github.com/swiftlang/swift-markdown/blob/27b7fc1a19068bcea3d2072db0ce86360d1400ed/README.md
[SM-P]: https://github.com/swiftlang/swift-markdown/blob/27b7fc1a19068bcea3d2072db0ce86360d1400ed/Package.swift
[SM-D]: https://github.com/swiftlang/swift-markdown/blob/27b7fc1a19068bcea3d2072db0ce86360d1400ed/Sources/Markdown/Base/Document.swift
[SM-M]: https://github.com/swiftlang/swift-markdown/blob/27b7fc1a19068bcea3d2072db0ce86360d1400ed/Sources/Markdown/Base/Markup.swift
[SM-O]: https://github.com/swiftlang/swift-markdown/blob/27b7fc1a19068bcea3d2072db0ce86360d1400ed/Sources/Markdown/Parser/ParseOptions.swift

### InkMarkdown（当前工作树相对路径）

[INK-PARSER]: ../../Sources/InkMarkdown/Parser/InkParser.swift
[INK-ATTR]: ../../Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift
[INK-BLOCK]: ../../Sources/InkMarkdown/Rendering/Block/InkBlockRenderer.swift
[INK-RENDERABLE]: ../../Sources/InkMarkdown/Rendering/Block/InkRenderableBlock.swift
[INK-HANDLER]: ../../Sources/InkMarkdown/Rendering/Block/InkBlockHandler.swift
[INK-STREAM]: ../../Sources/InkMarkdown/Rendering/InkStreamRenderer.swift
[INK-CONFIG]: ../../Sources/InkMarkdown/Configuration/InkConfiguration.swift
[INK-APPEAR]: ../../Sources/InkMarkdown/Configuration/InkAppearance.swift
