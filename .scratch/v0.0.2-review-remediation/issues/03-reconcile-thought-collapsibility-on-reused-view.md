# 03: 让复用 Thought 卡片完整切换可折叠能力

Status: ready-for-agent

## Summary

让同一个复用中的 Thought 卡片在 configuration 把 `isCollapsible` 从 false 切到 true、再切回 false 时，完整更新交互、图标、折叠状态和可访问性，而不是保留首次创建时的行为。

## Context

Blocked by: None.

## Acceptance

- [x] `false → true` 后头部可点击、chevron 可见、折叠状态可应用，VoiceOver traits/value/hint 与可折叠语义一致。
- [x] `true → false` 后移除点击行为和 chevron，正文归一化为可见状态，VoiceOver 降级为不可折叠 header 语义。
- [x] 重复 apply 相同配置不会叠加 target、重复 subview 或产生多次交互回调。
- [x] 扩展现有 Thought view 复用或 configuration 更新关键路径测试；不新增 UIView identity、状态排列或 snapshot 测试矩阵。
- [x] 使用 ExampleApp 手工检查可折叠能力切换、点击行为、图标、布局和 VoiceOver 可见语义。
- [x] 当前 checkout 的聚焦测试与 iOS Simulator 构建通过，并记录实际结果。
- [x] 如委派给 subagent，必须使用不继承主 agent 上下文的独立会话；本票正文是其唯一任务上下文。

## Comments

- 2026-08-31：实现完成。复用测试覆盖 false→true→false 与重复 apply；手工确认关闭折叠后 target/chevron 消失且正文恢复可见，重新开启后按钮、value 与折叠交互恢复。
