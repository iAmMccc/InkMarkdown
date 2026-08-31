# 02: 让 promoted environment 更新立即到达 mounted view

Status: ready-for-agent

## Summary

让已经完成 promotion 且仍挂载在 SwiftUI host 中的流式 Markdown，在主题或 Dynamic Type 环境变化后立即刷新可见 Block、测量和布局。刷新不能依赖新的 append、再次 promotion 或其他偶然 SwiftUI 更新。

## Context

Blocked by: None.

## Acceptance

- [x] promotion 完成后更新 render environment，已挂载视图在没有后续流式事件的情况下显示新颜色、字体和布局结果。
- [x] 更新通过现有 session-to-host display seam 送达；不要求宿主观察整个 render session，也不引入第二套状态事实源。
- [x] Thought 的 live state、lineage 和 presentation cycle 在环境更新中保持连续，只失效受影响的 measurement。
- [x] 扩展现有 mounted stream-view 关键链路测试；不新增环境组合测试矩阵。
- [x] 使用 ExampleApp 手工检查 promotion 后的主题或 Dynamic Type 变化，确认可见内容和高度立即更新且折叠态不丢失。
- [x] 当前 checkout 的聚焦测试与 iOS Simulator 构建通过，并记录实际结果。
- [x] 如委派给 subagent，必须使用不继承主 agent 上下文的独立会话；本票正文是其唯一任务上下文。

## Comments

- 2026-08-31：实现完成。mounted view 关键测试通过；ExampleApp 中 promotion 后切换特大字号，标题高度从 30 增至 50.33，已折叠 Thought 仍为“已折叠”。
