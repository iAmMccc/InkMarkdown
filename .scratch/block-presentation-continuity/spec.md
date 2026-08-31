# Block Presentation Continuity Module

Status: complete

## Problem Statement

InkMarkdown 的 SwiftUI adapter 会在静态 Markdown 更新、流式增量显示、终态 promotion、configuration / trait 变化和 host remount 时反复生成或替换 UIKit block view。当前 block identity、Thought 折叠态、view 复用、promotion 迁移和 measurement cache 由 renderer、render session、Coordinator 与 container 分别维护。结果是同一逻辑块的呈现状态需要跨多条路径手工同步，错误 identity 还可能把状态迁移到无关 block。

从用户视角看，正确行为应是：同一呈现周期内，同一逻辑块的可见状态和交互状态保持连续；新周期或无法可靠识别的 block 使用新状态。UIView 实例和测量缓存可以安全丢弃，但不能因此重置用户状态、产生陈旧高度、复用错误内容或让未知 custom block 崩溃。

## Solution

在 `InkMarkdownSwiftUI` adapter 内建立一个 deep Block Presentation Continuity module。该 module 以一个原子 reconciliation seam 接收当前呈现周期、ordered presentation candidates、resolved environment 和明确 lineage evidence，统一决定逻辑块延续、live presentation state、view transition 与 measurement invalidation，再向 UIKit container 输出一次性 apply plan。

`InkBlockRenderer` 继续只产出 Markdown 语义 block，不接收 presentation cycle 或 identity。continuity module 按严格证据识别逻辑块，持有当前周期的 live 块呈现状态，并把 UIView 与 cache 视为可重建 attachment。streaming promotion 必须延续可证明的一一对应 lineage 与状态，但不强制复用同一个 UIView。证据不足时只重建受影响 block，不猜测、不 fatal、不影响其他 blocks。

## User Stories

