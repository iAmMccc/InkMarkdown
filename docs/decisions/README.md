# Architecture Decision Records

本目录记录已确定的工程决策（说明背景与否决方案）。实现细节与交付状态以源码和 `current-status.md` 为准。

| ADR | 标题 | 状态 |
| --- | --- | --- |
| [ADR-001](ADR-001-swift-markdown-dependency-pinning.md) | swift-markdown 依赖：固定 revision + 可选本地缓存 | Accepted |
| [ADR-003](ADR-003-docs-codebase-evidence-layer.md) | `docs/codebase/` 作为工程证据基线层 | Accepted |
| [ADR-004](ADR-004-v1-image-and-strikethrough-contract.md) | v1 图片与删除线行为契约 | Amended（默认占位、ADR-006 opt-in 真图、删除线已支持） |
| [ADR-005](ADR-005-stream-max-parse-length-configurable.md) | 流式长度上限可配置（历史名 `maxParseLength`；现名 `maximumSourceLength`） | Accepted |
| [ADR-006](ADR-006-opt-in-image-rendering.md) | opt-in 图片真图渲染（默认保持占位） | Accepted |
| [ADR-007](ADR-007-local-generated-diagrams-and-formulas.md) | LaTeX / Mermaid 本地生成图复用所选后端 | Accepted |
| [ADR-008](ADR-008-swiftui-adapter-architecture.md) | v0.0.2 以独立 SwiftUI Adapter Product 正式支持 SwiftUI | Accepted（由 ADR-009、ADR-010 amend） |
| [ADR-009](ADR-009-block-presentation-continuity.md) | 块呈现连续性由 SwiftUI Adapter 持有 | Accepted |
| [ADR-010](ADR-010-v0.0.2-minimum-platform-ios-15.md) | v0.0.2 最低平台升级为 iOS / iPadOS 15 | Accepted |
| [ADR-012](ADR-012-pluggable-image-management.md) | 可替换图片管理后端与可选 Kingfisher product | Accepted |

编号不复用。只保留仍有效的决策；被替代文件删除前，将仍有效的约束归并到当前决策并更新引用。
