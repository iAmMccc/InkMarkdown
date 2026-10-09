# ADR-005: 流式 maxParseLength 改为可配置（默认 50_000）

> 历史命名说明：本 ADR 记录决策时使用 `maxParseLength`；当前对外符号为 `InkStreamRenderer.maximumSourceLength`。
>
> 实施状态：2026-08-28 已落地。`InkStreamRenderer` 与 `InkMarkdownRenderSession`
> initializer 均接受 `maximumSourceLength`，默认 50_000。

## Status

Accepted

## Date

2026-07-15

## Context

- `InkStreamRenderer` 将 `maxParseLength` 硬编码为 `50_000`。
- 超限时 `append` 直接返回；`finish` 截断后再解析——此行为对宿主不透明，且不同应用场景（对话与长报告）对上限要求不同。

## Decision

1. **默认值保持 50_000**（兼容现有行为与性能假设）。
2. **配置化**：阈值进入 renderer/session initializer，而不是全局 `InkConfiguration`。长度是流式会话资源边界，不属于静态 Markdown 渲染语义。
3. **不可变 snapshot**：会话创建时归一化并固化阈值；session 与 renderer 共享同一 snapshot。
4. **canonical source**：append 入口只接受上限内的 prefix；reset、finish、终态 attributed string 与 Block Promotion 只消费同一份已接受 source，不在各阶段重复截断。
5. **无效值**：0 或负数回退默认 50_000，不允许通过无效值取消保护。

## Alternatives Considered

### 永久硬编码 50k

- Pros: 实现简单  
- Cons: 长文档场景无法扩展  
- Rejected: 无法满足长文需求

### 取消上限

- Pros: 无长度限制  
- Cons: 异常 SSE 数据易引发内存泄露或主线程卡顿  
- Rejected: 不能作为默认方案

### 仅文档说明、不改 API

- Pros: 无需修改代码  
- Cons: 宿主无法自定义阈值  
- Rejected: 无法满足实际配置需求

## Consequences

- 已补充公开 initializer 注释、renderer/session 边界测试、`current-status` 及流式相关说明。
- 性能基准数据集小于 50k，默认值变更需重新评估性能基准。