1. 作为阅读静态 Markdown 的用户，我希望内容局部更新后已折叠的 Thought 仍保持折叠，从而不会因普通重渲染丢失阅读位置。
2. 作为查看流式回答的用户，我希望 Thought 内容持续增长时折叠状态保持不变，从而可以自主控制思考内容是否占据屏幕。
3. 作为等待流式回答完成的用户，我希望 streaming promotion 前后交互状态连续，从而不会看到 Thought 突然展开或折叠。
4. 作为返回同一条已完成消息的用户，我希望同一 render session remount 后恢复原有块呈现状态，从而获得连续的阅读体验。
5. 作为切换主题的用户，我希望 configuration 或颜色变化不重置块交互状态，从而只改变视觉样式。
6. 作为调整系统字体大小的用户，我希望 Dynamic Type 变化后交互状态保持不变且高度重新计算，从而既保留偏好又得到正确布局。
7. 作为在 iPad Split View 中改变宽度的用户，我希望 block 状态保持不变且布局无空白、重叠或陈旧高度，从而可以稳定阅读。
8. 作为 SwiftUI 宿主开发者，我希望首次提供的 block presentation state 成为初始值，从而可以配置默认展开或折叠行为。
9. 作为 SwiftUI 宿主开发者，我希望后续明确改变 caller-supplied state 时可以覆盖 live state，从而支持受控交互。
10. 作为 SwiftUI 宿主开发者，我希望普通内容更新不会被误判为 caller state override，从而避免每次 render 都重置用户操作。
11. 作为复用 render session 的宿主开发者，我希望 `reset` 开启新呈现周期，从而不把上一份文档状态带入下一份文档。
12. 作为取消流式回答的宿主开发者，我希望 `cancel` 结束当前呈现周期并清理 attachment，从而避免旧 callback 或状态污染后续内容。
13. 作为切换静态文档的宿主开发者，我希望新的 static host identity 开启新周期，从而不会把前一份文档状态带入无关文档。
14. 作为更新同一静态文档的宿主开发者，我希望同一 Coordinator 下的 source 变化仍按同一周期 reconcile，从而支持增量编辑而不依赖整篇 source hash。
15. 作为阅读重复段落或相似 blocks 的用户，我希望系统在 identity 歧义时不迁移旧状态，从而避免折叠态串到错误内容。
16. 作为阅读发生插入、删除或重排的内容的用户，我希望只有能够可靠证明的逻辑块延续，从而优先保证正确性。
17. 作为 custom block 作者，我希望未实现 continuity 能力的 block 仍能安全显示，从而不会因为 adapter 内部策略缺失而崩溃。
18. 作为实现 `InkReusableBlock` 的 custom block 作者，我希望现有 view reuse 能力仍可 best-effort 工作，从而不被新的状态 module 破坏。
19. 作为 UIKit 调用者，我希望 `InkMarkdown` 继续保持 UIKit-first renderer，从而不会被 SwiftUI presentation lifecycle 污染。
20. 作为 `0.0.1` 使用者，我希望已发布的最小 `InkRenderableBlock` interface 保持源兼容，从而可以升级而无需实现新的必选 witness。
21. 作为库维护者，我希望 renderer 不再接收 presentation identity 或 cycle 参数，从而让 semantic rendering seam 保持清晰。
22. 作为库维护者，我希望 Coordinator、session 和 container 不再各自保存 identity/state truth，从而让连续性 bug 集中在一个 module 内修复。
23. 作为库维护者，我希望 container 只消费 apply plan 并负责 mount 与 geometry，从而不再复制 reconciliation 规则。
24. 作为库维护者，我希望一次 reconciliation 原子提交 view ordering、replacement 与 invalidation，从而避免中间状态被 UIKit layout 观察。
25. 作为内建 stateful block 开发者，我希望通过 adapter 内部 strategy 定义延续、状态和 view transition，从而不把 Thought 特例散落到多个路径。
26. 作为未来内建 stateful block 开发者，我希望复用相同 strategy seam，从而无需增加新的 type-specific promotion 补丁。
27. 作为未来 custom stateful block 作者，我希望 v0.0.2 不仓促发布混合职责协议，从而让后续 public continuity interface 基于真实需求设计。
28. 作为维护流式渲染的开发者，我希望临时 stream text slot 不冒充终态逻辑块，从而避免一对多 promotion 使用虚假的负 index identity。
29. 作为维护 Thought promotion 的开发者，我希望 streaming Thought 与 promoted Thought 通过明确 lineage 一一对应，从而无需手工复制 view state。
30. 作为维护异步高度回调的开发者，我希望旧 attachment generation 的 callback 被忽略，从而不让退休 view 污染新布局。
31. 作为维护 measurement 的开发者，我希望内容、状态或 view 变化只递增受影响 slot revision，从而避免无关 block 全量重测。
32. 作为维护 environment 更新的开发者，我希望 configuration 或 trait 变化切换 environment signature，从而不会命中陈旧测量结果。
33. 作为性能工程师，我希望 view/cache 复用保持局部且可观测，从而能用现有 profiling workload 验证 locality，而不把优化变成公开契约。
34. 作为 QA，我希望在 ExampleApp 中手工检查静态 continuity，从而直接观察状态、布局与交互是否正确。
35. 作为 QA，我希望在 ExampleApp 中手工检查 streaming promotion，从而确认状态连续而不依赖 UIView 实例相同。
36. 作为 QA，我希望手工检查 same-session remount、reset、cancel 和新静态 host，从而验证周期边界与资源清理。
37. 作为测试维护者，我希望自动化只覆盖少量关键状态链路，从而防止 continuity 重构引入大量脆弱测试。
38. 作为测试维护者，我希望测试 observable reconciliation 结果而非 private maps 或具体 UIView identity，从而允许 implementation 演进。
39. 作为 Debug 构建使用者，我希望局部 fallback 提供可定位诊断，从而能理解为什么某个 block 没有延续。
40. 作为 Release 构建使用者，我希望无法延续时安静重建当前 block，从而不让诊断机制影响最终用户。
41. 作为 iOS 14 / iPadOS 14 宿主开发者，我希望 continuity module 遵守现有最低平台边界，从而不为该重构引入更高系统要求。
42. 作为 Chat 宿主开发者，我希望 promotion 后继续绑定同一 render session，从而保留同一呈现周期和块呈现状态。

## Implementation Decisions

