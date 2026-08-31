# 04: 打通流式 Thought promotion 连续性

Status: complete

**What to build:** 让同一流式呈现周期中的 Thought 在内容增长和 promotion 为终态 block 后继续保留 lineage 与用户状态；临时 stream remainder 在 promotion 时退休，不再冒充终态逻辑块。

**Blocked by:** 01: 建立静态 Thought 呈现连续性闭环

- [x] 一个 streaming render session 的生命周期持有一个 continuity context；session 不再保存或复制另一份 block live-state truth。
- [x] 流式临时内容通过 adapter-only presentation candidate 表达，不依赖 core renderer identity，也不使用负 index 模拟终态 block。
- [x] streaming Thought 与 promoted Thought 仅通过明确的一一对应 evidence 延续 lineage 和 live state；无法证明时局部新建 lineage。
- [x] promotion 可以安全采用旧 UIView，也可以重建 UIView 并恢复状态；两条路径对外语义一致，测试不要求 UIView 实例相同。
- [x] stream remainder 在 promotion 时退休，其 attachment、callback 与 measurement 不会污染 promoted block。
- [x] 第一条关键链路 fixture 扩展到 promotion，形成 initial state → user mutation → content/environment update → caller override → promotion 的完整链路，不另建重复 promotion 测试组。
- [x] 使用现有 streaming/chat Example 场景手工确认内容增长和 promotion 前后 Thought 状态连续、终态布局正确。
- [x] 当前 checkout 的相关构建与聚焦测试通过，并记录实际证据。

执行前读取父 spec、ADR-009 和仓库协作规则，并先检查当前 dirty working tree。若委派 subagent，必须使用无上下文继承模式，并提供包含仓库、范围、依赖、约束、证据和输出契约的完整 brief。

## Comments

- 2026-08-28：每个 `InkMarkdownRenderSession` 持有唯一 continuity context、cycle ID、Thought promotion evidence 与 adapter-only remainder token；streaming、promotion、reset/cancel 都经同一 reconcile/apply 边界。
- 2026-08-28：remainder 由 `InkStreamingRemainderBlock` 表达，使用固定 adapter structural slot，避免从空 session 插入 Thought 时同一 `UITextView` 被 mount 后又按旧 lineage unmount；promotion 缺少 remainder candidate 时由 plan 正常退休。
- 2026-08-28：第一条关键链路已扩展到 promotion，验证 lineage 与折叠 live state 连续，不再要求 UIView 指针相同；删除重复 P0 指针测试。
- 2026-08-28：独立 `gpt-5.6-sol max` 审查发现 remainder slot、宿主 callback 覆盖、错误 UIView 指针契约三项问题；均已修复。session 现以私有 owner observer 通知 Coordinator，公开 `onDisplayUpdate` 不被替换或写回。
- 2026-08-28：XcodeBuildMCP，`InkMarkdown-Package` scheme，iPad Pro 13-inch (M5) / iOS 26.5：修复前相关 39 passed / 0 failed / 1 skipped、完整测试 335 passed / 0 failed / 1 skipped；审查修复后 continuity + stream view + P0 gate 24 passed / 0 failed / 1 skipped。相关 Serena diagnostics 为空，tracked diff check 无 whitespace 错误。Example 手工项留到 Ticket 07。
- 2026-08-28 最终验收：Thought 分片增长、折叠、宽度变化、same-session remount、闭合与终态 promotion 保持状态；终态 suffix 正文紧随卡片，无空 remainder、重叠或陈旧高度。AI SSE 本地预设同时确认行内 `<think>...</think>` 示例不会提前关闭外层 Thought。
