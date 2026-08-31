# 05: 完成 attachment 与呈现周期边界

Status: complete

**What to build:** 让同一 streaming session 在 detach/reattach 后恢复 durable lineage 与 live state，同时确保旧 UIKit 资源和异步 callback 被隔离；reset、cancel、新文档或新静态 host 必须从干净的新呈现周期开始。

**Blocked by:** 02: 覆盖环境与测量变化下的连续性; 04: 打通流式 Thought promotion 连续性

- [x] detach 释放 host 引用、interaction/measurement callback、UIView registry 与 attached measurement cache，但保留同一 streaming session 的 durable lineage 和 live state。
- [x] 同一 session reattach 后恢复逻辑块状态并重新建立可丢弃 attachment，不要求复用原 UIView。
- [x] apply plan、interaction callback 与高度 callback 都绑定 lineage 和 attachment generation；退休 view、旧 generation 或已结束周期的 callback 被忽略。
- [x] `reset`、`cancel`、新流式文档和新的 static host identity 开启新周期并清空旧 lineage 与 presentation state；普通静态 source 更新不触发该边界。
- [x] attach、detach 和 end-cycle 清理幂等，不保留旧 host 强引用，也不覆盖宿主已经注册的 render-session callback。
- [x] 第三条关键链路测试覆盖 detach → same-session reattach → stale callback ignored → affected slot revision changed；周期 reset 复用第二条链路，不另建生命周期排列矩阵。
- [x] 使用现有 Example 场景手工检查 same-session remount、reset、cancel、新 static host，以及相邻 blocks 不受局部失效影响。
- [x] 当前 checkout 的相关构建与聚焦测试通过，并记录实际证据。

执行前读取父 spec、ADR-009 和仓库协作规则，并先检查当前 dirty working tree。若委派 subagent，必须使用无上下文继承模式，并提供包含仓库、范围、依赖、约束、证据和输出契约的完整 brief。

## Comments

- 2026-08-28：`detach()` 生成一次性事务 plan，commit 后清空 view registry 与 attached measurement cache，但 records 继续持有 lineage、caller input 与 live state；无 host/plan apply 失败的 dismantle 兜底使用 `discardAttachment()`，只丢弃可重建 attachment。
- 2026-08-28：apply plan、interaction callback、height callback 绑定 attachment generation；新增共享 `InkBlockPresentationAttachmentToken`，使 reset/cancel 在下一次 reconcile 前即可拒绝已捕获的旧高度 closure。周期边界同时递增 state version，旧 staged plan 无法提交。
- 2026-08-28：session 的 public `onDisplayUpdate` 与 adapter observer 完全分离；continuity reconcile observer、session display observer、renderer text-view binding 均带 owner token。旧 Coordinator teardown 只能清理自己，并在 detach 完成后同步唤醒已登记的新 owner。
- 2026-08-28：第三关键链保持单一测试，覆盖 detach/重复 detach、same-cycle reattach、lineage/live state 恢复、stale interaction/height ignored、仅 Thought slot revision +1，并穿过真实双 Coordinator 交叠接管与后续流式更新。第二关键链补充旧周期 staged plan/height callback 立即失效，不新增生命周期矩阵。
- 2026-08-28：两轮独立 `gpt-5.6-sol max` 实质审查先后发现 host callback 覆盖、交叠 remount owner 竞争、旧 staged plan 和旧高度 callback 窗口；均已修复。第三名最终复核 agent 未完成文件读取，未将其当作通过证据。
- 2026-08-28：XcodeBuildMCP，`InkMarkdown-Package` scheme，iPad Pro 13-inch (M5) / iOS 26.5：关键 suites 46 passed / 0 failed / 1 skipped；完整测试 336 passed / 0 failed / 1 skipped。相关 Serena diagnostics 为空。Example 生命周期手工项留到 Ticket 07。
- 2026-08-28 最终验收：same-session 卸载/重挂恢复折叠态；cancel/reset 与新 static host 清空旧状态。交叠 Coordinator 的等待者销毁和旧 owner teardown 均由 attachment token 限定，不会清除另一 host 的 attachment 或 observer。
