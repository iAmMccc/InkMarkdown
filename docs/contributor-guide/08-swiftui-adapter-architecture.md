# 八、SwiftUI Adapter 总体技术设计（v0.0.2）

> **状态：Accepted design**
> **适用版本：v0.0.2 开发阶段**
> **相关决策：[ADR-008](../decisions/ADR-008-swiftui-adapter-architecture.md)、[ADR-009](../decisions/ADR-009-block-presentation-continuity.md)**

本文是 InkMarkdown 正式支持 SwiftUI 的总体技术设计。它定义产品范围、设计思想、依赖方向、module 划分、端到端数据流和 v0.0.2 的验收标准；具体类型、方法、状态转换和测试 fixture 由后续 module 技术文档定义。

## 1. 决策摘要

v0.0.1 是 UIKit-first 的公开 beta。v0.0.2 将把 SwiftUI 作为正式支持场景交付，但采用 **UIKit rendering engine + SwiftUI adapter**，而不是并行开发原生 SwiftUI renderer。

SwiftUI 调用者获得声明式的 view、configuration injection 和流式呈现能力；实际 Markdown 解析、富文本排版、block 路由与交互继续复用现有 UIKit implementation。这样，UIKit 与 SwiftUI 共享一套 Markdown 语义和扩展能力，而不是维护两套易漂移的 renderer。

## 2. 目标、非目标与成功定义

### 2.1 目标

1. 在 iOS 15+ 与 iPadOS 15+ 正式支持 SwiftUI 宿主。
2. 保持 UIKit 与 SwiftUI 的**渲染语义对齐**：相同 Markdown 输入、`InkConfiguration`、opt-in 能力与交互规则应得到等价结果。
3. 保持现有 UIKit public interface 与渲染行为可用；SwiftUI 是新增 product，不是替代品。
4. 为静态和流式内容提供小而稳定的 SwiftUI interface，并将复杂生命周期收进 deep module。
5. 用可复现的正确性与性能证据定义发布门槛，而非预先宣称帧率、内存或竞品优势。

### 2.2 非目标

v0.0.2 不包含：

- 原生 SwiftUI Markdown renderer；
- InkIR、Transformer 或 UIKit renderer 重写；
- macOS、tvOS、watchOS、visionOS 支持；
- 第二套 SwiftUI Theme / 样式模型；
- 网络、SSE、LLM SDK 或 `AsyncSequence` 的所有权；
- 内嵌 `ScrollView`、分页或宿主导航策略。

### 2.3 成功定义

SwiftUI adapter 的价值不是“另一种普通 Markdown view”。它应让 iOS 15+ 的 SwiftUI 宿主复用 InkMarkdown 的 UIKit-first 输出契约：`NSAttributedString`、异构 `UIView` block、可配置的 Markdown 语义和 delta 流式输入，同时保持 SwiftUI 的组合方式。

## 3. 设计思想

### 3.1 一个语义真相，多种宿主 adapter

`InkConfiguration` 与现有 UIKit renderer 是 v0.0.2 的语义真相。SwiftUI 不复制 Markdown parser、样式规则或 block 分派；它在正确的 seam 将 SwiftUI 状态转换为一次 render 所需的 configuration snapshot，并托管 UIKit 视图。

基础 CommonMark / GFM 结构始终由 `swift-markdown` 解析为 `Markup` AST。`InkThoughtScanner` 及 LaTeX / Mermaid 等 opt-in 扩展 scanner 只识别各自领域语法的边界，再把内部 Markdown 与 suffix 交回同一 `swift-markdown` 管线；它们不解释标准 Markdown，也不构成第二套 Markdown parser。

这使 UIKit rendering engine 成为 deep module：调用者只学习少量 SwiftUI interface，却可获得富文本、复杂 block、配置、生命周期与流式完成态背后的大量 implementation。复杂度集中带来 locality，复用同一语义带来 leverage。

### 3.2 语义对齐，不要求类型对称

“完整对齐”指 Markdown 语法、配置含义、opt-in 图像/公式/图表、扩展行为、链接与 block 交互、静态与流式终态结果对齐。

