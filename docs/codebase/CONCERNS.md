# Codebase Concerns

## Core Sections (Required)

### 1) Top Risks (Prioritized)

| Severity | Concern | Evidence | Impact | Suggested action |
|----------|---------|----------|--------|------------------|
| ~~High~~ Done | ~~依赖跟踪 `branch: main`~~ | `Package.swift` 已 `revision:`；`Package.resolved` 无 branch 字段 | 可重复构建已改善 | 升级时显式修改 revision 并测试 |
| ~~High~~ Done | ~~无 CI~~ | `.github/workflows/ci.yml` | PR/push 自动 iOS 测试 | 监控 runner/模拟器可用性 |
| Med | 平台决策 vs manifest | `AGENTS.md` 目标矩阵；v1 仅 iOS（ADR-002） | 文档范围过大会导致误导 | 对外只宣称 iOS 14+ |
| Med | 流式 `maxParseLength = 50_000` 硬编码 | `InkStreamRenderer.swift:147`；ADR-005 | 超长 SSE 静默截断 / 停解析 | 配置化 + 文档契约 + 测试 |
| Med | 语义测试矩阵未完成 | `current-status.md`、仅 snapshot scaffold | 语法回归靠手测 | 在 `RenderSnapshot` 上补全 CommonMark/GFM 契约 |
| Med | ExampleApp SSE 未闭合块的全量重解析 | `SSEChatViewController` 按 chunk 节流重建 segments | 长回答 CPU / 文本段闪烁；generated 块已按 identity 复用；**文本段已按前缀复用**（`reusableTextSegments` + `updateFullText`），行内 attachment 不再每轮销毁 | 可继续收紧「仅尾部文本增长时跳过全量 rebuild」 |
| Low | 无 root linter/formatter | scan | 风格漂移 | 按需引入 SwiftFormat/SwiftLint |
| Low | 传递依赖 `swift-cmark` 仍为 branch+revision | `Package.resolved` | 随 markdown pin 间接固定，但非直接声明 | 可接受；如需锁定可监控 resolved |

### 2) Technical Debt

| Debt item | Why it exists | Where | Risk if ignored | Suggested fix |
|-----------|---------------|-------|-----------------|---------------|
| 删除线：内容保留但未做 GFM strikethrough 样式 | 行内 switch 无 `Strikethrough` 专用分支（default 透传） | `InkAttributedRenderer.renderInline` | 无法正常显示 `~~del~~` 样式 | 明确 v1 契约或补充样式与测试 |
| 图片默认占位 vs opt-in 期望 | ADR-004 默认占位；ADR-006 opt-in 真图已实现，文档曾滞后 | `renderImage`、`Rendering/Image/` | 宿主误判「库永不加载图片」或不知开启方式 | 文档已对齐 ADR-006；宿主按需配置 `isEnabled` 与 `ImageSecurityPolicy` |
| 过时 TABLE 指南仍在树内 | 历史保留文件 | `Components/TABLE_INTEGRATION_GUIDE.md`（已 exclude） | 容易误导 API 使用 | 入口已标注警告，可移出 Sources 或标记 deprecated |
| ExampleApp TODO | 演示未完全切到库渲染器 | `MarkdownDetailViewController.swift:137` | 示例与库实际能力不一致 | 跟进 example plan 或删除过时 TODO |
| 本地缓存仍是可选路径 | ADR-001：默认 revision，不默认 path | `Packages/` vs `Package.swift` | 离线开发需手动改 path | 文档说明可选流程即可 |
| 大文件 | 流式与富文本渲染逻辑过于集中 | `InkStreamRenderer` ~632 LOC；`InkAttributedRenderer` ~583 LOC | 变更容易引发冲突与回归 | 按增量与块访问器重构拆分 |

### 3) Security Concerns

| Risk | OWASP category (if applicable) | Evidence | Current mitigation | Gap |
|------|--------------------------------|----------|--------------------|-----|
| 恶意 Markdown / 超大输入 | A04 / resource exhaustion | 流式 50k 上限；无 HTML 执行 | 限制输入长度，丢弃内联 HTML | 非流式路径无长度限制，缺少统一 DoS 防御策略 |
| 链接点击打开任意 URL | A01 宿主侧 | `linkTapHandler` 可选 | 由宿主决定是否拦截 | 默认交给系统，宿主需要自行校验 URL |
| 密钥泄露 | N/A | 无服务端密钥 | 无密钥存储 | — |
| 依赖供应链 | A06 | 直接依赖锁定 revision，传递 cmark 锁定 gfm+revision | Package.resolved | 缺少 Dependabot / 安全配置文件 |

### 4) Performance and Scaling Concerns

