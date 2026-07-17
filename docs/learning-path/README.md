# InkMarkdown 零基础学习路径

这套教程写给这样的读者：会使用 UIKit 开发常规界面，但没有系统学习过 Markdown、语法树、`NSAttributedString` 或 TextKit。

你不需要编译原理基础，也不需要数学推导。每一章都先讲“它解决什么问题”，再看最小例子，最后才进入 InkMarkdown 源码。

本目录属于 Tutorial 系列。章节中的概念解释服务于当前练习；需要精确查 API 时，请转到 [Reference 文档](../references/README.md)。

## 10 分钟获得第一个成功结果

先不改代码，用 ExampleApp 确认项目能正常解析和显示 Markdown。有两条等价路径，任选其一：

**路径 A：手动用 Xcode（没有 AI 客户端 / MCP 工具时用这条）**

1. 双击打开 `ExampleApp/ExampleApp.xcodeproj`（或终端执行 `open ExampleApp/ExampleApp.xcodeproj`），等待 Xcode 解析完 Swift Package 依赖。
2. 确认 Scheme 选择器里选中的是 `ExampleApp`，运行目标选一个可用的 iOS 模拟器。
3. 按 Cmd-R 运行。

**路径 B：AI 编程客户端 + XcodeBuildMCP（可选，效率优化）**

