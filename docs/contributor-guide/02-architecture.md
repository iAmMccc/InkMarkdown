# 二、架构设计

本页解释解析、富文本、块路由和流式渲染怎样分层，以及扩展点为什么位于这些边界。

解析交给 swift-markdown。渲染分两条路：能塞进富文本的走 `NSAttributedString`，塞不进去的走 `UIView` 块。流式是前两者的增量版，外加双缓冲。

演进（见 [roadmap](../roadmap.md)）：v2 在解析和渲染之间插入
**InkIR + 可选 Transformer**，用于让复杂语义变换可组合、可测试。渲染后端仍然只有 UIKit。v1 仍是 Markup 直接渲染。

文本绘制默认 **TextKit 1**（`InkMarkdownLayoutManager`），不是 TextKit 2。

## 分层

| 层 | 主要类型 |
| --- | --- |
| 接入 | `InkAttributedRenderer`、`InkBlockRenderer`、`InkStreamRenderer` / `InkStreamTableView` |
| 配置 | `InkConfiguration`、`InkAppearance` |
| 解析 | `InkParser`、`InkLineClassifier` → `Document` / `Markup` |
| 富文本 | `InkAttributedRenderer` + `InkTextContext` → `InkMarkdownLayoutManager` |
| 块路由 | `InkBlockRenderer` + Handlers → CodeBlock / Table / ThematicBreak |

层之间只传：`Document` / `Markup` / `NSAttributedString` / `InkRenderableBlock`。

## 双通道

| 通道 | 产物 | 典型元素 |
| --- | --- | --- |
| 富文本 | `NSAttributedString` → `InkAttributedTextBlock` | 标题、段落、列表、引用、行内 |
| 块路由 | `InkRenderableBlock` → `UIView` | 表格、代码块、分割线 |

块渲染大致是：

1. 遍历 `document.children`
2. 按注册顺序问 `blockHandlers.canHandle`
3. 命中 → 先 flush 已攒的富文本，再产出 UIView 块
4. 未命中 → 攒进 `pendingMarkup`，最后 `InkAttributedRenderer.render(markups:)` 一次渲完

`render(markups:)` 直接吃 `[Markup]`，避免 AST → 字符串 → 再解析。

内置 handler：`InkCodeBlockHandler`、`InkTableBlockHandler(layoutMode:)`、`InkThematicBreakHandler`。加新块或覆盖旧块：注册 handler 即可，不必改核心。

## 源码地图

| 路径 | 职责 |
| --- | --- |
| `InkMarkdown.swift` | `@_exported import Markdown` |
| `Parser/` | `InkParser`、`InkLineClassifier`（流式行分类） |
| `Configuration/` | `InkConfiguration`、`InkAppearance` |
| `Rendering/AttributedString/` | 富文本递归渲染 |
| `Rendering/Block/` | 块路由 + `InkRenderableBlock` |
| `Rendering/Components/` | LayoutManager、代码块/表格/分割线/流式表 |
| `Rendering/InkTextContext.swift` | 行内样式 context（internal） |
| `Rendering/InkInlineSyntax.swift` | 行内扩展点 |
| `Rendering/InkStreamRenderer.swift` | 流式 + 增量解析 + SPI 基准 |

## 数据流（`InkBlockRenderer.render`）

1. 宿主可选跑 `sourceFilter`
2. `InkParser` → `Document`
3. 对每个 child：handler 命中则出 UIView 块，否则进 pending
4. pending 交给 `InkAttributedRenderer.render(markups:)` → `InkAttributedTextBlock`

## 扩展点

| 点 | 类型 | 挂在哪 |
| --- | --- | --- |
| 行内语法 | `InkInlineSyntax` | `inlineSyntaxes` |
| 块路由 | `InkBlockHandler` | `blockHandlers` |
| 源预处理 | `(String) -> String` | `sourceFilter` |
| 链接点击 | `(URL, UIView) -> Bool` | `linkTapHandler`（`true` = 已处理） |
| 样式 | `InkAppearance` | `appearance` / `shared` |

### 现在 vs v2

| 时机 | 机制 | 适合 |
| --- | --- | --- |
| 解析前 | `sourceFilter` | 改原始字符串 |
| 渲染行内 | `InkInlineSyntax` | 单端、扫纯文本（如简单 @） |
| 渲染块 | `InkBlockHandler` | 整块换成 UIView |
| 点击 | `linkTapHandler` | 拦截链接 |
| **v2 渲染前** | **`InkTransformer`（IR）** | 多规则语义、可组合变换、可单测改树 |

规则少：上面四项够用。多规则或需要独立测试语义变换：使用路线图 Phase B 的中端。

## 实现约束

1. 解析与渲染分开：v1 消费 `Markup`；v2 消费 InkIR
2. 新块类型 = 新 handler（v2 也可新 IR case + Transformer）
3. 样式集中在 `InkAppearance`
4. 样式用 context 下传，禁止事后 `enumerate` 覆盖（见 [03](03-principles.md)）
5. 默认不占屏幕水平边距（`blockInsets = .zero`）
6. 库内自定义文本绘制走 TextKit 1；不把 TK2 当 v1 交付前提
