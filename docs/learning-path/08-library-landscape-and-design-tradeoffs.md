# 第 8 章：用主流库读懂 InkMarkdown 的定位

**难度**：初中级  
**预计时间**：60 分钟

本章带你用同一套问题阅读五个 Markdown 库。完成后，你能区分解析器、渲染器、公开 UI 边界和流式管线，不再只用“支持 Markdown”判断两个库是否重复。

## 本章目标

学完后，你可以：

- 为一个 Markdown 库画出“输入 → 中间模型 → 公开输出”。
- 解释 swift-markdown 为什么是解析层，而不是 UIKit 渲染器。
- 区分 MarkdownUI、Textual 与 InkMarkdown 的公开 UI 边界。
- 说明“内部使用 `UITextView`”和“向 UIKit 宿主公开 API”的区别。
- 根据项目场景选择需要的类型，而不是背库名。

## 前置知识

先完成[第 7 章](07-guided-debugging-and-exercises.md)，或至少能解释 `Markup`、`NSAttributedString`、SwiftUI `View` 和 `UIView` 的区别。对比中的外部事实统一来自 [iOS Markdown 库定位对比](../references/ios-markdown-ecosystem.md)。

## 8.1 不要从功能列表开始

“支持标题、链接和表格”无法说明一个库适合放在哪层。先为它填一张架构卡：

```text
输入：Markdown 字符串还是已解析数据？
解析：谁识别 CommonMark / GFM？
中间模型：Markup 树、AttributedString，还是其他模型？
公开输出：SwiftUI View、NSAttributedString，还是 UIView？
更新方式：整体重算还是面向流式？
```

这五项能直接显示库之间是上下游关系、交叉关系，还是真正重复。

## 8.2 先画公开数据流

下图只保留宿主最需要知道的输入和输出。

```mermaid
flowchart TD
  M["Markdown 源文本"]
  M --> SM["swift-markdown"]
  SM --> AST["Document / Markup 树"]

  M --> MUI["MarkdownUI"]
  MUI --> SV1["SwiftUI Markdown view"]

  M --> TXT["Textual"]
  TXT --> AS["Swift AttributedString + PresentationIntent"]
  AS --> SV2["InlineText / StructuredText"]

  M --> SSM["SwiftStreamingMarkdown"]
  SSM --> SV3["SwiftUI 流式入口\n段落内部可用 UITextView"]

  AST --> INK["InkMarkdown"]
  INK --> NS["NSAttributedString"]
  INK --> UV["InkRenderableBlock / UIView"]
```

这张图显示 swift-markdown 可以是 InkMarkdown 的上游，而 MarkdownUI 和 Textual 主要服务 SwiftUI 显示。它们都处理 Markdown，但不在同一个公开边界上交付结果。

## 8.3 逐张填架构卡

使用参考页填写下表，不需记忆所有类型名。

| 库 | 你应先记住什么 | 不要误解为什么 |
| --- | --- | --- |
| swift-markdown | 产出可遍历、改写的 `Markup` 树 | 它不决定 UIKit 外观 |
| MarkdownUI | 向 SwiftUI 交付只读 Markdown view 和分层主题 API | 它不返回 InkMarkdown 需要的 UIKit block 数组 |
| Textual | 是 SwiftUI 文本引擎，Markdown 是其中一种 parser | 它不是 swift-markdown `Markup` 渲染后端 |
| SwiftStreamingMarkdown | 面向 LLM 的 SwiftUI 流式产品管线 | 内部用 `UITextView` 不等于公开 UIKit 库边界 |
| InkMarkdown | 用 `Markup` 生成 UIKit 富文本和独立块 | 它不提供 SwiftUI 渲染器 |

## 8.4 区分三组容易混淆的话

这三组概念决定了你能否看懂项目定位。

### 解析器与渲染器

解析器回答“这些字符是什么结构”。渲染器回答“这个结构怎样显示”。swift-markdown 与 InkMarkdown 分别负责这两层。

### 内部实现与公开边界

一个 SwiftUI 库可以在内部包装 `UITextView`，但 UIKit 宿主仍然不一定能直接拿到 `NSAttributedString`、替换 block handler 或组装自定义 `UIView`。讨论“是否支持 UIKit”时，必须说清是内部实现还是公开 API。

### 网络分片与增量语义

能够接收逐步变长的文本，不代表库会缓存稳定前缀或精确替换受影响后缀。比较流式库时，还要查输入是 chunk 还是完整快照，以及最终结果如何收口。

## 8.5 把对比用回 InkMarkdown

外部库最有价值的作用是帮你看见可选的边界，而不是复制 API。

| 看到的设计 | 对 InkMarkdown 的意义 |
| --- | --- |
| swift-markdown 的结构化树与 Walker / Rewriter | 保持解析层独立，不用渲染器重写 CommonMark |
| MarkdownUI 分开行内和块样式 | 审视 `InkAppearance` 时区分字符属性与块布局 |
| Textual 的可组合 `TextProperty` 与统一 Style | 为未来 Theme 组合提供参考，但保留 UIKit 可用类型 |
| SwiftStreamingMarkdown 的专用流式入口 | 将流式视为独立状态管线，不只是多次调用静态 renderer |

这些只是设计参考。项目当前已交付什么，仍以[当前状态](../current-status.md)和测试为准。

## 8.6 动手练习

这组练习要求你说出选择理由，而不是只写库名。

### 练习 A：填架构卡

从 [iOS Markdown 库定位对比](../references/ios-markdown-ecosystem.md) 选两个库，分别写出输入、中间模型、公开输出和更新方式。

### 练习 B：为场景选边界

为下列场景选择“需要的类型”，再查找符合边界的库：

1. iOS 14 UIKit 项目需要把结果放入现有 `UITableViewCell`，并自定义表格 `UIView`。
2. SwiftUI 项目需要只读 GFM 文档和主题定制。
3. 工具只需统计 Markdown 中的链接，不显示 UI。
4. SwiftUI 聊天页需要针对 LLM 的流式显示与数学公式。

参考思路依次是：UIKit 富文本与 block 边界、SwiftUI Markdown view、Markup 遍历、SwiftUI 流式管线。

### 练习 C：追溯一条结论

在对比页中选择一条外部结论，点开对应仓库来源，找到支持结论的 README、DocC 或源码。这一步能防止把二手摘要当成永不变的 API 契约。

## 完成标准

你能用自己的话回答以下问题即可：

- swift-markdown 与 InkMarkdown 是重复库，还是上下游？
- MarkdownUI 的主题 API 为什么值得参考，却不能直接替代 UIKit 输出？
- 一个库内部使用 `UITextView`，为什么不足以证明它提供 UIKit 公开边界？
- 比较两个流式库时，除了帧率还要问哪些语义问题？

## 下一步

- 读[项目概述](../contributor-guide/01-overview.md)，用本章的五个问题复核 InkMarkdown 的定位。
- 读[路线图](../roadmap.md)，区分已交付能力与受外部库启发的未来设计。
- 开始修改代码前，按[开发指南](../contributor-guide/04-development.md)建立可重复的构建和测试环境。
