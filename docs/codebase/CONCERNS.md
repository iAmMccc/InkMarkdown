# Codebase Concerns

## Core Sections (Required)

### 1) Top Risks (Prioritized)

| Severity | Concern | Evidence | Impact | Suggested action |
|----------|---------|----------|--------|------------------|
| ~~High~~ Done | ~~依赖跟踪 `branch: main`~~ | `Package.swift` 已 `revision:`；`Package.resolved` 无 branch 字段 | 可重复构建已改善 | 升级时显式改 revision + 测 |
| ~~High~~ Done | ~~无 CI~~ | `.github/workflows/ci.yml` | PR/push 自动 iOS 测 | 监控 runner/模拟器可用性 |
| Med | 平台决策 vs manifest | `AGENTS.md` 目标矩阵；v1 仅 iOS（ADR-002） | 文档若写超会误导 | 对外只宣称 iOS 14+ |
| Med | 流式 `maxParseLength = 50_000` 硬编码 | `InkStreamRenderer.swift:147`；ADR-005 | 超长 SSE 静默截断 / 停解析 | 配置化 + 文档契约 + 测试 |
| Med | 语义测试矩阵未完成 | `current-status.md`、仅 snapshot scaffold | 语法回归靠手测 | 在 `RenderSnapshot` 上铺 CommonMark/GFM 契约 |
| Low | 无 root linter/formatter | scan | 风格漂移 | 按需引入 SwiftFormat/SwiftLint |
| Low | 传递依赖 `swift-cmark` 仍为 branch+revision | `Package.resolved` | 随 markdown pin 间接固定，但非直接声明 | 一般可接受；若需极致锁定可观察 resolved |

### 2) Technical Debt

| Debt item | Why it exists | Where | Risk if ignored | Suggested fix |
|-----------|---------------|-------|-----------------|---------------|
| 删除线：内容保留但未做 GFM strikethrough 样式 | 行内 switch 无 `Strikethrough` 专用分支（default 透传） | `InkAttributedRenderer.renderInline` | 用户以为支持 `~~del~~` 样式 | 明确 v1 契约或补样式 + 测试 |
| 图片仅占位 | 产品范围不含下载/附件 | `renderImage` | 宿主期望内置图片 | 文档写清；扩展点由宿主做 |
| 过时 TABLE 指南仍在树内 | 历史材料 | `Components/TABLE_INTEGRATION_GUIDE.md`（已 exclude） | Agent 误读旧 API | 入口已警告；考虑移出 Sources 或标 deprecated |
| ExampleApp TODO | 演示未完全切到库渲染器 | `MarkdownDetailViewController.swift:137` | 示例与库能力不一致 | 跟进 example plan 或删过时 TODO |
| 本地缓存仍是可选路径 | ADR-001：默认 revision，不默认 path | `Packages/` vs `Package.swift` | 离线开发需自行 path 覆盖 | 文档写清可选流程即可 |
| 大文件 | 流式/富文本复杂度集中 | `InkStreamRenderer` ~632 LOC；`InkAttributedRenderer` ~583 LOC | 变更冲突与回归面大 | 按边界拆 incremental / block visitors |

### 3) Security Concerns

| Risk | OWASP category (if applicable) | Evidence | Current mitigation | Gap |
|------|--------------------------------|----------|--------------------|-----|
| 恶意 Markdown / 超大输入 | A04 / resource exhaustion | 流式 50k 上限；无 HTML 执行 | 长度上限；inline HTML 多丢弃 | 非流式路径无限长；无统一 DoS 策略文档 |
| 链接点击打开任意 URL | A01 宿主侧 | `linkTapHandler` 可选 | 宿主可拦截 | 默认交给系统，宿主需自审 |
| 密钥泄露 | N/A | 无服务端密钥 | 无密钥面 | — |
| 依赖供应链 | A06 | 直接依赖已 pin revision；传递 cmark 为 gfm+revision | Package.resolved | 缺 Dependabot/安全策略文件（可选） |

