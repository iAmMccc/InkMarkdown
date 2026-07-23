# 二、架构设计

本文介绍解析、富文本、块路由和流式渲染的分层设计，以及自定义扩展点的边界。

解析使用 swift-markdown。渲染分为两条路径：可包含在富文本中的元素使用 `NSAttributedString`，独立块元素使用 `UIView`。流式渲染基于这两者提供增量更新与双缓冲机制。

版本演进（见 [roadmap](../roadmap.md)）：v2 会在解析与渲染之间引入 **InkIR + 可选 Transformer**，方便组合与测试复杂语义变换。渲染后端仍然基于 UIKit。v1 保持由 Markup 直接渲染。

文本绘制默认使用 **TextKit 1**（`InkMarkdownLayoutManager`）。

## 分层设计

| 层级 | 主要类型 |
| --- | --- |
| 接入层 | `InkAttributedRenderer`、`InkBlockRenderer`、`InkStreamRenderer` / `InkStreamTableView` |
| 配置层 | `InkConfiguration`、`InkAppearance` |
| 解析层 | `InkParser`、`InkLineClassifier` → `Document` / `Markup` |
| 富文本层 | `InkAttributedRenderer` + `InkTextContext` → `InkMarkdownLayoutManager` |
| 块路由层 | `InkBlockRenderer` + Handlers → CodeBlock / Table / ThematicBreak |

各层间仅传递：`Document` / `Markup` / `NSAttributedString` / `InkRenderableBlock`。

## 双通道渲染

| 通道 | 产物 | 典型元素 |
| --- | --- | --- |
| 富文本 | `NSAttributedString` → `InkAttributedTextBlock` | 标题、段落、列表、引用、行内元素 |
| 块路由 | `InkRenderableBlock` → `UIView` | 表格、代码块、分割线 |
| 块渲染流程： | | |

1. 遍历 `document.children`
2. 按注册顺序调用 `blockHandlers.canHandle`
3. 命中 handler 时：先刷新已积攒的富文本，再生成 `UIView` 块
4. 未命中时：存入 `pendingMarkup`，最后通过 `InkAttributedRenderer.render(markups:)` 一次性渲染

`render(markups:)` 直接接收 `[Markup]`，避免 AST 转为字符串后再重解析。

内置 handler 包含：`InkCodeBlockHandler`、`InkTableBlockHandler(layoutMode:)`、`InkThematicBreakHandler`。新增或覆盖块组件时注册对应 handler 即可，无需修改核心代码。

## 源码目录结构

| 路径 | 职责 |
| --- | --- |
| `InkMarkdown.swift` | 导出接口 `@_exported import Markdown` |
| `Parser/` | `InkParser`、`InkLineClassifier`（流式行分类） |
| `Configuration/` | `InkConfiguration`、`InkAppearance` |
| `Rendering/AttributedString/` | 富文本递归渲染 |
| `Rendering/Block/` | 块路由与 `InkRenderableBlock` |
| `Rendering/Components/` | LayoutManager、代码块/表格/分割线/流式表格视图 |
| `Rendering/InkTextContext.swift` | 行内样式 context（internal） |
| `Rendering/InkInlineSyntax.swift` | 行内语法自定义扩展点 |
| `Rendering/InkStreamRenderer.swift` | 流式渲染、增量解析与性能基准 |

## 数据流 (`InkBlockRenderer.render`)

1. 宿主可选配置 `sourceFilter`
2. `InkParser` 生成 `Document`
3. 遍历子节点：命中 handler 生成 `UIView` 块，未命中则放入 pending
4. 将 pending 传给 `InkAttributedRenderer.render(markups:)` 生成 `InkAttributedTextBlock`

## 自定义扩展点

| 扩展点 | 类型 | 配置项 |
| --- | --- | --- |
| 自定义行内语法 | `InkInlineSyntax` | `inlineSyntaxes` |
| 自定义块级组件路由 | `InkBlockHandler` | `blockHandlers` |
|源码预处理 | `(String) -> String` | `sourceFilter` |
| 链接点击回调 | `(URL, UIView) -> Bool` | `linkTapHandler`（返回 `true` 表示已处理） |
| 样式配置 | `InkAppearance` | `appearance` / `shared` |

### 当前版本 vs v2 架构

| 时机 | 机制 | 适用场景 |
| --- | --- | --- |
| 解析前 | `sourceFilter` | 修改原始文本字符串 |
| 渲染行内 | `InkInlineSyntax` | 单端轻量语法解析（如简单的 `@` 标识） |
| 渲染块 | `InkBlockHandler` | 将整块替换为 `UIView` |
| 点击交互 | `linkTapHandler` | 拦截与处理链接 |
| **v2 渲染前** | **`InkTransformer`（IR）** | 复杂多规则变换、需组合与单测的树结构操作 |

简单规则使用前四项扩展点即可。规则较多或需要单独测试语义变换时，使用 Phase B 规划的 IR 转换架构。

## 实现约束

1. 解析与渲染分离：v1 消费 `Markup`，v2 消费 `InkIR`。
2. 新增块类型使用 handler 扩展（v2 支持扩充 IR 分支与 Transformer）。
3. 样式统一定义在 `InkAppearance` 中。
4. 样式通过 context 向下传递，禁止之后通过 `enumerate` 修改覆盖（见 [03](03-principles.md)）。
5. 默认无外层水平边距（`blockInsets = .zero`）。
6. 渲染引擎使用 TextKit 1，暂不依赖 TextKit 2。
