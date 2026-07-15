# Architecture Decision Records

本目录记录**已接受的工程决策**（为什么这样定、否决了什么）。实现细节与当前交付状态仍以源码、`current-status.md` 为准。

| ADR | 标题 | 状态 |
| --- | --- | --- |
| [ADR-001](ADR-001-swift-markdown-dependency-pinning.md) | swift-markdown 依赖：固定 revision + 可选本地缓存 | Accepted |
| [ADR-002](ADR-002-v1-platform-scope-ios-only.md) | v1.0 对外平台范围仅 iOS 14+ | Accepted |
| [ADR-003](ADR-003-docs-codebase-evidence-layer.md) | `docs/codebase/` 作为工程证据基线层 | Accepted |
| [ADR-004](ADR-004-v1-image-and-strikethrough-contract.md) | v1 图片与删除线行为契约 | Accepted |
| [ADR-005](ADR-005-stream-max-parse-length-configurable.md) | 流式 `maxParseLength` 可配置 | Accepted |

编号只增不删；决策变更时写新 ADR 并标记旧条目为 Superseded。
