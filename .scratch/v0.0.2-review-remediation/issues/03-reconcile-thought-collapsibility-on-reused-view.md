# 03: 让复用 Thought 卡片完整切换可折叠能力

Status: ready-for-agent

## Summary

让同一个复用中的 Thought 卡片在 configuration 把 `isCollapsible` 从 false 切到 true、再切回 false 时，完整更新交互、图标、折叠状态和可访问性，而不是保留首次创建时的行为。

## Context

- Spec: [v0.0.2 Review Remediation](../spec.md)
- Architecture: [Block Presentation Continuity module](../../../docs/contributor-guide/11-block-presentation-continuity.md)
- Source: [InkThoughtBlock](../../../Sources/InkMarkdown/Rendering/Components/InkThoughtBlock.swift)

Blocked by: None.

## Acceptance

- [x] `false → true` 后头部可点击、chevron 可见、折叠状态可应用，VoiceOver traits/value/hint 与可折叠语义一致。
- [x] `true → false` 后移除点击行为和 chevron，正文归一化为可见状态，VoiceOver 降级为不可折叠 header 语义。
- [x] 重复 apply 相同配置不会叠加 target、重复 subview 或产生多次交互回调。
- [x] 不保留 Thought view 的点击、尺寸、subview、target 或可访问性 UI 单测；这些行为统一通过 ExampleApp 手工验收。
- [x] 使用 ExampleApp 手工检查可折叠能力切换、点击行为、图标、布局和 VoiceOver 可见语义。
- [x] 当前 checkout 的聚焦测试与 iOS Simulator 构建通过，并记录实际结果。
- [x] 如委派给 subagent，必须使用不继承主 agent 上下文的独立会话；本票正文是其唯一任务上下文。

## Comments

- 2026-08-31：实现完成。`syncCollapsedVisualState()` 统一创建、点击与 apply 三条视觉同步路径。
- 2026-08-31：最终 checkout 在配置页手工切换 true→false→true：关闭后 target/chevron 与折叠 value/hint 消失，正文恢复可见；重开后按钮、提示与折叠交互恢复。
- 2026-08-31：按测试策略删除 Thought view 的复用、点击、尺寸、subview、target 与可访问性单测，不以 UIKit 实现细节建立自动化契约。