- 使用项目领域术语“呈现周期”“逻辑块”“块呈现状态”和“块呈现连续性”；不得用“view reuse”替代完整的 continuity 契约。
- continuity 是用户状态正确性契约；UIView identity 与 measurement cache hit 只是可丢弃优化。
- module 位于 `InkMarkdownSwiftUI` adapter 内，不移入 `InkMarkdown` renderer，也不建立 native SwiftUI renderer。
- 每个呈现周期拥有独立 continuity context。静态周期由 adapter Coordinator lifetime 界定；流式周期由 `InkMarkdownRenderSession` 持有其 lifetime。
- 流式 session detach / reattach 不开启新周期。detach 释放 host 引用、callback、UIView registry 与 attached measurement cache，但保留 durable lineage 和 live state。
- `reset`、`cancel`、新流式文档或新的 static host identity 开启新周期，并清空旧 lineage 与 presentation state。
- 静态 source 字符串变化本身不切换周期。宿主切换到无关静态文档时必须建立新的 presentation identity；不得用整篇 source hash 猜测。
- `InkBlockRenderer` 只产生语义 blocks，不接收 cycle、lineage、view registry、measurement cache 或 live presentation state。
- reconciliation 输入是不可变 snapshot，包含 cycle identity、ordered presentation candidates、resolved environment、可用宽度、promotion lineage evidence 和 attachment generation。
- 静态与终态 candidates 包装 semantic blocks；流式临时 view 使用 adapter-only presentation candidate，不伪装为 core block identity。
- stream remainder 是临时 slot；它在 promotion 时退休。只有能够证明一一对应的 candidate 才延续 lineage 与状态。
- 逻辑块按固定证据顺序匹配：显式稳定 identity、promotion lineage、相同结构槽位与 concrete type 且 strategy 明确允许延续。证据不足时创建新 lineage。
- 禁止使用通用文本相似度、编辑距离、整篇 hash 或“最接近旧 block”推断 identity。
- 每条 lineage 的 continuity record 持有最新 semantic snapshot、上次 caller-supplied state、live state、strategy、可选 attached UIView、slot revision 和 attachment generation。
- continuity module 是周期内 live presentation state 的 SSOT；render session 继续只拥有 canonical source 与解析/显示阶段。
- 首次 caller-supplied state 初始化 live state。后续 supplied state 与上次 supplied snapshot 相同，则保留用户 live state；明确变化时视为 caller override。
- 普通内容增长、configuration、颜色、Dynamic Type、宽度和 trait 变化不得静默覆盖用户交互状态。
- promotion 必须延续可证明 lineage 与 live state。strategy 可以安全 adopt 旧 UIView，也可以重建并恢复状态；两条路径语义等价。
- adapter 对外部调用者提供一个主要 reconciliation seam；辅助 lifecycle operation 只包括 attach、detach 和 end-cycle。
- reconciliation 产生一次性 atomic apply plan，包含 ordered views、mount/unmount/replace、dirty measurement slots、retired attachments 和 intrinsic-size invalidation。
- apply plan 绑定 attachment generation，只能消费一次。container 不读取 continuity records，也不重新判断 identity 或 cache validity。
- 内建 stateful blocks 通过 adapter 内部 strategy registry 接入。strategy 统一负责延续判断、state merge、view transition、interaction callback 与 slot revision。
- v0.0.2 不向 `InkRenderableBlock` 增加 continuity witness，也不把 identity/state 职责混入 `InkReusableBlock`。
- 未注册 custom block 不获得 presentation-state migration 保证。若其实现 `InkReusableBlock`，可在严格同槽位条件下继续获得 best-effort view reuse。
- strategy 缺失、lineage 歧义、view 类型不兼容、update 被拒绝、state 无法恢复或 plan 过期时，只对当前 candidate 局部降级。
- 局部降级创建新 lineage 或 view、丢弃无法证明安全的当前 block state、失效当前 measurement，不影响其他 blocks，不 fatal。
- Debug 构建提供可定位诊断；Release 构建安静降级。诊断不成为 public callback contract。
- measurement key 至少由 lineage identity、slot-local revision、constrained width 与 environment signature 决定。
- semantic content、live state 或 attached view 变化只递增 affected slot revision；全局 environment 变化切换 signature 并清理不可再使用的 cache。
- height invalidation 与 interaction callback 必须携带 lineage 和 attachment generation；来自退休 view、旧 generation 或结束周期的 callback 被忽略。
- continuity reconciliation、UIView 操作和 callback wiring 全部受 `MainActor` 隔离。renderer 的解析调度属于独立 seam。
- 清理 operation 必须幂等，不覆盖宿主已注册的 render-session callback，也不保留旧 host 强引用。
- 实施采用 expand–migrate–contract 顺序：先建立内部 module 与 Thought strategy，再接入静态路径，再接入 streaming / promotion，最后删除旧 identity seam。
- contract 阶段删除 `0.0.1` 未包含的 identity SPI、renderer-side identified render helpers、streaming slot kind、source-derived epoch helper 及 renderer presentation-epoch 参数。
- 保留 `InkReusableBlock` 作为独立 view-reuse interface，并保持 `0.0.1` 已发布 public API 源兼容。
- ExampleApp continuity 检查优先扩展现有静态/configuration/streaming/chat 场景，不额外复制一套顶层 demo catalog。
- 实现完成、build、关键链路测试、Example 手工检查和性能证据齐备后，才能把本设计写入当前状态作为已交付事实。

