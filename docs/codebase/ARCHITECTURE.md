# Architecture

## Core Sections (Required)

### 1) Architectural Style

- Primary style: **分层渲染管线**（parse → style config → dual-channel render）+ **策略扩展点**（block handlers / inline syntax）
- Why this classification:
  - 解析与渲染分离；解析 100% 委托 swift-markdown（`InkParser` 仅 8 行包装）
  - 渲染按“能否进入 `NSAttributedString`”分为富文本通道与 UIView 块通道
  - 流式是双通道之上的增量编排（解析缓冲 + 显示缓冲），不是第三条语义后端
- Primary constraints:
  - **UIKit only**；不做 SwiftUI 渲染器（产品决策）
  - 固定行高 + baseline 居中（混排字体一致性）
  - v1：**Markup 直接渲染**，无独立 IR（roadmap 规划 v2 `InkIR`）

### 2) System Flow

```text
Markdown source
  → optional sourceFilter (InkConfiguration)
  → InkParser.parse → Document / Markup tree (swift-markdown)
  → path A: InkAttributedRenderer (+ InkTextContext) → NSAttributedString
  → path B: InkBlockRenderer + blockHandlers → [InkRenderableBlock] → UIView
  → path C: InkStreamRenderer (append/finish) → background parse queue
             → preloadContent → CADisplayLink flush → UITextView.textStorage
```

步骤（证据）：

1. **配置**：`InkConfiguration` 聚合 appearance、inlineSyntaxes、blockHandlers、sourceFilter、linkTapHandler（`Configuration/InkConfiguration.swift`）。
2. **解析**：`InkParser.parse` → `Document(parsing:)`（`Parser/InkParser.swift`）。
3. **富文本**：`InkAttributedRenderer` 递归 Markup；样式经 `InkTextContext` **向下传递**，叶子一次生成 run；后处理只加 paragraphStyle / baselineOffset（文件头注释）。
4. **块路由**：`InkBlockRenderer` 遍历 document children；handler 命中则 flush 待渲染 markup 为 attributed block，再追加自定义 block（`Block/InkBlockRenderer.swift`）。
5. **流式**：`append` 累积 buffer（硬上限 50_000）；后台 `InkIncrementalMarkdownRenderer` 增量解析；主线程 CADisplayLink 按帧吐字（`InkStreamRenderer.swift` 架构注释）。

### 3) Layer/Module Responsibilities

| Layer or module | Owns | Must not own | Evidence |
|-----------------|------|--------------|----------|
| Parser | Markup 树获取；行分类辅助 | 样式、UIKit 布局 | `Parser/` |
| Configuration | 外观默认值、一次渲染的可插拔列表 | 解析语义、网络/图片加载 | `Configuration/` |
| AttributedString render | 固定行高、行内/块级富文本映射 | 表格网格、下载资源 | `InkAttributedRenderer.swift` |
| Block routing | 将特定 Markup 交给 handler → UIView 块 | 重写解析器 | `Block/*` |
| Components | CodeBlock / Table / ThematicBreak / LayoutManager 视图实现 | 业务导航 | `Components/` |
| Stream | 增量边界、双缓冲、主线程约束 | 持久化、网络 SSE 本身 | `InkStreamRenderer.swift` |
| ExampleApp | 演示与手动验收 | 库语义真相源 | `ExampleApp/` |

### 4) Reused Patterns

| Pattern | Where found | Why it exists |
|---------|-------------|---------------|
| Facade / thin parse wrapper | `InkParser` | 固定解析入口，便于替换测试或未来选项 |
| Strategy / Open-Closed handlers | `InkBlockHandler` + 默认 code/table/break | 宿主扩展块类型而不改核心路由 |
| Context object (downward) | `InkTextContext` | 避免“先渲染再 enumerate 覆盖”造成样式互相踩 |
| Dual-buffer streaming | parse queue + CADisplayLink display | 解析抖动与吐字动画解耦 |
| SPI for benchmarks | `@_spi(Performance) InkStreamingPerformanceBenchmark` | 性能闸门不污染常规 public API |
| Re-export | `@_exported import Markdown` | 宿主扩展 Markup 时少链一个 target |

### 5) Known Architectural Risks

- **平台声明 vs 产品决策**：目标多平台，但实现与 manifest 绑定 UIKit/iOS（见 CONCERNS / STACK Intent vs Reality）。
- **依赖升级仍需人工**：已 pin revision（ADR-001），但升级时必须重跑测试/CI。
- **大文件复杂度**：`InkStreamRenderer`（~632 LOC）、`InkAttributedRenderer`（~583 LOC）为高认知负载热点。
- **流式长度硬编码**：`maxParseLength = 50_000`，超限静默停解析 / 截断 finish。
- **v1 无 IR**：复杂语义变换只能塞进 renderer 或 sourceFilter，可测可组合性受限（roadmap v2）。

### 6) Evidence

- `Sources/InkMarkdown/InkMarkdown.swift`
- `Sources/InkMarkdown/Configuration/InkConfiguration.swift`
- `Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift`
- `Sources/InkMarkdown/Rendering/Block/InkBlockRenderer.swift`
- `Sources/InkMarkdown/Rendering/InkStreamRenderer.swift`
- `docs/contributor-guide/02-architecture.md`（设计叙述；实现以源码为准）
