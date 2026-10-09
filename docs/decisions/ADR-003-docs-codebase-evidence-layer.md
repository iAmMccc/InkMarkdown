# ADR-003: 采用 `docs/codebase/` 作为工程证据基线层

## Status

Accepted

## Date

2026-07-15

## Context

- 已有 `contributor-guide`、`spec`、`current-status` 等文档（零基础 Tutorial 已迁出本仓）。
- Agent 需要简短、可核验、绑定源码的架构/风险摘要，避免与详细解释文档抢「单一真相」。
- `acquire-codebase-knowledge` 将七件套产出至 `docs/codebase/`。

## Decision

1. 采用 `docs/codebase/` 作为知识库的 **工程证据基线层**。
2. 内容原则：简短、附带 Evidence 路径、不重复 contributor-guide 的详细解释。
3. 冲突裁决优先级：源码 / 测试 > `current-status` 交付陈述 > `docs/codebase` 快照 > roadmap。
4. 技术栈、公开接口、测试方式或高风险点变化时，同步更新对应文件（也可重新扫描生成）。

## Alternatives Considered

### 只维护 contributor-guide

- Pros: 少一层目录
- Cons: 长文档不利于 Agent 快速核对证据
- Rejected: 分层维护效率更高

### 将七件套存入 `.omc` 或仅保留在本地

- Pros: 不占用主 docs 目录
- Cons: 违背「知识库随仓库版本管理」策略
- Rejected

## Consequences

- `docs/README.md` 导航已包含 codebase 入口。
- 与 `Serena` MCP (LSP) 索引互补：Markdown 供直接阅读，LSP 符号索引供结构与代码语义查询。
