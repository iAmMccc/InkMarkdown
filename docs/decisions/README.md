# Architecture Decision Records

本目录记录已确定的工程决策（说明背景与否决方案）。实现细节与交付状态以源码和 `current-status.md` 为准。

| ADR | 标题 | 状态 |
| --- | --- | --- |
| [ADR-001](ADR-001-swift-markdown-dependency-pinning.md) | swift-markdown 依赖：固定 revision + 可选本地缓存 | Accepted |
| [ADR-002](ADR-002-v1-platform-scope-ios-only.md) | v1.0 对外平台范围仅 iOS 14+ | Accepted |
| [ADR-003](ADR-003-docs-codebase-evidence-layer.md) | `docs/codebase/` 作为工程证据基线层 | Accepted |
| [ADR-004](ADR-004-v1-image-and-strikethrough-contract.md) | v1 图片与删除线行为契约 | Accepted |
| [ADR-005](ADR-005-stream-max-parse-length-configurable.md) | 流式 `maxParseLength` 可配置 | Accepted |

编号递增且只增不删；决策变更时补充新 ADR 并将旧条目标记为 Superseded。
