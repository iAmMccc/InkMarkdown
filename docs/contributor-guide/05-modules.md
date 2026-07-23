# 五、模块详解

本页是源码定位 Reference。按公开入口、解析、配置、富文本、块路由、组件和流式模块查找类型与职责。

对照 `Sources/InkMarkdown/` 读。

## 依赖关系（简图）

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

**`InkMarkdown.swift`**：`@_exported import Markdown`。渲染入口在各 Renderer，不在这个文件。

## 解析 `Parser/`

| 类型 | 职责 |
| --- | --- |
| `InkParser` | `Document(parsing:)` 薄包装，预留统一钩子 |
| `InkLineClassifier` | 无状态行分类：`.text` / `.tableLine` / `.codeFenceOpen` / `.codeFenceClose` / `.thematicBreak` |

分类器不持状态；是否在代码块内由流式状态机保证。`isDelimiterRow` 二次确认 GFM 表头分隔行。

## 配置 `Configuration/`

### `InkConfiguration`

| 字段 | 说明 |
| --- | --- |
| `appearance` | 默认 `InkAppearance.shared`（保存字号、颜色、行高等基础样式） |
| `inlineSyntaxes` | 自定义行内语法扩展，默认 `[]`（通过正则匹配自定义并截获行内文本，如 @用户、#话题 等） |
| `sourceFilter` | 解析前预处理（对原始 Markdown 源码字符串进行清洗过滤） |
| `blockHandlers` | 块路由，有序匹配（将代码块、表格等块级元素路由至自定义的 UIView 组件） |
| `linkTapHandler` | 链接点击（宿主响应富文本链接点击时的业务回调） |

`defaultBlockHandlers`：Code / Table / ThematicBreak。`standard` = `.init()`。

### `InkAppearance`

子结构：`Text`、`Heading`、`Blockquote`、`List`、`CodeBlock`、`InlineCode`、`Table`、`ThematicBreak`、`Link`。

- `shared`：可变全局单例
- 正文默认：`fontSize = 17`、`lineHeight = 28`
- `Heading.fontSize(forLevel:)`：**仅 H1 用 `h1FontSize`，其余 level 共用 `fontSize`**
- `Text.blockInsets` 默认 `.zero`

## 富文本通道

### `InkAttributedRenderer`

| 入口 | 用途 |
| --- | --- |
| `render(_:configuration:)` | 源文本 → 富文本 |
| `render(document:)` | 已解析 Document |
| `render(markups:)` | 块路由 flush 用；块间 `\n`，末尾 `0.1pt` 哨兵兑现下间距 |
| `renderInline(...)` | 只行内、不挂段落样式（表格单元格） |

私有 `InkRenderer`：`renderBlock` / `renderInline` 用 `switch` 分发（功能上等价 Visitor，未形式化为 `MarkupVisitor`）。唯一后处理：`applyFixedLineHeight`。

实现上要注意：

- 列表 marker 用正文字重；悬挂缩进 `headIndent = maxMarkerWidth`
- 引用对非段落子节点不全 range 盖段落样式，只叠缩进
- 图片：`[🖼 plainText|source|image]`
- `InlineHTML`：`<br>` → 换行；自定义空标签丢弃；其余空串
- `Strikethrough`：有专门 case，`context.striking()` 派生删除线标志下传；叶子（`renderText` / `renderInlineCode` / `renderImage`）读 `isStrikethrough` 挂 `.strikethroughStyle`。范式 A 的叶子遗漏风险见 [03 §3.2](03-principles.md)
- 代码块在本通道是 fallback；真 UI 走 `InkCodeBlock`

### `InkTextContext`（internal）

见 [03 §3.2](03-principles.md)。非公开 API。

### `InkInlineSyntax` / `InkInlineContext`

扫描 `Text` 节点产出片段。与 `InkBlockHandler` 互补（行内 vs 整块 UIView）。

### `InkAttributedTextBlock`

`UITextView` 兜底：`InkMarkdownLayoutManager`、不可编辑、可选中、不滚动。有 `linkTapHandler` 时关 `dataDetectorTypes`。

## 块路由

### `InkBlockRenderer`

遍历 children → handler 命中则 flush pending + append UIView 块；否则 pending。最后 `render(markups:)` 一次渲富文本。

### `InkBlockHandler` / `InkRenderableBlock`

```swift
public protocol InkRenderableBlock {
  func makeView() -> UIView
}
```

`makeBlock` 必须透传 `configuration`（单元格二次渲染要同一套 syntax / link handler）。

## 组件 `Rendering/Components/`

| 文件 | 职责 |
| --- | --- |
| `InkMarkdownLayoutManager` | 行内代码背景 + 引用竖线；公开 attribute key |
| `InkCodeBlockView` | 圆角灰背 + 等宽 Label |
| `InkThematicBreakBlock` | 顶线 + 下留白 |
| `InkTableBlock` | 从 `Table` 构造；`cellMarkdownText` = `children.map { $0.format() }` |
| `InkTableBlockView` | wrap / scroll 分流 |
| `InkTableRenderHelper` | 行/格/量宽/分割线/复制纯文本（tab 分隔） |
| `InkTableCellTextView` | 可点链接的只读 TextView（替代 UILabel） |
| `InkStreamTableView` | 流式逐行；`referenceRows` 预估列宽；`onHeightChange` |

> `TABLE_INTEGRATION_GUIDE.md` 的 API 已过时，以源码为准。

## 流式 `InkStreamRenderer.swift`

| 类型 | 角色 |
| --- | --- |
| `InkStreamRenderer` | 主线程 API：`bind` / `append` / `reset` / `finish`；后台解析 + DisplayLink 显示 |
| `InkIncrementalMarkdownRenderer` | 稳定边界增量 |
| `InkStreamingPerformanceBenchmark` | `@_spi(Performance)` 全量 vs 增量 |

## 想改 X 看哪里

| 想改 | 文件 |
| --- | --- |
| 默认字号 / 色 / 间距 | `InkAppearance` + `appearance_defaultValues` |
| 行高 | `applyFixedLineHeight` / `baselineOffset` |
| 样式传递 | `InkTextContext` + 03 §3.2 |
| 新块 / 新行内 | `InkBlockHandler` / `InkInlineSyntax` |
| 表格 | `InkTableBlockView` + `InkTableRenderHelper` |
| 代码块外观 | `InkCodeBlockView` |
| 引用线 / 代码底 | `InkMarkdownLayoutManager` |
| 流式 | `InkStreamRenderer` + 03 §3.7 |
