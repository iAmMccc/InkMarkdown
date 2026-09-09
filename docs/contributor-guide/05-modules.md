# 五、模块详解

本文列出源码模块的类型与职责分配，作为代码查找参考。可结合 `Sources/InkMarkdown/` 目录查看。

## 模块依赖关系

```text
InkMarkdown.swift  (@_exported Markdown)
  ├─ Parser: InkParser / InkLineClassifier
  ├─ Configuration: InkConfiguration / InkAppearance
  ├─ Attributed: InkAttributedRenderer → InkTextContext / InkInlineSyntax
  ├─ Block: InkBlockRenderer → Handlers → CodeBlock / Table / ThematicBreak
  │            └─ LayoutManager / TableRenderHelper
  └─ Stream: InkStreamRenderer → IncrementalMarkdownRenderer → Attributed
```

## 公开入口

**`InkMarkdown.swift`**：重新导出模块（`@_exported import Markdown`）。渲染入口在各个 Renderer 中。

## 解析模块 (`Parser/`)

| 类型 | 职责 |
| --- | --- |
| `InkParser` | `Document(parsing:)` 封装，预留解析钩子 |
| `InkLineClassifier` | 无状态行分类：`.text` / `.tableLine` / `.codeFenceOpen` / `.codeFenceClose` / `.thematicBreak` |

分类器本身无状态，代码块状态由流式状态机控制。`isDelimiterRow` 用于确认 GFM 表头分隔行。

## 配置模块 (`Configuration/`)

### `InkConfiguration`

| 字段 | 说明 |
| --- | --- |
| `appearance` | 默认使用 `InkAppearance.shared` |
| `inlineSyntaxes` | 自定义行内语法扩展，默认 `[]` |
| `sourceFilter` | 源码预处理回调函数 |
| `blockHandlers` | 块路由列表，按顺序匹配 |
| `linkTapHandler` | 链接点击回调函数 |

`defaultBlockHandlers` 包含 Code、Table 和 ThematicBreak。`standard` 等同于 `.init()`。

### `InkAppearance`

配置子结构：`Text`、`Heading`、`Blockquote`、`List`、`CodeBlock`、`InlineCode`、`Table`、`ThematicBreak`、`Link`。

- `shared`：全局单例
- 正文默认样式：`fontSize = 17`、`lineHeight = 28`
- `Heading.fontSize(forLevel:)`：H1 使用 `h1FontSize`，其余等级共用 `fontSize`
- `Text.blockInsets` 默认值为 `.zero`

## 富文本渲染模块

### `InkAttributedRenderer`

| 入口方法 | 用途 |
| --- | --- |
| `render(_:configuration:)` | Markdown 源码转富文本 |
| `render(document:)` | 解析好的 Document 转富文本 |
| `render(markups:)` | 块路由刷新使用；处理块间换行与末尾 0.1pt 间距哨兵 |
| `renderInline(...)` | 仅渲染行内样式，不应用段落样式（用于表格单元格） |

内部使用 `InkRenderer` 分发 `renderBlock` 和 `renderInline` 分支。渲染完成后使用 `applyFixedLineHeight` 统一处理行高。

实现要点：

- 列表 marker 使用正文字重，悬挂缩进设置 `headIndent = maxMarkerWidth`
- 引用块对非段落子节点仅增加缩进，不应用全文段落样式
- 图片：**默认**占位符 `[🖼 plainText|source|image]`；`InkImageRendering.isEnabled == true` 时走 `InkImageAttachment` / `InkImageBlock`（见 [ADR-006](../decisions/ADR-006-opt-in-image-rendering.md)）
- `InlineHTML`：`<br>` 转换为换行符，其余 HTML 标签丢弃或替换为空串
- `Strikethrough`：`context.striking()` 传向下级，由叶子节点应用 `.strikethroughStyle`
- 代码块在富文本通道仅作为降级方案，UI 块渲染使用公开 `InkCodeBlock` 生成的 `UIView`

### `InkTextContext`（internal）

行内样式上下文管理，不对外暴露。详见 [03 §3.2](03-principles.md)。

### `InkInlineSyntax` / `InkInlineContext`

通过正则匹配 `Text` 节点生成行内片段，与 `InkBlockHandler` 分别处理行内与块级扩展。

### `InkAttributedTextBlock`

`UITextView` 视图容器：基于 `InkMarkdownLayoutManager`，不可编辑，允许选中，禁用滚动。配置 `linkTapHandler` 时关闭 `dataDetectorTypes`。

## 块路由模块

### `InkBlockRenderer`

遍历 AST 子节点：匹配 handler 则刷新已积攒的富文本并追加 `UIView` 块，未匹配则加入 pending。最后调用 `render(markups:)` 一次性渲染富文本。

