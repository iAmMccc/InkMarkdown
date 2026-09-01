# Codebase Concerns

## Core Sections (Required)

### 1) Top Risks (Prioritized)

| Severity | Concern | Evidence | Impact | Suggested action |
|----------|---------|----------|--------|------------------|
| ~~High~~ Done | ~~依赖跟踪 `branch: main`~~ | `Package.swift` 已 `revision:`；`Package.resolved` 无 branch 字段 | 可重复构建已改善 | 升级时显式修改 revision 并测试 |
| ~~High~~ Done | ~~无 CI~~ | `.github/workflows/ci.yml` | PR/push 自动 iOS 测试 | 监控 runner/模拟器可用性 |
| ~~High~~ Done | ~~流式 sourceFilter 路径每次 append 全量重渲 O(n²)~~ | `InkStreamRenderer.swift`：sourceFilter 依赖完整源文本只能整段全量解析，但显示侧改为「稳定前缀 diff + 只重写受影响尾部」（`stablePrefixLength` + `refreshTextStorage` seam），parseQueue 内维护 diff 基线 | 主线程 textStorage 重写成本从 O(累计长度) 收敛到 O(本次变化) | 2026-08-19 已修复；5 项 seam 测试钉住跳过/尾部追加/收缩/前缀变化四情形 |
| ~~High~~ Done | ~~流式显示刷新逻辑处于测试盲区~~ | `onDisplayFrame` 由 CADisplayLink 驱动，集成测试不触发；节流分支此前无任何测试执行 | 行为变化无回归防线 | 已抽 `refreshTextStorage` 纯函数 seam 并补测试（`InkStreamRendererRefreshTests.swift`） |
| ~~Med~~ Done | ~~finish 后 append 无保护~~ | `InkStreamRenderer.append` 无终态守卫，可覆盖 finalize 结果 | 终态被污染、onFinishDisplay 提前触发 | 已加 `guard !isFinished` 并有测试钉住 |
| ~~Med~~ Done | ~~配置语义相等性只看数量与 nil 性~~ | `InkConfiguration.isSemanticallyEqualTo` 曾把内容不同的配置误判相等，SwiftUI Coordinator 据此漏更新 | 配置内容变化不触发重渲 | 已收敛到 `InkSemanticComparator`：值类型比较完整状态，不透明闭包、loader 与回调使用显式 `InkSemanticIdentity`；直接赋值保守刷新。配置语义与 Coordinator 幂等测试共同钉住 |
| Med | 最低平台验证 | ADR-008 仅承诺 iOS/iPadOS 14+；manifest 已仅声明 `.iOS(.v14)`，当前全量回归来自 iPhone 17 / iOS 26.5 | 可能把较高版本 Simulator 结果误当作最低版本支持 | v0.0.2 前完成 iOS/iPadOS 14 验证；不为其他平台建立路径 |
| ~~Med~~ Done | ~~`isSemanticallyEqualTo` 对「同类型不同状态」仍判相等~~ | 内置扩展通过 `InkConfigurationSemanticsProviding` 或稳定 `InkSemanticIdentity` 比较完整状态；未知扩展保守判为不等价；块复用比较已覆盖样式、渲染配置、表格边界、图片 store 与生成 loader | 已避免 Coordinator 因有损比较漏更新，也避免旧异步图片结果回灌新块 | 新增有状态扩展时必须提供完整值语义或稳定 identity，并补配置与块复用回归 |
| Low | 增量性能基准偶发超时 | `StreamingPerformanceTests.incremental_renderIsFasterThanFullRender` 在机器高负载下偶发失败（同日多次复跑通过，P3 与模块级复跑均通过） | 负载相关 flaky，非逻辑回归 | 复跑确认；必要时给基准加宽裕或标注 flaky |
| ~~Med~~ Done | ~~流式 `maximumSourceLength = 50_000` 固定~~ | renderer/session initializer 已开放自定义上限并共享不可变 snapshot；ADR-005 | canonical source、finish 与 promotion 已统一 | 默认值变更时重跑 source-limit 与性能门槛 |
| Med | 语义测试矩阵未完成 | 已新增首批 19 项 CommonMark/GFM 契约；复杂引用、列表续段、表格边界与跨通道矩阵仍缺 | 组合语法回归仍可能依赖手测 | 继续在 `RenderSnapshot` 与三条渲染通道补全契约 |
| Med | ExampleApp SSE 未闭合块的全量重解析 | `SSEChatViewController` 按 chunk 节流重建 segments | 长回答 CPU / 文本段闪烁；generated 块已按 identity 复用；**文本段已按前缀复用**（`reusableTextSegments` + `updateFullText`），行内 attachment 不再每轮销毁 | 可继续收紧「仅尾部文本增长时跳过全量 rebuild」 |
| Low | 无 root linter/formatter | scan | 风格漂移 | 按需引入 SwiftFormat/SwiftLint |
| Low | 传递依赖 `swift-cmark` 仍为 branch+revision | `Package.resolved` | 随 markdown pin 间接固定，但非直接声明 | 可接受；如需锁定可监控 resolved |

