# 一、项目概述

## 是什么

**InkMarkdown** 基于 [swift-markdown](https://github.com/swiftlang/swift-markdown)，做 Apple 平台上的 Markdown **渲染**。

- **现在**：UIKit — `NSAttributedString` + 块级 `UIView` + 流式
- **以后**：SwiftUI — 同一中间模型（InkIR）的第二后端，见 [roadmap](../roadmap.md)
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
| 轻量扩展点；v2 可选中端 Transformer | 对外承诺 TED / O(1) 等数学口号 |
| TextKit 1 自定义绘制（库内 text view） | v1 只交 TextKit 2 |
| SwiftUI 第二后端（路线图） | 第一天对标 MarkdownUI 主题生态 |

| 对比 | 对方 | 本库 |
| --- | --- | --- |
| swift-markdown | 解析 + AST | 原生渲染层 |
| MarkdownUI / Textual | 成熟 SwiftUI | UIKit 优先；SwiftUI 后期同 IR |
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
| SwiftUI | 无（路线图） |
| TextKit 2 | 非默认（试探） |

## 技术栈

- Swift 6.2+，语言模式 `.v5`
- **iOS 14+**（Package 只声明这一项）
- 依赖：远程 `swiftlang/swift-markdown`
- 测试：Swift Testing；快照基建在 `Tests/.../Snapshots`
- 库内富文本自定义绘制：**TextKit 1**（`InkMarkdownLayoutManager`）

上手见 [04-development](04-development.md)。原理见 [03-principles](03-principles.md)。