### 4) Performance and Scaling Concerns

| Concern | Evidence | Current symptom | Scaling risk | Suggested improvement |
|---------|----------|-----------------|-------------|-----------------------|
| 全量重解析退化 | 性能测试闸门 0.30 | 有测试兜底 | 改坏 incremental 会吃满 CPU | 保持 `StreamingPerformanceTests` 在 CI |
| 50k 截断 | `maxParseLength` | 长对话截断 | 产品行为突兀 | 配置 + 用户可见提示（宿主） |
| 主线程 textStorage | CADisplayLink flush | 滑动时可用 `isDisplayPaused` | 列表场景掉帧 | 继续强化暂停与 cell 高度回调契约 |
| Scan 噪音 | `.build`/Caches 计入 metrics | 误判仓库规模 | 文档误导 | 本目录已用 Sources 自计 ~3k LOC |

### 5) Fragile/High-Churn Areas

| Area | Why fragile | Churn signal (90d) | Safe change strategy |
|------|-------------|--------------------|----------------------|
| `InkAttributedRenderer.swift` | 全部富文本语义中枢 | 高 churn 库文件之一 | 小步 + 行高/上下文测试 |
| `InkStreamRenderer.swift` | 状态机 + 双缓冲 | 相关提交多 | 边界测试 + 性能闸门必跑 |
| `Tests/InkMarkdownTests.swift` | 契约集中 | 4 次路径变更 | 新增语法测优先快照助手 |
| README / AGENTS / docs | 知识库迭代 | 最高 churn 在文档 | 改能力时同步 current-status |
| ExampleApp Demo 模型与 Pager | 演示结构变动 | 多文件 3–4 次 | 不与库 API 真相混淆 |

生产代码 TODO（排除依赖缓存）：

- `ExampleApp/.../MarkdownDetailViewController.swift`：替换为 InkMarkdown 自身渲染器

### 6) Resolved decisions (2026-07-15)

以下原 `[ASK USER]` 项已按推荐决策落 ADR，实现可后续跟进：

| 议题 | 决策摘要 | ADR |
|------|----------|-----|
| 依赖策略 | 固定 revision 为默认；`Packages/Caches` 仅可选离线 | [ADR-001](../decisions/ADR-001-swift-markdown-dependency-pinning.md) |
| 多平台 | v1.0 仅 iOS 14+；其余进路线图 | [ADR-002](../decisions/ADR-002-v1-platform-scope-ios-only.md) |
| docs/codebase | 正式证据基线层，短文档不抢长文真相 | [ADR-003](../decisions/ADR-003-docs-codebase-evidence-layer.md) |
| 图片 / 删除线 | v1 契约限制，不阻塞发布 | [ADR-004](../decisions/ADR-004-v1-image-and-strikethrough-contract.md) |
| maxParseLength | 可配置，默认 50_000 | [ADR-005](../decisions/ADR-005-stream-max-parse-length-configurable.md) |

### 7) Evidence

- `docs/codebase/.codebase-scan.txt`（TODO、HIGH-CHURN、CI、metrics）
- `Package.swift` / `Package.resolved`
- `Sources/InkMarkdown/Rendering/InkStreamRenderer.swift`
- `Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift`
- `docs/current-status.md` / `docs/roadmap.md`
- `git log` / churn 统计（scan 与本地 `git log --name-only`）

## Intent vs Reality (summary)

| Intent (docs / AGENTS) | Reality (repo) |
|------------------------|----------------|
| UIKit-only 产品 | 一致 |
| iOS/macOS/tvOS/watchOS 矩阵 | v1 仅 iOS 14+（ADR-002）；多平台为路线图 |
| 依赖可重复构建 | 直接依赖 revision pin（ADR-001）；本地 Caches 可选 |
| v1.0 前完善 + CI/CHANGELOG | 核心实现 + **CI 已有**；CHANGELOG/tag 未落地 |
| 完整语义测试矩阵 | 32 测试 + 快照脚手架，矩阵未齐 |