1. 按[开发指南](../contributor-guide/04-development.md#运行-exampleapp)使用 XcodeBuildMCP 发现并运行 `ExampleApp/ExampleApp.xcodeproj`。

两条路径殊途同归，跑起来之后：

2. 在 App 中进入“Markdown 标准样式”→“一级标题 H1”。
3. 在渲染页和源码页之间切换，对照 `#` 源文本与标题显示结果。
4. 返回后打开“粗体”和“表格”，确认行内富文本与独立 UIKit 块都能显示。

成功标志：你能在 Simulator 中看到标题、粗体和网格表格，并能切换到对应 Markdown 源文本。如果没有成功，先按[构建与测试排查流程](../contributor-guide/04-development.md#排查常见渲染问题)修复环境，再开始第 1 章。手把手的详细步骤（含亲手调用一次渲染 API）见[第 0 章：先跑起来](00-first-run.md)。

## 学完后你能做什么

- 读懂常见 Markdown，并区分 CommonMark、GFM 和项目自定义行为。
- 看懂 swift-markdown 产生的 `Markup` 树。
- 理解 `NSAttributedString`、字符范围和 TextKit 1 的分工。
- 沿着一段 Markdown 追踪到 `NSAttributedString` 或 `UIView`。
- 理解块路由和流式渲染为什么存在。
- 使用断点和测试验证修改，完成第一次小型贡献。
- 用统一架构卡比较 swift-markdown、MarkdownUI、Textual、SwiftStreamingMarkdown 与 InkMarkdown。

## 整条路线

```mermaid
flowchart LR
  A["Markdown 写法"] --> B["CommonMark 与 GFM"]
  B --> C["Markup 树"]
  C --> D["NSAttributedString"]
  D --> E["TextKit 1"]
  E --> F["富文本渲染器"]
  F --> G["UIView 块路由"]
  G --> H["流式状态管线"]
  H --> I["调试、测试与贡献"]
  I --> J["生态对比与设计取舍"]
```

## 建议阅读顺序

| 阶段 | 章节 | 你会得到什么 | 建议用时 |
| --- | --- | --- | --- |
| 0 | [先跑起来](00-first-run.md) | 亲手用 Xcode 跑通 ExampleApp，并调用一次 `InkAttributedRenderer.render(_:)` 看到真实输出 | 20 分钟 |
| 1 | [Markdown 从哪里开始](01-markdown-foundations.md) | 能读写最常见语法，知道“标记”不是最终 UI | 45 分钟 |
| 2 | [CommonMark、GFM 与 Markup 树](02-commonmark-gfm-and-markup-tree.md) | 能把源文本画成一棵节点树 | 60 分钟 |
| 3 | [NSAttributedString 与 TextKit 1](03-nsattributedstring-and-textkit.md) | 能解释文字、样式、范围、布局的关系 | 60 分钟 |
| 4 | [完整渲染管线](04-inkmarkdown-render-pipeline.md) | 能跟踪普通段落、标题、链接的源码路径 | 100 分钟 |
| 5 | [块路由与 UIKit 装配](05-block-routing.md) | 能跟踪 handler、pending flush 和 UIView block 装配 | 50 分钟 |
| 6 | [流式 Markdown 状态管线](06-streaming-rendering.md) | 能解释稳定前缀、UTF-16 显示进度和当前实现边界 | 75 分钟 |
| 7 | [跟练：调试、测试与第一次贡献](07-guided-debugging-and-exercises.md) | 能独立定位节点、检查 attribute、验证修改 | 90 分钟 |
| 8 | [用主流库读懂项目定位](08-library-landscape-and-design-tradeoffs.md) | 能用输入、中间模型和公开输出比较 iOS Markdown 库 | 60 分钟 |
| 随时查 | [术语表](glossary.md) | 用白话快速找回陌生概念 | — |

时间只是参考。每章末尾都有“完成标准”。达到标准再继续，比一次读完更有效。

## 推荐学习方法

每章按同样的四步学习：

1. **先运行最小例子**：不要急着记术语。
2. **用自己的话复述**：能解释给另一位 UIKit 开发者，就算真正理解。
3. **画一遍数据流**：只画输入、处理者、输出，不要求精美。
4. **改一个值并验证**：例如标题颜色、行高或 handler 顺序。

遇到陌生词时先查[术语表](glossary.md)。仍然不明白，再回到该词首次出现的章节。

## 三类知识不要混在一起

| 层次 | 谁负责 | 回答的问题 |
| --- | --- | --- |
| Markdown 语法标准 | CommonMark / GFM | 这段字符应该被识别为什么结构？ |
| 解析结果 | swift-markdown | 这个结构对应哪个 `Markup` 节点？ |
| 显示策略 | InkMarkdown | 这个节点在 UIKit 中如何显示？ |

例如，GFM 规定表格如何被识别，swift-markdown 产生 `Table` 节点，InkMarkdown 再决定用独立 `UIView` 显示。表格长什么样不是 CommonMark 的规定。

## 学习时以什么为准

- 项目当前真正做到了什么：看[当前状态](../current-status.md)。
- 架构和模块职责：看[贡献者指南](../contributor-guide/README.md)。
- 每种语法的渲染契约：看[渲染语义规范](../spec/README.md)。
- swift-markdown 的具体 API：看[API 速查](../references/swift-markdown-api-guide.md)。
- 本教程负责建立理解，不替代上述状态、规范和 API 文档。

## 官方延伸资料

- [CommonMark 交互式入门](https://commonmark.org/help/tutorial/)
- [CommonMark 0.31.2 规范](https://spec.commonmark.org/0.31.2/)
- [GitHub Flavored Markdown 规范](https://github.github.com/gfm/)
- [swift-markdown](https://github.com/swiftlang/swift-markdown)
- [Apple：NSAttributedString](https://developer.apple.com/documentation/foundation/nsattributedstring)
- [Apple：TextKit](https://developer.apple.com/documentation/uikit/textkit)
- [Apple 文本系统 API 速查](../references/apple-text-system-api-guide.md)
- [iOS Markdown 库定位对比](../references/ios-markdown-ecosystem.md)

## 文档维护提示

以下变化发生时，需要复查这套教程：

- swift-markdown 升级后节点类型或解析选项变化。
- `InkAttributedRenderer`、`InkBlockRenderer` 或 `InkStreamRenderer` 的公开入口变化。
- 项目由 TextKit 1 迁移到其他正式渲染路径。
- 新增或移除默认 `InkBlockHandler`。
- 外部对比库的公开 UI 边界、解析模型或流式 API 变化。

## 学完后

- 想修改架构或渲染原理：进入[贡献者文档](../contributor-guide/README.md)。
- 想确认某种语法的预期结果：进入[渲染语义规范](../spec/README.md)。
- 想查 swift-markdown 类型：进入[依赖 API 参考](../references/README.md)。
