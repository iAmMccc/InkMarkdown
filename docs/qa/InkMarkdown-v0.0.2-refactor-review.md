# InkMarkdown v0.0.2 重构审查结论

> **历史快照，非当前状态。** 本文只记录 2026-08-26、HEAD `041c5ad2` 附近工作区的审查证据；文件数量、测试数量、缺陷状态和行号均不得用于判断当前工作区。当前修复状态见 [2026-08-27 审查修复记录](InkMarkdown-v0.0.2-refactor-review-resolution-2026-08-27.md) 与 [当前项目状态](../current-status.md)。

审查基线：当前工作区相对 HEAD `041c5ad2` 的全部变更（staged、unstaged、删除及 untracked）。

审查依据：[/tmp/InkMarkdown-v0.0.2-refactor-summary.md](/tmp/InkMarkdown-v0.0.2-refactor-summary.md)。该文件仅作为设计意图，以下结论均以当前代码、调用链和实际测试结果核验。

审查时间：2026-08-26；文档整理：2026-08-27。

## Findings

以下均为已确认缺陷，按严重级别排序。

### P1 — 自定义 `InkRenderableBlock` 会被 identity stamper 终止进程

- **位置**：[InkRenderableBlock.swift:89](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/Block/InkRenderableBlock.swift:89)、[InkBlockRenderer.swift:67](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/Block/InkBlockRenderer.swift:67)、[RenderedListViewController.swift:303](/Users/shizihan/DailyUse/Github/InkMarkdown/ExampleApp/ExampleApp/Detail/Pager/RenderedListViewController.swift:303)。
- **触发**：业务通过公开 `InkBlockHandler` 返回自定义 block；ExampleApp 的 `H1ActionCardBlock` 已满足此条件。
- **错误行为**：`render` 无条件调用 stamper；硬编码类型分支不认识自定义类型，执行 `preconditionFailure`，页面崩溃。
- **证据**：公开 handler 文档允许追加自定义 block，而 stamper 仅处理六种内建类型。
- **最小修正**：使用 type-erased stamped wrapper，或在协议/SPI 提供可写 identity；未知扩展类型不得 fatal，并补自定义 handler 端到端测试。

### P1 — thought 首次出现或与正文同 chunk 到达时，thought 视图不创建或不刷新

- **位置**：[InkMarkdownRenderSession.swift:181](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift:181)、[InkMarkdownCoordinator.swift:150](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift:150)。
- **触发**：视图已挂载后首次 append `<think>…`，或一个 chunk 同时包含 thought 增量/闭合标签和 answer remainder。
- **错误行为**：首次 thought 分支只 `renderer.reset`，不通知 thought；有 remainder 时只通知 `.streamText`。thought 会缺失或保持旧正文/旧高度。
- **历史证据**：display target 是互斥 enum，Coordinator 每次只刷新一个槽；当时的 mounted-view 测试曾覆盖挂载前 append 混合 chunk。该 UI 单测套件后续按项目测试策略删除，当前 UI 行为由 ExampleApp 手工验收，数据与状态由 continuity/session 关键链路测试覆盖。
- **最小修正**：使用可组合 dirty-slot 集合，同次 append 同时提交 thought/text 更新，并补先挂载后首次 thought、混合 chunk 测试。

### P1 — `cancel()` 后已显示的 thought 不会从 SwiftUI 界面移除

- **位置**：[InkMarkdownRenderSession.swift:212](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift:212)、[InkStreamMarkdownView.swift:63](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Views/InkStreamMarkdownView.swift:63)、[InkMarkdownRenderSession.swift:317](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift:317)。
- **触发**：流式 thought 可见时调用公开 `session.cancel()`。
- **错误行为**：renderer 清空 text view，但 `streamingThought = nil` 后没有 display 通知；SwiftUI 只订阅 `$isPromoted`，旧 thought 卡片继续显示。
- **证据**：现有 cancel 测试在 cancel 后手工调用 `coordinator.updateStreaming`，掩盖了公开路径缺口：[InkMarkdownP0GateTests.swift:319](/Users/shizihan/DailyUse/Github/InkMarkdown/Tests/InkMarkdownSwiftUITests/InkMarkdownP0GateTests.swift:319)。
- **最小修正**：cancel/reset 提交结构性 presentation invalidation，或让视图观察独立 presentation generation；测试不得手工驱动 Coordinator。