## Testing Decisions

- 自动化测试的最高且主要 seam 是 continuity module 的 reconciliation interface。测试输入 presentation snapshot 与 lineage evidence，断言 observable plan、state outcome、cycle boundary 和 slot revision；不穿透 private records/maps。
- 只保留三条自动化关键链路，可使用 table-driven fixture 合并相邻变体：
  1. initial state → user mutation → content/environment update → caller override → promotion；
  2. strict evidence match → ambiguity fallback → new-cycle reset → custom block safe rebuild；
  3. detach → same-session reattach → stale callback ignored → affected slot revision changed。
- UI、布局和交互不新增 UI automation 或 snapshot tests。通过 ExampleApp 手工检查 static continuity、streaming promotion、same-session remount、environment 变化、reset/cancel、新 static host 和 custom fallback。
- 好测试只断言外部可见行为：状态是否连续、错误状态是否没有迁移、布局是否请求正确失效、旧 callback 是否无效、其他 blocks 是否不受影响。
- 不断言具体 UIView 实例必须相同；promotion 允许 safe adoption 或 rebuild + state restore。
- 不为每个 block type、每种排列、每个 internal branch 或每个 cache entry 新建测试，禁止滥写重复测试。
- 既有 `InkMarkdownP0GateTests` 可作为 promotion、reset/cancel、stream slot 与局部测量的测试先例；目标是把重复 identity 断言上移到统一 reconciliation seam。
- 既有 `InkPartialBlockReuseTests` 可作为 custom reusable block 与安全 view transition 的先例；新测试不复制其每种 block 细节矩阵。
- 既有 `InkMarkdownRenderSessionTests`、`InkStreamMarkdownViewTests` 与 `InkMarkdownMeasurementTests` 提供 session lifecycle、stream integration 与 measurement 的集成先例；只保留无法由 continuity seam 表达的少量跨-module contract。
- 性能 locality 通过现有 profiling/debug counters 和 Example workload 验证；不把具体 cache hit 或 UIView reuse 次数定义成 public behavior。
- 构建与自动化验证继续使用项目约定的 iOS Simulator 与 XcodeBuildMCP；不能用 macOS `swift test` 的 UIKit 缺失代表库逻辑失败。

## Out of Scope

- native SwiftUI Markdown renderer、InkIR 或第二套 Theme；
- 修改 Markdown parsing、block routing、source filtering 或 `InkConfiguration` 语义；
- 网络、SSE/LLM transport、聊天业务状态、滚动和导航策略；
- v0.0.2 的 public custom continuity protocol；
- 跨呈现周期、跨文档或跨进程持久化 block presentation state；
- 通用 source-edit diff、文本相似度匹配或 block reorder animation；
- 保证同一个 UIView 在所有更新、promotion 或 remount 中存活；
- 为 continuity 建立大规模 UI automation、snapshot matrix 或 exhaustive unit-test matrix；
- 在真实 baseline 前承诺固定 FPS、内存或 cache-hit 数字；
- 修改项目最低平台、Swift language mode 或已发布 `0.0.1` public API；
- 本 spec 阶段修改 production code、ExampleApp 实现或 `current-status.md`。

## Further Notes

- ADR-009 是本 spec 的架构决策来源；ADR-008 的 SwiftUI adapter 总体方向仍有效，Thought live state ownership 的旧描述已被 ADR-009 amend。
- Block Presentation Continuity module 技术设计是实现细节来源；若 spec 与 ADR 冲突，以 ADR 为准。
- 当前 checkout 仍是未发布 v0.0.2 的 dirty working tree。实现 agent 必须先检查现有改动，保留用户和其他任务的并行修改，不把历史测试结果当作当前证据。
- 本 spec 已采用用户确认的测试 seam，不需要再次访谈；下一步由 `/to-tickets` 拆成 blockers-first tracer-bullet tickets。
- 任何 delegated subagent 都不得继承主 agent 上下文。必须使用无继承模式，并在 self-contained brief 中写明仓库路径、领域术语、ADR/spec 来源、scope、依赖、证据要求和输出契约。
- agent 状态、计划或“完成”声明不等于交付；每个 ticket 必须用当前 checkout 的 build、关键链路测试或 Example 手工证据收口。

## Comments

- 2026-08-28：七个本地 tickets 已按 expand–migrate–contract 顺序完成并收口；没有创建 GitHub Issue。当前证据记录于各 ticket 与 `docs/current-status.md`。iOS/iPadOS 14 实际运行仍是 v0.0.2 release blocker，不影响本 spec 的 continuity 实施状态。
