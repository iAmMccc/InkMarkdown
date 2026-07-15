# 一、项目概述

本页说明 InkMarkdown 解决什么问题、明确不做什么，以及当前公开能力的边界。需要可验证的交付状态时，直接查看[当前状态](../current-status.md)。

## 是什么

**InkMarkdown** 基于 [swift-markdown](https://github.com/swiftlang/swift-markdown)，做 Apple 平台上的 Markdown **渲染**。

- **产品范围**：UIKit — `NSAttributedString` + 块级 `UIView` + 流式
- **明确不做**：SwiftUI 渲染器；该场景由 MarkdownUI / Textual 覆盖
- **解析**：全部交给 swift-markdown，不自写 cmark

```text
Markdown 源文本
  → swift-markdown → Markup
  → InkMarkdown
      → NSAttributedString
      → UIView 块
      → 流式
```

v2 起多一步：Markup → **InkIR** →（可选 Transformer）→ 各后端。

## 定位

| 做 | 不做 |
| --- | --- |
| UIKit 优先，能嵌 `UITextView` / 列表 | WebView 主路径 |
| 固定行高、块路由、可测的流式 | 编辑器、完整 HTML、高亮引擎本体 |
| 轻量扩展点；v2 可选中端 Transformer | SwiftUI 渲染器；对外承诺 TED / O(1) 等数学口号 |
| TextKit 1 自定义绘制（库内 text view） | v1 只交 TextKit 2 |

| 对比 | 对方 | 本库 |
| --- | --- | --- |
| swift-markdown | 解析 + AST | 原生渲染层 |
| MarkdownUI / Textual | 成熟 SwiftUI | 聚焦 UIKit，不重复其产品范围 |
| [SwiftStreamingMarkdown](https://github.com/microsoft/SwiftStreamingMarkdown) | SwiftUI / 产品向流式 | UIKit 可嵌入 + 宿主扩展 |

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
| 图片 | 占位 `[🖼 …]` |
| 删除线 | 有内容，无删除线样式 |
| InkIR / Transformer | 无（v2） |
| SwiftUI | 不支持（项目范围外） |
| TextKit 2 | 非默认（试探） |

## 技术栈

- Swift 6.2+，语言模式 `.v5`
- **当前可构建目标：iOS 14+**（Package 只声明这一项）
- 当前 manifest：远程 `swiftlang/swift-markdown` **revision pin**（ADR-001）；可选本地缓存见[当前状态](../current-status.md)
- 测试：Swift Testing；快照基建在 `Tests/.../Snapshots`
- 库内富文本自定义绘制：**TextKit 1**（`InkMarkdownLayoutManager`）

完整交付状态见[当前状态](../current-status.md)。上手见
[04-development](04-development.md)，原理见 [03-principles](03-principles.md)。