### P1 — 切换 session 后，复用的 thought view 仍操作旧 session

- **位置**：[InkMarkdownCoordinator.swift:115](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift:115)、[InkMarkdownCoordinator.swift:189](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift:189)。
- **触发**：同一 SwiftUI 位置从 session A 切换到 session B，二者均有 thought。
- **错误行为**：view 被复用，但 `onToggleCollapse` 和 `onReservedHeightChanged` 只在首次创建时绑定；点击 B 仍修改 A 的折叠状态，并用 A 的 identity 更新 ReservedHeight。
- **最小修正**：session 变化时重建 thought view，或每次复用都重绑当前 session/identity 闭包；增加 session replacement 测试。

### P1 — `InkMarkdownLaTeX` product 无法启用真实 iosMath renderer

- **位置**：[Package.swift:42](/Users/shizihan/DailyUse/Github/InkMarkdown/Package.swift:42)、[Package.swift:88](/Users/shizihan/DailyUse/Github/InkMarkdown/Package.swift:88)、[InkMarkdownLaTeX.swift:1](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownLaTeX/InkMarkdownLaTeX.swift:1)、[InkLaTeXImageRenderer.swift:124](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/LaTeX/InkLaTeXImageRenderer.swift:124)。
- **触发**：消费者开启 LaTeX，即使额外链接 `InkMarkdownLaTeX`。
- **错误行为**：核心 target 不依赖 iosMath，编译固定进入 stub；addon 只有注释，无法改变已编译核心。loader 最终固定抛出 `LaTeX rendering requires the iosMath module.`。
- **证据**：当前测试产物只有 `iosMath-not-imported`；真实渲染测试在该状态提前 `return`：[InkLaTeXImageRendererTests.swift:31](/Users/shizihan/DailyUse/Github/InkMarkdown/Tests/InkMarkdownTests/InkLaTeXImageRendererTests.swift:31)。
- **最小修正**：把真实 renderer/loader 放入 addon，通过核心注册 seam 注入；或恢复核心 iosMath 依赖。真实渲染测试必须失败而非提前返回。

### P1 — Mermaid 资源拆分后，核心公开路径找不到 bridge

- **位置**：[Package.swift:99](/Users/shizihan/DailyUse/Github/InkMarkdown/Package.swift:99)、[InkMermaidImageRenderer.swift:23](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/Mermaid/InkMermaidImageRenderer.swift:23)、[project.pbxproj:95](/Users/shizihan/DailyUse/Github/InkMarkdown/ExampleApp/ExampleApp.xcodeproj/project.pbxproj:95)。
- **触发**：ExampleApp 或仅链接 `InkMarkdown`/`InkMarkdownSwiftUI` 的消费者开启 Mermaid。
- **错误行为**：bridge 资源只属于未链接的 addon；反射找不到 addon class 后回退 `Bundle.main`，渲染进入 `.bundledResourceMissing`。
- **证据**：ExampleApp 依赖列表没有 `InkMarkdownMermaid`；测试却显式注入 `InkMarkdownMermaid.bundle`，未覆盖默认生产初始化器：[InkMermaidRendererTests.swift:74](/Users/shizihan/DailyUse/Github/InkMarkdown/Tests/InkMarkdownTests/InkMermaid/InkMermaidRendererTests.swift:74)。
- **最小修正**：由 addon 显式注册 `Bundle.module` 和 loader；ExampleApp/README 补 product 接入；增加默认初始化器集成测试。

