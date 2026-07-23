# ADR-005: 流式 maxParseLength 改为可配置（默认 50_000）

## Status

Accepted

## Date

2026-07-15

## Context

- `InkStreamRenderer` 将 `maxParseLength` 硬编码为 `50_000`。
- 超限时 `append` 直接返回；`finish` 截断后再解析——此行为对宿主不透明，且不同应用场景（对话与长报告）对上限要求不同。

## Decision

1. **默认值保持 50_000**（兼容现有行为与性能假设）。
2. **配置化**：阈值进入公开配置面（优先 `InkConfiguration` 或流式配置字段），宿主可按需调整。
3. **文档契约**：明确超限处理规则（停止追加解析与 finish 截断），避免出现截断误解。
4. **实施计划**：本 ADR 确定 API 演进方向，代码改动后续单独提交。

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

- 落地时补充：配置字段注释、超限行为测试、`current-status` 及流式相关说明。
- 性能基准数据集小于 50k，默认值变更需重新评估性能基准。