### `InkBlockHandler` / `InkRenderableBlock`

```swift
public protocol InkRenderableBlock {
  func makeView() -> UIView
}
```

`makeBlock` 方法须向内传递 `configuration`，确保单元格等子元素使用相同的语法和链接回调。

## 组件模块 (`Rendering/Components/`)

| 文件 | 职责 |
| --- | --- |
| `InkMarkdownLayoutManager` | 绘制行内代码背景与引用竖线，提供公开 attribute key |
| `InkCodeBlockView.swift` / `InkCodeBlock` | 代码块视图实现；公开 block `InkCodeBlock` 生成圆角背景与等宽字体 `UIView` |
| `InkThematicBreakBlock` | 分割线视图 |
| `InkTableBlock` | 解析 `Table` AST 节点生成表格结构 |
| `InkTableBlockView` | 静态表格呈现 adapter：消费 `InkTablePresentation` 快照，负责 wrap/scroll 容器与复制手势 |
| `InkTablePresentation` | 内部表格呈现状态：单元格来源接纳、列宽测量与失效（static/stream 共用） |
| `InkTableRenderHelper` | UIKit 建行/约束/反馈；消费已接纳的 cell 值与布局快照 |
| `InkTableCellTextView` | 支持链接点击的只读 TextView |
| `InkStreamTableView` | 流式逐行渲染表格 adapter：输入与布局协调委托 `InkTablePresentation`，`referenceRows` 只参与测量 |

## 图片模块 (`Rendering/Image/`)

| 文件 | 职责 |
| --- | --- |
| `InkImageStore` | 呈现订阅桥接；缓存、合并、排队和预算由所选后端负责（见 [ADR-012](../decisions/ADR-012-pluggable-image-management.md)） |
| `InkImagePresentationLoad` | 内部呈现订阅生命周期：替换、取消、过期抑制、一次终结；async 适配为 `InkImagePresentationLoadAsync` |
| `InkImageBlock` | 块级图片 adapter：尺寸/占位/失败 fallback/tap；观察委托 PresentationLoad |
| `InkImageAttachment` | 行内图片 adapter：保留 MaterializationIdentity 与 TextKit 段落抬升；观察委托 PresentationLoad |
| `InkImagePreviewController` | 全屏预览：使用配置中的图片后端与呈现订阅；保留高分辨率请求的过期结果抑制 |

> Block / Attachment / Preview 不再各自 switch Store 的 ready/loading/queued/rejected。


## 流式模块 (`InkStreamRenderer.swift`)

| 类型 | 角色 |
| --- | --- |
| `InkStreamRenderer` | 主线程 API：`bind` / `append` / `reset` / `finish`；后台解析与 DisplayLink 刷新 |
| `InkIncrementalMarkdownRenderer` | 基于稳定边界的增量解析渲染 |
| `InkStreamingPerformanceBenchmark` | `@_spi(Performance)` 性能测试助手 |

## SwiftUI 呈现宿主 (`InkMarkdownSwiftUI/Bridge/`)

| 类型 | 角色 |
| --- | --- |
| `InkMarkdownCoordinator` | 静态/blocks 路径与模式切换；流式委托 `InkStreamingPresentationHost` |
| `InkStreamingPresentationHost` | 流式接管：snapshot 应用、环境暂存、waiting/committed/releasing、成组 Session binding |
| `InkMarkdownRenderSession` | canonical source/phase、PublishHopper、continuity context；成组 `InkSessionPresentationBindingGrant` |

> 流式 token/observer/textView 接线不在 Coordinator 内维护第二套状态机。

## 代码修改指南

| 修改目标 | 相关文件 |
| --- | --- |
| 默认字号、颜色、间距 | `InkAppearance` + `appearance_defaultValues` |
| 行高计算 | `applyFixedLineHeight` / `baselineOffset` |
| 样式传递逻辑 | `InkTextContext`（参考 03 §3.2） |
| 自定义块或行内语法 | `InkBlockHandler` / `InkInlineSyntax` |
| 表格渲染与布局 | `InkTablePresentation`（来源/列宽）+ `InkTableBlockView` / `InkStreamTableView`（UIKit 呈现）+ `InkTableRenderHelper`（建行） |
| 图片加载与呈现生命周期 | `InkImagePresentationLoad`（共享观察）+ `InkImageBlock` / `InkImageAttachment` / `InkImagePreviewController`（呈现差异）+ `InkImageStore`（呈现订阅）+ `InkImageBackend`（资源管理） |
| 代码块外观 | `InkCodeBlock`（实现位于 `InkCodeBlockView.swift`） |
| 引用线与代码块背景 | `InkMarkdownLayoutManager` |
| 流式渲染逻辑 | `InkStreamRenderer`（参考 03 §3.7） |
