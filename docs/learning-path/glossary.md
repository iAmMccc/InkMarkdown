# InkMarkdown 初学者术语表

本页用项目语境解释术语，不追求学术定义。第一次遇到陌生词时先看“白话解释”，再根据链接进入对应章节。

## A–G

### AST

Abstract Syntax Tree，抽象语法树。可以把它理解为“把原始标记符号整理成有父子关系的内容结构”。本项目通常称为 `Markup` 树。见[第 2 章](02-commonmark-gfm-and-markup-tree.md)。

### Attribute

附加到某段文字范围的属性，例如字体、颜色、段落样式和链接。见[第 3 章](03-nsattributedstring-and-textkit.md)。

### Attribute run

连续且 attributes 相同的一段文字。它是理解概念，不是项目中的某个 public 类型。

### Baseline / baselineOffset

Baseline 是文字排版时对齐字形的基准线。`baselineOffset` 会让文字相对基准位置上下移动。InkMarkdown 用它配合固定行高，让不同字体在行盒中更稳定。

### Block / 块级结构

通常独占一段垂直区域的文档结构，例如标题、段落、列表、引用、代码块和表格。

### Block handler

实现 `InkBlockHandler` 的路由对象。它识别某个顶层 Markup 节点，并把它变成独立 `InkRenderableBlock`。见[第 5 章](05-block-routing.md)。

### CADisplayLink

