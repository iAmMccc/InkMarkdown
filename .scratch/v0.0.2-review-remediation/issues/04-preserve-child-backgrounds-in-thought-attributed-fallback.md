# 04: 保留 Thought 富文本后备中的子级背景语义

Status: ready-for-agent

## Summary

让 Thought 的 attributed fallback 表达卡片背景时，不覆盖 inline code 等子节点已经确定的同 key 背景与绘制 metadata。Thought 内部 Markdown 保持完整行内语义，闭标签后的 suffix 继续位于 Thought 区域之外。

## Context

- Spec: [v0.0.2 Review Remediation](../spec.md)
- Rendering rule: [Context 下传](../../../docs/contributor-guide/03-principles.md#32-context-下传禁止事后回写)
- Source: [InkAttributedRenderer](../../../Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift)、[InkThoughtBlock](../../../Sources/InkMarkdown/Rendering/Components/InkThoughtBlock.swift)

Blocked by: None.

## Acceptance

- [x] Thought 正文中的 inline code 保留自己的背景颜色、圆角背景 metadata、等宽字体和前景色。
- [x] Thought 容器背景不会通过事后全 range 同 key 回写覆盖子节点语义，并遵守现有 context 下传与固定行高约束。
- [x] 闭标签后的普通 Markdown 不获得 Thought 背景或 Thought 文本样式。
- [x] 只补一条同时覆盖 Thought、inline code 和 suffix 边界的语义关键路径测试；不新增视觉 snapshot 矩阵。
- [x] 使用现有 ExampleApp Thought 场景手工确认卡片范围、inline code 背景和 suffix 布局正确。
- [x] 当前 checkout 的聚焦测试与 iOS Simulator 构建通过，并记录实际结果。
- [x] 如委派给 subagent，必须使用不继承主 agent 上下文的独立会话；本票正文是其唯一任务上下文。

## Comments

- 2026-08-31：实现完成。单条语义测试覆盖 Thought body、inline code metadata/等宽字体与 suffix；ExampleApp 视觉确认卡片、代码背景和外部正文边界正确。
