# 01: 固化 sourceFilter 顶层一次性边界

Status: ready-for-agent

## Summary

让自定义源码预处理在每次顶层 Markdown 渲染中只执行一次。Thought 闭标签后的尾随正文仍进入标准 Block 渲染，但必须作为已经预处理的内容继续解析，不能再次调用 `sourceFilter`。这样，非幂等 filter 也不会重复改写内容或造成递归。

## Context

Blocked by: None.

## Acceptance

- [x] 使用一个包含完整 Thought、尾随 Markdown 和非幂等 `sourceFilter` 的关键路径，证明一次顶层渲染只调用 filter 一次，并能在有限时间内完成。
- [x] 尾随正文继续按标准 Markdown 语义生成对应 Block；Thought 卡片与尾随正文的边界保持不变。
- [x] 内部 prepared-source seam 不暴露 presentation identity、cycle 或 SwiftUI lifecycle 职责，也不破坏现有公开 API 的源兼容性。
- [x] 只扩展最接近该调用链的现有测试，不建立 sourceFilter 与 Thought 的排列矩阵。
- [x] 当前 checkout 的聚焦测试与 iOS Simulator 构建通过，并记录实际结果。
- [x] 如委派给 subagent，必须使用不继承主 agent 上下文的独立会话；本票正文是其唯一任务上下文。

## Comments

- 2026-08-31：实现完成。非幂等 filter 关键路径证明顶层调用一次，Thought 与 suffix 标题均保留；合并聚焦测试 60/60、全量 335 通过/0 失败/1 跳过。