它不要求 SwiftUI 调用者接收每一个 UIKit 类型，也不要求 UIKit callback 原样暴露给 SwiftUI。adapter 应把宿主相关类型转换为等价的 SwiftUI 交互语义；已有 UIKit `InkConfiguration` 扩展仍必须可以穿过 adapter 生效。

### 3.3 宿主拥有业务，库拥有渲染会话

应用拥有网络连接、LLM/SSE 协议、重试和业务状态。库不接管这些职责。

**渲染会话**拥有单条流式 Markdown 的 canonical source、解析/显示阶段、终止、取消与重置，并持有该流式呈现周期的 continuity context lifetime。SwiftUI adapter 绑定该会话；它不是业务 ViewModel，也不持有应用 transport。

**Block Presentation Continuity module** 拥有当前呈现周期内的 block lineage 与 live presentation state。render session 不再与 block、UIView 各自保存一份交互状态；具体 seam 见 [module 技术设计](11-block-presentation-continuity.md)。

### 3.4 屏幕由宿主组合

基础 SwiftUI Markdown view 是非滚动内容 view。宿主决定 `ScrollView`、List、聊天气泡、分页、导航和自动滚动；adapter 负责根据可用宽度给出内容尺寸并维护 UIKit child view 生命周期。该职责分配避免双滚动状态和 iPad 宽度变化时的布局泄漏。

### 3.5 性能是证据，不是口号

UIKit bridge 不天然快于 native SwiftUI；native SwiftUI 也不天然更省内存。对于高频 delta 流式和现有异构 UIKit block，adapter 复用既有、已测试的 TextKit / UIKit 渲染路径，而不是并行建设第二个 renderer；对短小静态内容，桥接可能产生额外测量和布局开销。所有性能结论必须来自同语义 workload 的真机或 Simulator 基线与回归测试。

## 4. 产品与 module 划分

```text
SwiftUI application
        │
        ▼
InkMarkdownSwiftUI product
  ├─ 静态呈现 adapter
  ├─ 流式呈现 adapter
  ├─ block presentation continuity
  ├─ configuration / environment adapter
  └─ UIKit-host lifecycle / measurement adapter
        │  单向依赖
        ▼
InkMarkdown product
  ├─ Parser（swift-markdown → Markup）
  ├─ Configuration / Appearance
  ├─ Attributed renderer（NSAttributedString / TextKit 1）
  ├─ Block renderer（InkRenderableBlock → UIView）
  └─ Stream renderer（增量解析与显示）
        │
        ▼
swift-markdown
```

### 4.1 `InkMarkdown`：UIKit rendering engine

该 product 保持 UIKit-first。它继续是解析、配置、富文本、block 和流式 rendering implementation 的唯一来源；不得反向 import SwiftUI。v0.0.2 不以“抽取 Core 文件数”为目标，也不以条件编译把 SwiftUI interface 混入这个 product。

### 4.2 `InkMarkdownSwiftUI`：正式 presentation adapter

该 product 单向依赖 `InkMarkdown`，向 SwiftUI 宿主提供静态 view、流式 view、configuration injection 和交互桥接。它通过 adapter 内部 continuity module 管理 block lineage、live presentation state、view reuse、尺寸失效和 attachment 生命周期，不另建 Markdown renderer。

独立 product 形成真实 seam：UIKit 调用者不会被 SwiftUI dependency 污染；未来若 InkIR 支持 native SwiftUI renderer，内部 implementation 可以演进而不让 SwiftUI 调用者重新学习核心 interface。

### 4.3 测试与示例 module

SwiftUI adapter 必须有独立验证 surface 和 ExampleApp 展示入口。UI 与布局逻辑通过 ExampleApp 关键用例手工检查；自动化只保留 identity、state、promotion 和 lifecycle 的关键链路，不重复 UIKit renderer 的内部测试，也不绑定 private maps 或具体 UIView identity。

## 5. 整体实现流

### 5.1 静态 Markdown

```text
SwiftUI input + Environment
  → resolved configuration snapshot
  → InkBlockRenderer
  → [InkRenderableBlock]
  → Block Presentation Continuity reconcile
  → atomic apply plan
  → UIKit host container
  → SwiftUI layout measurement
```