跟随屏幕刷新节奏回调的定时机制。`InkStreamRenderer` 用它在主线程逐帧推进可见字符，不负责 Markdown 解析。见[第 6 章](06-streaming-rendering.md#62-解析和显示使用两个进度)。

### CommonMark

一套精确的 Markdown 解析规范，用大量示例减少不同实现之间的歧义。它规定结构怎样识别，不规定 UIKit 外观。

### Configuration

`InkConfiguration`。聚合一次渲染所需的 appearance、行内扩展、源文本过滤、块 handlers 和链接回调。

### Context

递归渲染时向子节点传递的当前样式环境。`InkTextContext` 保存字体、颜色、链接等信息。

### Document

swift-markdown 解析结果的根节点。它的 `children` 通常是标题、段落、列表等顶层块。

### Dual-buffer / 双缓冲

`InkStreamRenderer` 把“解析”和“显示”分成两条互不阻塞的独立进度：后台串行队列持续把解析结果写进 `preloadContent` 这个缓冲区，`CADisplayLink` 按帧从里面读取并逐步推进可见文字。解析慢不会卡显示动画，这就是项目所说的“双缓冲”。见[第 6 章](06-streaming-rendering.md#完整双缓冲流程把上面的方框展开)。

### Generation / 代（换代丢弃过期任务）

`InkStreamRenderer` 内部用一个只增不减的计数器（`renderGeneration`）标记当前有效的渲染轮次。每次 `reset(to:)` 或 `finish()` 都会让计数器 +1；后台解析任务写回结果前会检查自己拿到的计数器是否还等于当前值，不相等就直接丢弃，避免过期的后台结果覆盖新一轮的显示状态。见[第 6 章](06-streaming-rendering.md#完整双缓冲流程把上面的方框展开)。

### GFM

GitHub Flavored Markdown。它是 CommonMark 的严格超集，增加表格、任务列表、删除线和扩展自动链接等能力。

### Glyph

实际用于排版和绘制的字形。字符与 glyph 不保证永远一一对应，因此 TextKit 会区分字符范围与 glyph 范围。见[第 3 章](03-nsattributedstring-and-textkit.md#一次显示是怎样发生的)。

## H–N

### Handler 顺序

`InkBlockRenderer` 选择第一个能处理节点的 handler。数组顺序就是匹配优先级。

### Immutable / 不可变

创建后不直接修改原值。swift-markdown 的 Markup 树通常按不可变方式读取；改写时生成新树。`NSAttributedString` 也不可变，修改时使用 `NSMutableAttributedString`。

### Incremental rendering / 增量渲染

只重做新内容或受影响范围，而不是每次把所有工作从头执行。InkMarkdown 流式实现缓存稳定前缀，并重算活跃后缀。见[第 6 章](06-streaming-rendering.md#64-稳定前缀与活跃后缀)。

### InkAppearance

项目当前用来集中管理视觉参数的 `struct`，按 Markdown 语法元素拆成子配置（`text`、`heading`、`blockquote`、`list`、`codeBlock`、`inlineCode`、`table`、`thematicBreak`、`link`）。可以设置全局单例 `InkAppearance.shared`，也可以按需传入自定义实例；它决定字号、颜色、间距等外观，不决定 Markdown 怎样被解析。见[第 4 章](04-inkmarkdown-render-pipeline.md#和-inkappearance-的分工)。

### InkBlockRenderer

块路由渲染器。它按 `InkConfiguration.blockHandlers` 的注册顺序为每个顶层 `Markup` 节点找第一个 `canHandle` 命中的 handler：命中就交给它生成独立 `InkRenderableBlock`（如表格、代码块），没命中的普通节点先累积到 `pendingMarkup`，遇到独立块或遍历结束时再批量渲染成 `InkAttributedTextBlock`。入口是 `InkBlockRenderer.render(_:configuration:)`，返回 `[InkRenderableBlock]`。见[第 5 章](05-block-routing.md)。

### InkTextContext

行内渲染时向下传递的样式上下文 `struct`，保存当前基准字体、前景色、是否处于链接内、斜体兜底用的 `obliqueness`，以及完整的 `InkAppearance`。每个行内节点基于父级 context 派生出新 context 交给子节点，叶子节点（如 Text、InlineCode、Image）据此一次性写好 attributes，不再需要“先渲染子节点、父节点回头覆盖”的旧模式。见[第 4 章](04-inkmarkdown-render-pipeline.md#46-阶段五行内递归与-inktextcontext)。

### Inline / 行内结构

位于段落或标题内部的结构，例如普通文字、加粗、斜体、链接和行内代码。

### Inline syntax

实现 `InkInlineSyntax` 的业务扩展，用于扫描 `Text` 节点中的自定义纯文本片段，例如 `$标签$`。它不是通用 Markdown 解析器。

### Line fragment / 行片段

`NSLayoutManager` 分配给某一行文字的矩形布局区域。它和 `usedRect`（该行文字实际占用的部分）不完全相同：短行右侧的空白仍属于 line fragment，但不计入 usedRect。项目里 `InkMarkdownLayoutManager` 按 line fragment 高度绘制代码背景和引用竖线。见[第 3 章](03-nsattributedstring-and-textkit.md#一次显示是怎样发生的)。

### Markup

swift-markdown 各种文档节点的公共抽象，例如 `Heading`、`Paragraph`、`Strong` 和 `Text`。一组具有父子关系的 Markup 构成树。

### Mutable / 可变

创建后允许修改。`NSMutableAttributedString` 可追加文字、添加或移除 attributes。

### NSLayoutManager

TextKit 1 的布局与绘制核心。它把字符映射到 glyph、计算行片段并绘制。项目子类 `InkMarkdownLayoutManager` 添加代码背景和引用线。见[第 3 章](03-nsattributedstring-and-textkit.md#nslayoutmanager)。

### NSAttributedString

“字符串 + 作用范围 + 属性”的富文本值。它保存内容和语义样式，不单独负责屏幕布局。见[第 3 章](03-nsattributedstring-and-textkit.md#31-nsattributedstring-是什么)。

### NSRange

Foundation 使用的“起点 + 长度”范围。处理 Swift `String` 时应使用正确转换，不要凭 `String.count` 手算 Emoji 范围。见[第 3 章](03-nsattributedstring-and-textkit.md#34-nsrange只把它当作位置--长度)。

### NSTextContainer

TextKit 1 中描述文字可用布局区域的对象，例如容器宽度和行片段内边距。见[第 3 章](03-nsattributedstring-and-textkit.md#nstextcontainer)。

### NSTextStorage

TextKit 1 中的可变富文本存储。内容或 attributes 改变时，它会通知关联的布局管理器。见[第 3 章](03-nsattributedstring-and-textkit.md#nstextstorage)。

## O–S

### Paragraph style

段落级排版属性集合，例如固定行高、首行缩进、段后距和对齐。Foundation 类型为 `NSParagraphStyle` / `NSMutableParagraphStyle`。见[第 3 章](03-nsattributedstring-and-textkit.md#35-段落属性和字符属性不同)。

### Parse / 解析

把 Markdown 字符串识别为结构化 Markup 树。InkMarkdown 把这项工作交给 swift-markdown。

### Parser

执行解析的组件。项目入口是 `InkParser`，当前内部调用 `Document(parsing:)`。

### Pending markup

`InkBlockRenderer` 中暂存的相邻普通顶层节点。遇到独立 UIView 块或遍历结束时，一批送给富文本渲染器。

### Recursion / 递归

一个处理方法用同样的方法继续处理子节点。可以理解为“处理当前盒子，再处理里面每个小盒子”。

### Render / 渲染

把结构转换为可显示结果。本项目的输出可以是 `NSAttributedString`，也可以是能创建 `UIView` 的块。

### Renderer

执行渲染的组件。主要入口包括 `InkAttributedRenderer`、`InkBlockRenderer` 和 `InkStreamRenderer`。

### Semantic / 语义

内容“是什么”，例如一级标题、链接、引用。它与“长什么样”不同。两个主题可以用不同颜色显示同一个链接语义。

### Soft break / hard line break

普通源文本换行通常形成 `SoftBreak`，项目当前显示为空格。明确的硬换行形成 `LineBreak`，项目显示为换行。具体识别规则由 Markdown 规范和解析器决定。

### Source filter

`InkConfiguration.sourceFilter`。在解析前接收原始字符串并返回新字符串，适合清理业务占位符。

### SPM

Swift Package Manager。项目使用 `Package.swift` 定义包、目标、平台和依赖。

### Stable boundary / 稳定边界

流式输入中，边界之前的内容被当前算法认为不会再受后续字符影响。项目采用保守判断，不等于通用增量 CommonMark 标准。见[第 6 章](06-streaming-rendering.md#64-稳定前缀与活跃后缀)。

### Stable prefix / 稳定前缀

流式累计文本中可以缓存、不必每次重新渲染的前半部分。见[第 6 章](06-streaming-rendering.md#64-稳定前缀与活跃后缀)。

### Swift Testing

Swift 的现代测试框架，常见标记为 `@Test`，断言为 `#expect`。项目语义和流式性能测试使用它。

## T–Z

### Tail / 活跃后缀

流式累计文本中仍可能被未来字符改变的尾部。例如未闭合的加粗、链接或代码围栏。见[第 6 章](06-streaming-rendering.md#64-稳定前缀与活跃后缀)。

### TextKit 1

Apple 的经典文本布局系统，核心链路是 `NSTextStorage → NSLayoutManager → NSTextContainer`。InkMarkdown 当前正式使用这条路径。见[第 3 章](03-nsattributedstring-and-textkit.md#36-nsattributedstring-不负责真正布局)。

### TextKit 2

Apple 较新的文本布局 API 体系。项目当前不把它作为 v1/v2 默认路径，不能把“存在新 API”写成“项目已经迁移”。

### Theme / Appearance

项目当前用 `InkAppearance` 集中保存视觉参数。它决定字号、颜色、间距等，不决定 Markdown 怎样被解析。

### UIKit

Apple 的视图框架。InkMarkdown 明确定位为 UIKit 专用库，不提供 SwiftUI 渲染器。

### usedRect

`NSLayoutManager` 在 `enumerateLineFragments` 回调里给出的矩形，表示某一行文字真正绘制到的区域，是 line fragment 里被字符实际占用的子集（不含行尾空白）。项目里 `InkMarkdownLayoutManager` 用它计算代码背景、引用竖线的绘制高度，而不是用整段 line fragment 的高度。见[第 3 章](03-nsattributedstring-and-textkit.md#一次显示是怎样发生的)。

### UTF-16

Foundation 文本 API 常用的编码单位。初学者无需计算编码，只需使用 `NSRange(_:in:)` 等转换 API，避免用人眼字符数推算范围。

### Visitor / Walker / Rewriter

swift-markdown 提供的三类树操作方式：Visitor 计算结果，Walker 做遍历副作用，Rewriter 生成改写后的树。初学阶段先掌握 `children` 递归，进阶再查[API 速查](../references/swift-markdown-api-guide.md)。

### XcodeBuildMCP

用于发现 Xcode 项目、选择 scheme 和 Simulator、构建、测试、运行、采集日志和 UI 自动化的 MCP 工具。项目默认优先使用它，避免自动化脚本写死本机环境。

## 仍然找不到某个词时

按以下顺序查：

1. [学习路径入口](README.md)
2. [贡献者指南](../contributor-guide/README.md)
3. [swift-markdown API 速查](../references/swift-markdown-api-guide.md)
4. [渲染语义规范](../spec/README.md)
5. Apple 或上游项目的官方文档