### 2) Technical Debt

| Debt item | Why it exists | Where | Risk if ignored | Suggested fix |
|-----------|---------------|-------|-----------------|---------------|
| 自定义 inline syntax / 图片不完整继承删除线 | 文本与行内代码 `Strikethrough` 已写入 `.strikethroughStyle`，但自定义 `inlineSyntaxes` 未透传该属性，图片叶子节点也不写入 | `InkAttributedRenderer.renderInline` / `renderImage`；`spec/extended-syntax.md` | `~~@mention~~`、`~~![image](url)~~` 等组合语义可能不一致 | 补充契约测试；需要时让 custom syntax 合并文本 context，并为图片定义独立视觉契约 |
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
| source limit 截断 | `maximumSourceLength` 默认 50k，可按 session 配置 | 长对话仍可能在宿主选择的边界截断 | 产品行为突兀 | 宿主按场景配置并增加用户提示 |
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
| Med | ExampleApp SSE 流式路径 | Chat 走 `ChatDemoViewModel` + `InkMarkdownRenderSession`；chunk 路径仅 `session.append`；滚动/粘底/吐字暂停由 **ExampleApp 内** `ChatScrollPolicy`（非 SPM 公开 product）+ `session.isDisplayPaused` 驱动；promotion 后会话转移到 `messages[].renderSession`，UI 仍绑定 `InkStreamMarkdownView`，**勿**假定 re-parse `content` 或 value-copy blocks 可保留折叠态。**勿假定** `InkStreamRenderer` 支持 GFM 增量表。 |
| `onLoadFinished` 与 `failureFallback` 双轨 | 库默认源码回退 + ExampleApp 错误条叠加 | `InkImageRendering` / `GeneratedContentErrorBannerView` | 文档写清边界，避免宿主误以为改了库默认契约 |

生产代码 TODO（排除依赖缓存）：

- `ExampleApp/.../MarkdownDetailViewController.swift`：替换为 InkMarkdown 自身的渲染器

### 6) Resolved decisions (2026-07-15)

原 `[ASK USER]` 项已按决策形成 ADR，后续待跟进实现：

| 议题 | 决策摘要 | ADR |
|------|----------|-----|
| 依赖策略 | 默认固定 revision；`Packages/Caches` 作为可选离线路径 | [ADR-001](../decisions/ADR-001-swift-markdown-dependency-pinning.md) |
| 平台范围 | 当前产品路线仅支持 iOS 14+ / iPadOS 14+；不支持其他平台 | [ADR-008](../decisions/ADR-008-swiftui-adapter-architecture.md) |
| docs/codebase | 作为项目结构与状态证据层 | [ADR-003](../decisions/ADR-003-docs-codebase-evidence-layer.md) |
| 图片 / 删除线 | v1 默认占位 + opt-in 真图（ADR-006）；删除线样式已实现 | [ADR-004](../decisions/ADR-004-v1-image-and-strikethrough-contract.md)、[ADR-006](../decisions/ADR-006-opt-in-image-rendering.md) |
| maximumSourceLength | 可配置，默认 50_000 | [ADR-005](../decisions/ADR-005-stream-max-parse-length-configurable.md) |

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
| UIKit-first engine + SwiftUI adapter 产品路线 | 已发布 `0.0.1` 为 UIKit-first；当前 source 已有独立 `InkMarkdownSwiftUI` adapter，v0.0.2 尚未发布 |
| iOS/iPadOS 14+ 范围 | ADR-008 已排除其他平台；manifest 已收敛，iOS/iPadOS 14 验证仍是 v0.0.2 blocker |
| 依赖可重复构建 | 直接依赖 revision pin（ADR-001）；本地 Caches 可选 |
| v0.0.2 前完善 + 发布证据 | 核心 UIKit implementation、CI、SwiftUI adapter 基础契约与 iPhone/iPad ExampleApp 关键链路证据已落地；最低系统、完整可访问性、网络图片与真机性能证据仍未完成 |
| 完整语义测试矩阵 | 2026-09-01 iPhone 16 Pro / iOS 18.5 全量共 299 项：298 项通过、0 失败、1 项跳过；测试已按关键数据/状态/语义链路收口，SwiftUI adapter 仍缺完整人工交互与最低版本矩阵 |