### P1 — 已发布的 `InkImageBlock` public API 被源破坏

- **位置**：[InkImageBlock.swift:9](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/Image/InkImageBlock.swift:9)、[InkImageBlock.swift:41](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/Image/InkImageBlock.swift:41)。
- **触发**：0.0.1 客户把 `InkImageBlock` 当作 `UIView`，或调用 `init(source:store:rendering:)`。
- **错误行为**：类型从 `public final class …: UIView` 变为 struct；原初始化器及 UIView 行为移到新名称 `InkImageBlockView`，现有源码无法编译。
- **证据**：diff 直接替换公开类型；设计文档要求保持 UIKit public interface 可用：[08-swiftui-adapter-architecture.md:21](/Users/shizihan/DailyUse/Github/InkMarkdown/docs/contributor-guide/08-swiftui-adapter-architecture.md:21)。
- **最小修正**：保留兼容 facade/旧初始化器并标记 deprecated；否则必须按破坏性版本发布。

### P1 — 显式 Dynamic Type category 被丢弃，测试允许“完全未缩放”通过

- **位置**：[InkAttributedRenderer.swift:902](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift:902)、[InkAppearance.swift:376](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Configuration/InkAppearance.swift:376)、[InkMarkdownAccessibilityTests.swift:31](/Users/shizihan/DailyUse/Github/InkMarkdown/Tests/InkMarkdownSwiftUITests/InkMarkdownAccessibilityTests.swift:31)。
- **触发**：`contentSizeCategory = .accessibilityLarge` 且 interface style 为 `.unspecified`。
- **错误行为**：环境补全重建 configuration 时丢掉 category；`UIFontMetrics` 缩放也未使用配置 trait，显式 category 不保证改变字体或行高。
- **证据**：测试只断言 `axHeight >= largeHeight`，相等也通过。指定 trait 的 UIKit 缩放 API 见 [Apple UIFontMetrics.scaledFont(for:compatibleWith:)](https://developer.apple.com/documentation/uikit/uifontmetrics/scaledfont%28for%3Acompatiblewith%3A%29)。
- **最小修正**：保留 category，并将 `renderEnvironment.traitCollection` 传入缩放 API；测试要求字体尺寸和高度严格变化。

### P2 — 流式环境更新不刷新现存 thought view

- **位置**：[InkMarkdownRenderSession.swift:127](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift:127)、[InkMarkdownCoordinator.swift:150](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift:150)。
- **触发**：thought 已显示后调用公开 `updateRenderEnvironment`，尤其 remainder 为空。
- **错误行为**：session 内 thought 配置已变，但 renderer reset 只处理文本槽，没有 `.streamingThought` 通知；卡片保持旧字体、颜色和高度。
- **最小修正**：环境变化同时标记 thought/text 槽及 container trait snapshot；补可见 view 级测试。

### P2 — 整篇 source hash 使静态 block identity/fingerprint 复用失效

- **位置**：[InkMarkdownCoordinator.swift:45](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift:45)、[InkRenderableBlock.swift:76](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/Block/InkRenderableBlock.swift:76)、[InkAttributedTextBlock.swift:71](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/Block/InkAttributedTextBlock.swift:71)。
- **触发**：静态 Markdown 任意字符变化。
- **错误行为**：整篇 hash 改变所有 identity；fingerprint 又包含同一 epoch。未变块仍被重建、重测，图片/交互状态无法复用。
- **证据**：所谓“二次 update 复用”测试使用完全相同 markdown，实际命中 Coordinator 提前返回：[InkMarkdownPerformanceBaselineTests.swift:30](/Users/shizihan/DailyUse/Github/InkMarkdown/Tests/InkMarkdownSwiftUITests/InkMarkdownPerformanceBaselineTests.swift:30)。
- **最小修正**：把文档生命周期 epoch 与内容 hash 分开；fingerprint 只编码局部块内容，并测试修改单块时其余块指针/cache 保持不变。

### P2 — 当前严格并发构建产生 Swift 6 模式错误级诊断

- **位置**：[InkImageAttachment.swift:9](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/Image/InkImageAttachment.swift:9)、[InkImageAttachment.swift:63](/Users/shizihan/DailyUse/Github/InkMarkdown/Sources/InkMarkdown/Rendering/Image/InkImageAttachment.swift:63)。
- **触发**：Swift 6 language mode 或 warnings-as-errors。
- **风险**：当前 Swift 5 模式可构建，但编译器报告 `sending 'self' risks causing data races; this is an error in the Swift 6 language mode`，升级后直接失败。
- **证据**：非隔离 `NSTextAttachment` override 把 `@unchecked Sendable self` 捕获进 MainActor closure；本次全量构建实际产生该警告。
- **最小修正**：建立编译器可验证的 MainActor handoff，避免从非隔离回调直接发送 `self`。

### P3 — 两个明确禁止入库的试写文件仍在 untracked 集合

- **位置**：[test.swift:1](/Users/shizihan/DailyUse/Github/InkMarkdown/test.swift:1)、[scratch/test.swift:1](/Users/shizihan/DailyUse/Github/InkMarkdown/scratch/test.swift:1)。
- **触发**：`git add -A` 或打包整个源码树。
- **风险**：协议实验和手工打印脚本会进入提交；重构总结也明确要求排除。
- **最小修正**：提交前排除/移除这两个文件；本次审查未删除。

## Verification gaps

### 测试/静态审查无法签收

- 当前只验证 `InkMarkdown-Package`、iPhone 17 Pro Max、iOS 26.5：**275 passed / 0 failed / 1 skipped**。唯一 skip 是 [iOS 14 ICS 用例](/Users/shizihan/DailyUse/Github/InkMarkdown/Tests/InkMarkdownSwiftUITests/InkMarkdownP0GateTests.swift:376)。
- iOS 14–15 首次 intrinsic measurement、无宽度时的尺寸协商、旋转、Split View、宽度先布局后测量，均未在对应 runtime 验证。
- 未运行 ExampleApp；没有签收 LaTeX/Mermaid 真实页面、图片异步 ReservedHeight、表格滚动/选择、链接、Thought VoiceOver 等完整可见语义。
- 未做真机 Instruments、FPS、hitch、内存峰值、WebKit 冷启动或长会话性能验证。
- Swift 6 language mode 未运行；当前仅有编译器诊断证据。
- `apple-docs` MCP 未暴露；Dynamic Type API 使用 Apple 官方网页回退核验，需安装 `apple-doc-mcp-server` 并重载会话后补正式 MCP 核验。

### 重构总结已声明但尚未交付

[/tmp/InkMarkdown-v0.0.2-refactor-summary.md:135–145](/tmp/InkMarkdown-v0.0.2-refactor-summary.md:135)已列出但仍未交付的项目：iOS/iPadOS 14 runtime、真机 hitch/FPS、完整语义/a11y 矩阵、宽松 workload 时间预算，以及提交前清理 `test.swift`/`scratch/test.swift`。

独立全量测试数字已复跑确认，但 LaTeX 提前返回、Mermaid bundle 注入和弱 Dynamic Type 断言说明“275 passed”不能证明这些能力正确。

## Summary

- 相对 HEAD `041c5ad2`：76 个 tracked 文件变更（含 5 个删除）、14 个 untracked、0 个 staged。
- Findings：12 项；P1 × 8、P2 × 3、P3 × 1。
- 最高严重级别：P1。
- Serena 已先初始化、激活项目，并用于符号与调用链核验。
- **不建议合并**。至少先修复自定义 block 崩溃、thought 生命周期、LaTeX/Mermaid product 拆分、Dynamic Type 和 public API 破坏。