- 配置 snapshot 是一次 render 的唯一输入；不能同时把全局 mutable appearance、Environment 与 Coordinator cache 当作独立真相。
- 内容或影响语义的配置变化必须进入相同的更新判定；不能只比较 Markdown 字符串。
- adapter continuity module 按严格 lineage evidence reconcile blocks；用户状态连续是契约，UIView 复用是可丢弃优化。container 只执行 apply plan 与 geometry，不再建立第二份 identity truth。
- 测量按 lineage、slot revision、宽度与 environment signature 复用；`sizeThatFits` / `intrinsicContentSize` / `layoutSubviews` 共用同一测量结果，禁止在 `layoutSubviews` 内 `invalidateIntrinsicContentSize`。

### 5.2 流式 Markdown

```text
Application transport
  → render session (delta / finish / cancel / reset)
  → InkThoughtScanner.splitStreamingSource(currentText)
       ├ PREFIX 思考标签 → InkThoughtBlockView（identity-stable apply）
       └ remainder → InkStreamRenderer + bound UITextView
  → visible streaming text（vertical stack: [thoughtView?][textView]）
  → completed render
  → InkBlockRenderer promotion（semantic blocks，不携带 presentation identity）
  → continuity reconcile（Thought lineage / live state 必须延续；UIView adopt 可选）
  → final UIKit block container（不 re-parse）
```

- render session 是 canonical source authority；`currentText` 为 SSOT，renderer 缓冲仅为 remainder 派生，不得各自截断或保存不一致版本。
- PREFIX 思考标签在流式阶段即进入 continuity module；用户折叠态写入当前 lineage 的 live presentation state。promotion 通过明确 lineage evidence 迁移状态，不要求沿用同一个 UIView，也不再手工把 view 状态复制进 `session.blocks`。
- Chat 终态将 **同一会话实例** 挂到 `messages[].renderSession`，UI 仍用 `InkStreamMarkdownView(session:)`，**不得**切换为无 session 写回的 blocks 快照或 re-parse `content` 字符串。
- “输入结束”“解析完成”“显示完成”“终态 block 可交互”是不同语义状态，必须被建模与测试，不能用一个布尔值掩盖。
- 流式阶段与终态 block 阶段使用同一 resolved configuration snapshot 的语义；主题或宽度改变的刷新策略必须在会话内可解释。
- adapter 的 attachment / detachment 是会话生命周期的一部分，重复 mount、controller 替换、取消与 reset 不得遗留 callback、display driver 或 UIKit view；`onDisplayUpdate` 回调须链式转发，不得覆盖宿主已注册的回调。

### 5.3 配置、交互与 trait 变化

```text
InkConfiguration / InkAppearance
  + SwiftUI Environment / trait input
  → resolved, view-scoped snapshot
  → static renderer or render session
```

- `InkConfiguration` 是完整的扩展 interface：source filter、行内语法、block handler、链接处理和 opt-in 能力都必须能被 SwiftUI 调用者配置。
- Environment 是便利 injection seam，不是新的 Theme 真相；v0.0.2 不增加第二套样式协议。
- 动态类型、颜色方案、可用宽度和 iPad 尺寸变化属于 render input。它们不结束 block continuity；module 保留 lineage 与 live state，按需更新 UIView 并失效 measurement。具体规则见 [Block Presentation Continuity module 技术设计](11-block-presentation-continuity.md)。

## 6. MVVM 与 Clean Architecture 约束

InkMarkdown 是渲染库，不应把宿主应用的业务模型伪装成库内 ViewModel。

- SwiftUI adapter 处于 presentation 层；其 observable state 只描述渲染会话与 view 呈现。
- UIKit rendering engine 是被 adapter 调用的 framework implementation，不依赖 SwiftUI、网络或应用业务对象。
- 应用 transport 位于库外；它通过 render-session interface 驱动呈现。
- 配置、解析、rendering 与宿主生命周期的依赖方向始终从 SwiftUI product 指向 UIKit product，而不反向泄漏。

这不是教条式分层：目标是让一个 bug 的知识、修复和验证停留在对应 module，获得 locality；让同一 renderer 语义服务 UIKit 与 SwiftUI，获得 leverage。

## 7. iOS 15 / iPadOS 15 兼容策略

支持范围仅为 iOS 15+ 与 iPadOS 15+。Apple 的 `UIViewRepresentable` 可用于该范围，但其 `sizeThatFits` 仅在 iOS/iPadOS 16+ 可用。

