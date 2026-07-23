# ADR-003: 采用 `docs/codebase/` 作为工程证据基线层

## Status

Accepted

## Date

2026-07-15

## Context

- 已有 `contributor-guide`、`spec`、`current-status` 等人类向知识库（零基础 Tutorial 已迁出本仓）。
- Agent 需要短、可核验、与源码绑定的栈/结构/风险摘要，避免与长文解释抢「单一真相」。
- `acquire-codebase-knowledge` 产出七件套到 `docs/codebase/`。

## Decision

1. **正式采用** `docs/codebase/` 为知识库中的 **工程证据基线层**。
2. 内容原则：**短、有 Evidence 路径、不复制** contributor-guide 长解释。
3. 冲突裁决：源码 / 测试 > `current-status` 交付陈述 > `docs/codebase` 快照 > roadmap。
4. 栈、公开入口、测试方式、高风险点变化时更新对应文件（可重跑扫描）。

## Alternatives Considered

### 只维护 contributor-guide

- Pros: 少一层目录  
- Cons: 长文难做 agent 快速证据核对  
- Rejected: 分层价值更高

### 把七件套塞进 `.omc` 或仅本地

- Pros: 不进主 docs  
- Cons: 与项目「知识库进仓库」策略不一致  
- Rejected

## Consequences

- `docs/README.md` 导航已包含 codebase 入口。
- 与 `codebase-memory-mcp` 索引互补：markdown 给人读；图索引给结构查询（见会话说明）。
