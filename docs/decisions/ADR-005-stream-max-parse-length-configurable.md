# ADR-005: 流式 maxParseLength 改为可配置（默认 50_000）

## Status

Accepted

## Date

2026-07-15

## Context

- `InkStreamRenderer` 将 `maxParseLength` 硬编码为 `50_000`。
- 超限时 `append` 直接 return；`finish` 截断后再解析——行为对宿主不透明，且不同产品（短聊 vs 长报告）阈值需求不同。

## Decision

1. **默认值保持 50_000**（兼容现有行为与性能假设）。
2. **配置化**：阈值进入公开配置面（优先 `InkConfiguration` 或与流式强相关的明确字段），宿主可提高/降低。
3. **文档契约**：写清超限语义（停止追加解析 / finish 截断），避免静默「丢字」误解。
4. **实现可后续落地**；本 ADR 锁定 API 方向，不要求与本文同提交改代码。

## Alternatives Considered

### 永久硬编码 50k

- Pros: 实现简单  
- Cons: 长文档场景无法扩展  
- Rejected: 作为唯一策略

### 取消上限

- Pros: 最灵活  
- Cons: 易在异常 SSE 下 OOM / 主线程压力  
- Rejected: 默认无上限

### 仅文档说明、不改 API

- Pros: 零代码  
- Cons: 宿主无法调  
- Rejected: 作为最终态

## Consequences

- 落地时应补：配置字段中文注释、超限行为测试、`current-status` / stream 文档一句说明。
- 性能闸门数据集远小于 50k，默认值变更需重评基准注释。
