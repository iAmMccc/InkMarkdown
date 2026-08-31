# 02: 覆盖环境与测量变化下的连续性

Status: complete

**What to build:** 让静态 Thought 在 configuration、颜色、Dynamic Type、trait 和可用宽度变化时保留 lineage 与 live state，同时只重新测量真正失效的布局，避免陈旧高度、空白或重叠。

**Blocked by:** 01: 建立静态 Thought 呈现连续性闭环

- [x] configuration、颜色、Dynamic Type、trait 或宽度变化不重置 Thought 的用户交互状态，也不创建无依据的新 lineage。
- [x] measurement identity 至少包含 lineage、slot-local revision、constrained width 与 environment signature；变化后的结果不会命中陈旧测量。
- [x] semantic content、live state 或 attached view 变化只递增受影响 slot revision，不驱动无关 block 全量重测。
- [x] 全局 environment 变化切换 environment signature，并清理不再适用的 attached measurement cache。
- [x] 高度与 intrinsic-size invalidation 通过同一次 atomic apply plan 交付，container 不维护第二套 cache-validity 规则。
- [x] 扩展第一条关键链路 fixture，覆盖 content/environment update 后 live state 保持与 caller override；不另建环境排列测试矩阵。
- [x] 使用现有 configuration/static Example 场景手工检查主题、字体和宽度变化后的状态及布局；不新增 UI automation 或 snapshot test。
- [x] 当前 checkout 的相关构建与聚焦测试通过，并记录实际证据；最低 iOS/iPadOS 14 边界不因本票提高。

执行前读取父 spec、ADR-009 和仓库协作规则，并先检查当前 dirty working tree。若委派 subagent，必须使用无上下文继承模式，并提供包含仓库、范围、依赖、约束、证据和输出契约的完整 brief。

## Comments

- 2026-08-28：continuity measurement key 已绑定 lineage、slot revision、constrained width 与 environment signature；interaction、semantic、view 和 environment 失效均由同一 staged apply plan 交付。
- 2026-08-28：补齐 iOS 14 可用的 `traitCollectionDidChange(_:)` production trigger；trait-only 变化即使宽度和上次签名已记录，也会经过窄 callback，不伪造 environment version。
- 2026-08-28：Thought 当前 attachment generation 的高度 callback 使用 entry 已提交的 proposed width；旧 generation callback 被拒绝。
- 2026-08-28：XcodeBuildMCP，`InkMarkdown-Package` scheme，iPad Pro 13-inch (M5) / iOS 26.5：continuity + P0 gate 11 passed / 0 failed / 1 skipped；完整测试 341 passed / 0 failed / 1 skipped。Serena diagnostics 与 `git diff --check` 均无问题，日志无 unsupported trait override 警告。
- 2026-08-28：`gpt-5.6-sol max` 独立审查无可操作 findings。Example 已完成主题、Dynamic Type 与基础宽度重排的部分手工检查；完整 Thought 状态与布局矩阵留到 Ticket 07 统一验收，因此手工检查项暂不勾选。
- 2026-08-28 最终验收：configuration 的字号、段落间距和 caller override，以及 streaming 窄宽/全宽切换均保持正确 Thought 状态和相邻布局。measurement cache 在宽度切换时淘汰旧宽条目，关键链验证仅保留当前宽度 slots。