因此 adapter 必须把平台可用性收敛在 compatibility implementation：

- iOS/iPadOS 16+ 使用 SwiftUI 提供的尺寸协商；
- iOS/iPadOS 15 优先使用容器与 window 宽度进行 UIKit 固有尺寸协商；仅在 detached 且宽度未知时使用受可用性隔离的主屏宽度兜底；
- 颜色与 trait 转换使用 availability-safe 路径；
- view 清理使用 `UIViewRepresentable` 生命周期提供的 teardown seam；
- iPad Split View、旋转、Dynamic Type 与多次 attach/detach 都是正式验证场景。

这里定义兼容性原则，不锁定具体代码结构。Apple 官方可用性证据：[`UIViewRepresentable.sizeThatFits`](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/sizethatfits(_:uiview:context:))（iOS/iPadOS 16+）、[`Color.init(uiColor:)`](https://developer.apple.com/documentation/swiftui/color/init(uicolor:))（iOS/iPadOS 15+）、[`dismantleUIView`](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/dismantleuiview(_:coordinator:))（iOS/iPadOS 13+）。

## 8. 性能与正确性验证策略

### 8.1 正确性先于性能

任何性能比较必须先确认语义等价：相同 Markdown、字体、宽度、insets、opt-in 配置和交互行为。功能缺失不能被当作性能优势。

### 8.2 必测 workload

- 静态短文、长文、嵌套列表/引用、代码块、表格、图片/公式/图表；
- delta 流式、未闭合语法、突发 chunk、`finish → promotion`、`reset → reuse`、取消和重新绑定；
- 配置、颜色方案、Dynamic Type、可用宽度与 iPad Split View 变化；
- UIKit 与 SwiftUI 宿主的链接、复制、表格和代码块交互；
- VoiceOver 与文本选择等可访问性行为。

上述 workload 是发布验证范围，不等于为每个组合新增自动化测试。Block continuity 的 UI 行为使用 ExampleApp 手工检查，数据与状态只保留 module 文档定义的关键链路自动化测试。

### 8.3 指标

发布前建立并保存：首次可见延迟、chunk-to-visible 延迟、finish-to-block-ready 延迟、p50/p95/p99 帧时间、hitch、主线程/后台 CPU、峰值内存、allocation、布局测量次数和最终渲染一致性。v0.0.2 的 gate 是自身基线不回归，不是未经复现的竞品排名。

## 9. v0.0.2 实施阶段与退出标准

| 阶段 | 范围 | 完成标准 |
| --- | --- | --- |
| A. Product foundation | 新增独立 SwiftUI product、ADR、设计文档、公开范围与测试入口 | 依赖方向可编译；文档明确当前 beta 与目标交付的区别 |
| B. Static semantics | 静态 adapter、完整 configuration 传播、尺寸/生命周期策略 | UIKit/SwiftUI 语义矩阵通过；iOS 15 与 iPad 场景通过 |
| C. Streaming session | render session、流式 adapter、终态 promotion、取消/reset | 状态机、重复绑定、结束与重置测试通过；无来源分叉 |
| D. Release evidence | ExampleApp、可访问性、性能基线、README/状态/路线更新 | v0.0.2 的所有 release blocker 有可复现证据 |

## 10. 后续 module 文档的职责

本设计刻意不规定具体 type、方法或缓存算法。实现阶段至少应分别补充：

1. [Block Presentation Continuity module](11-block-presentation-continuity.md)；
2. SwiftUI static presentation adapter；
3. render-session 与 streaming presentation adapter；
4. configuration / Environment resolution；
5. iOS 15 layout and lifecycle compatibility；
6. SwiftUI 验证矩阵、性能基线与 ExampleApp 验收。

这些文档必须遵守本文的产品范围、依赖方向和语义真相；若需改变其中任一项，应先更新 ADR，而不是以局部补丁绕开设计。

## 11. 延后决策

以下事项不属于 v0.0.2：native SwiftUI renderer、InkIR/Transformer、跨平台 renderer、SwiftUI Theme 生态、网络 transport adapter。待出现第二个 renderer adapter 或 InkIR 后，再用实际变化需求判断新 seam 是否具有足够 depth 与 leverage。
