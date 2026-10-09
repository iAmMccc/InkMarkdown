# 一、项目概述

本页说明 InkMarkdown 解决什么问题、明确不做什么，以及当前公开能力的边界。需要可验证的交付状态时，直接查看[当前状态](../current-status.md)。

## 是什么

**InkMarkdown** 基于 [swift-markdown](https://github.com/swiftlang/swift-markdown)，做 Apple 平台上的 Markdown **渲染**。

- **已发布产品范围**：`0.0.1` 是 UIKit-first — `NSAttributedString` + 块级 `UIView` + 流式
- **v0.0.2 目标**：独立 `InkMarkdownSwiftUI` adapter product，使 SwiftUI 宿主复用 UIKit rendering engine 的语义
- **明确不做**：v0.0.2 不开发 native SwiftUI renderer；该选择留待 InkIR 成熟后评估
- **解析**：全部交给 swift-markdown，不重写 cmark

```text
Markdown 源文本
  → swift-markdown → Markup
  → InkMarkdown（UIKit rendering engine）
      → NSAttributedString
      → UIView 块
      → 流式
  → InkMarkdownSwiftUI（v0.0.2 adapter）
      → SwiftUI 宿主
```

v2 起才增加：Markup → **InkIR** →（可选 Transformer）→ UIKit / future native SwiftUI renderer。

## 定位

| 做 | 不做 |
| --- | --- |
| UIKit 优先，可嵌 `UITextView` / 列表 | WebView 主路径 |
| 固定行高、块路由、可测的流式 | 编辑器、完整 HTML、高亮引擎本体 |
| 轻量扩展点；v2 可选拆出中端 Transformer | v0.0.2 之前的 native SwiftUI renderer；对外承诺 TED / O(1) 等数学口号 |
| TextKit 1 自定义绘制（库内 text view） | v1 只交 TextKit 2 |

| 对比 | 对方 | 本库 |
| --- | --- | --- |
| swift-markdown | 解析 + AST | 原生渲染层 |
| MarkdownUI / Textual | 原生 SwiftUI 呈现 | InkMarkdown 提供 UIKit-first 输出，v0.0.2 以 adapter 接入 SwiftUI；不把“原生 SwiftUI”当作已交付能力 |
| [SwiftStreamingMarkdown](https://github.com/microsoft/SwiftStreamingMarkdown) | SwiftUI / 产品向流式 | UIKit-first output、delta 输入契约与宿主扩展；性能比较须以可复现证据为准 |

战略全文：[roadmap.md](../roadmap.md)。

## 当前能力

| 能力 | 状态 |
| --- | --- |
| 标题 / 段落 / 强调 / 链接 / 行内代码 | 有 |
| 有序 / 无序 / 任务列表 | 有 |
| 引用（左侧竖线） | 有 |
| 固定行高 | 有 |
| 代码块 / 表格 / 分割线 | 有（双通道） |
| 流式（SSE） | 有（含性能门槛测试） |
| `InkInlineSyntax` / `InkBlockHandler` | 有 |
| 图片 | 默认占位 `[🖼 …]`；opt-in 真图（[ADR-006](../decisions/ADR-006-opt-in-image-rendering.md)） |
| 删除线 | 支持 `.strikethroughStyle`；自定义 `inlineSyntaxes` 命中时不继承删除线（详见 [扩展语法](../spec/extended-syntax.md)） |
| InkIR / Transformer | 无（v2） |
| SwiftUI | v0.0.2 设计已接受；当前尚无已发布 adapter interface |
| TextKit 2 | 非默认（试探） |

## 技术栈

- Swift 6.2+，语言模式 `.v5`
- **v0.0.2 交付目标：iOS 15+、iPadOS 15+**；manifest 已收敛且已有新版 Simulator 证据，最低版本运行验证仍是 release blocker
- 当前 manifest：远程 `swiftlang/swift-markdown` **revision pin**（ADR-001）；可选本地缓存见[当前状态](../current-status.md)
- 测试：Swift Testing；快照基建在 `Tests/.../Snapshots`
- 库内富文本自定义绘制：**TextKit 1**（`InkMarkdownLayoutManager`）

完整交付状态见[当前状态](../current-status.md)。上手见 [04-development](04-development.md)，原理见 [03-principles](03-principles.md)。