| Concern | Evidence | Current symptom | Scaling risk | Suggested improvement |
|---------|----------|-----------------|-------------|-----------------------|
| 全量重解析退化 | 性能测试闸门 0.30 | 有测试兜底 | 改坏 incremental 会吃满 CPU | 保持 `StreamingPerformanceTests` 在 CI |
| 50k 截断 | `maxParseLength` | 长对话截断 | 产品行为突兀 | 提供配置并增加用户提示 |
| 主线程 textStorage | CADisplayLink flush | 滑动时使用 `isDisplayPaused` | 列表场景可能掉帧 | 继续优化暂停与 cell 高度回调契约 |
| Scan 噪音 | `.build`/Caches 计入 metrics | 误判仓库规模 | 文档统计偏差 | 本目录改用 Sources 自计 ~3k LOC |

### 5) Fragile/High-Churn Areas

| Area | Why fragile | Churn signal (90d) | Safe change strategy |
|------|-------------|--------------------|----------------------|
| `InkAttributedRenderer.swift` | 富文本渲染逻辑核心 | 变更频繁 | 小步修改，补充行高与上下文测试 |
| `InkStreamRenderer.swift` | 状态机与双缓冲逻辑 | 提交较多 | 补充边界测试并运行性能测试 |
| `Tests/InkMarkdownTests.swift` | 测试契约集中 | 4 次路径变更 | 新增语法测试优先采用快照助手 |
| README / AGENTS / docs | 知识库更新 | 文档变更频繁 | 修改功能时同步更新 current-status |
| ExampleApp Demo 模型与 Pager | 演示结构变动 | 多文件修改 3–4 次 | 不与库核心 API 逻辑混淆 |
| ExampleApp SSE 增量重建 | 流式 chunk 触发 Block 重解析；靠 canonicalID 复用 generated 宿主 | 公式与图表 Demo 引入 | **未闭合 fence 提前生图：部分缓解** — `partitionForStreamingRender` 截断未闭合 Mermaid/`$$` 尾部后再 Block 渲染；`looksLikeBlockJustClosed` 仅在未闭合计数归零时立即 flush。仍为 Demo 层策略，非 `InkStreamRenderer` 契约。主题：SSE / 综合 Demo / **组件 Pager 公式·图表 tab** 均在 `traitCollectionDidChange` 时重建 |
| `onLoadFinished` 与 `failureFallback` 双轨 | 库默认源码回退 + ExampleApp 错误条叠加 | `InkImageRendering` / `GeneratedContentErrorBannerView` | 文档写清边界，避免宿主误以为改了库默认契约 |

生产代码 TODO（排除依赖缓存）：

- `ExampleApp/.../MarkdownDetailViewController.swift`：替换为 InkMarkdown 自身的渲染器

### 6) Resolved decisions (2026-07-15)

原 `[ASK USER]` 项已按决策形成 ADR，后续待跟进实现：

| 议题 | 决策摘要 | ADR |
|------|----------|-----|
| 依赖策略 | 默认固定 revision；`Packages/Caches` 作为可选离线路径 | [ADR-001](../decisions/ADR-001-swift-markdown-dependency-pinning.md) |
| 多平台 | v1.0 仅支持 iOS 14+；其余平台进入路线图 | [ADR-002](../decisions/ADR-002-v1-platform-scope-ios-only.md) |
| docs/codebase | 作为项目结构与状态证据层 | [ADR-003](../decisions/ADR-003-docs-codebase-evidence-layer.md) |
| 图片 / 删除线 | v1 默认占位 + opt-in 真图（ADR-006）；删除线样式已实现 | [ADR-004](../decisions/ADR-004-v1-image-and-strikethrough-contract.md)、[ADR-006](../decisions/ADR-006-opt-in-image-rendering.md) |
| maxParseLength | 可配置，默认 50_000 | [ADR-005](../decisions/ADR-005-stream-max-parse-length-configurable.md) |

### 7) Evidence

- `docs/codebase/.codebase-scan.txt`（TODO、HIGH-CHURN、CI、metrics）
- `Package.swift` / `Package.resolved`
- `Sources/InkMarkdown/Rendering/InkStreamRenderer.swift`
- `Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift`
- `docs/current-status.md` / `docs/roadmap.md`
- `git log` / churn 统计（scan 与本地 `git log --name-only`）

## Intent vs Reality

| Intent (docs / AGENTS) | Reality (repo) |
|------------------------|----------------|
| UIKit-only 产品 | 一致 |
| iOS/macOS/tvOS/watchOS 矩阵 | v1 仅 iOS 14+（ADR-002）；多平台为路线图 |
| 依赖可重复构建 | 直接依赖 revision pin（ADR-001）；本地 Caches 可选 |
| v1.0 前完善 + CI/CHANGELOG | 核心实现 + **CI 已有**；CHANGELOG/tag 未落地 |
| 完整语义测试矩阵 | 32 测试 + 快照脚手架，矩阵未齐 |
