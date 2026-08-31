# 03: 收紧身份判定并隔离 custom block 降级

Status: complete

**What to build:** 当内容插入、删除、重排、重复或包含未知 custom block 时，只延续证据充分的逻辑块；证据不足的当前 block 局部、安全重建，不能把交互状态迁移到无关内容，也不能影响其他 blocks。

**Blocked by:** 01: 建立静态 Thought 呈现连续性闭环

- [x] lineage 只按固定证据顺序延续：显式稳定 identity、明确 promotion lineage、相同结构槽位与 concrete type 且对应 strategy 明确允许。
- [x] 禁止使用通用文本相似度、编辑距离、整篇 hash 或“最接近旧 block”推断 identity。
- [x] 插入、删除、重排、重复内容或其他歧义场景创建新 lineage，不把旧 live state 迁移到错误 block。
- [x] 未注册 custom block 能局部安全重建；实现 `InkReusableBlock` 的 custom block 仅在严格同槽位条件下保留 best-effort view reuse。
- [x] strategy 缺失、view 类型不兼容、update 被拒绝或状态无法安全恢复时，不 fatal，只失效当前 block 的状态、view 与 measurement；其他 blocks 保持连续。
- [x] Debug 构建提供可定位降级诊断，Release 构建安静降级；诊断不形成 public callback contract。
- [x] 第二条关键链路测试覆盖 strict evidence match → ambiguity fallback → new-cycle state reset → custom block safe rebuild，并只断言 observable reconciliation 结果。
- [x] 使用现有 Example 体系手工检查一次歧义和 custom fallback；不复制新的顶层 demo catalog，不新增 exhaustive block matrix。
- [x] 当前 checkout 的相关构建与聚焦测试通过，并记录实际证据。

执行前读取父 spec、ADR-009 和仓库协作规则，并先检查当前 dirty working tree。若委派 subagent，必须使用无上下文继承模式，并提供包含仓库、范围、依赖、约束、证据和输出契约的完整 brief。

## Comments

- 2026-08-28：candidate 支持 adapter-internal stable identity 与 promotion lineage evidence；整轮 reconciliation 先按 stable、promotion、structural 三个全局 pass 决策，强 evidence 重复或冲突会隔离 lower pass，不受 candidate 顺序影响。
- 2026-08-28：unknown non-reusable custom 固定局部重建；`InkReusableBlock` 即使携带强 evidence，也必须通过同 concrete type、同 structural slot 的 fallback strategy，reconcile staging 不原地修改已挂载 view。
- 2026-08-28：第二条关键链路仍为单一测试，已覆盖较弱 promotion candidate 排在 stable candidate 前、歧义新 lineage、新周期清除已折叠 live state，以及 reusable custom 跨槽位安全重建。
- 2026-08-28：XcodeBuildMCP，`InkMarkdown-Package` scheme，iPad Pro 13-inch (M5) / iOS 26.5：continuity 聚焦 2 passed / 0 failed；continuity + P0 gate 12 passed / 0 failed / 1 skipped；完整测试 342 passed / 0 failed / 1 skipped。Serena diagnostics 为空；untracked 文件的 `git diff --no-index --check` 无 whitespace 输出。
- 2026-08-28：首次 `gpt-5.6-sol max` 审查发现跨 evidence 抢占、reusable custom 越槽位和 reset 假阳性；修复后二次独立复核确认三项均关闭、无新 P0/P1/P2。Example 歧义/custom 手工检查留到 Ticket 07，因此手工项暂不勾选。
- 2026-08-28 最终验收：结构族增删、重复或可证实重排时拒绝弱 lineage 迁移；旧 records 建立一次性索引，更新路径不再按 candidate 扫描全表。现有静态 Example 中折叠 A 后删除 A，B 保持展开；组件页 custom H1 局部 fallback 不影响 Thought 与相邻 blocks。
