# ADR-009：块呈现连续性由 SwiftUI Adapter 持有

## Status

Accepted

## Date

2026-08-28

## Context

SwiftUI adapter 需要在静态内容更新、流式增量显示和终态 promotion 之间保持同一逻辑块的用户可见状态与交互状态。现有实现把相关知识分散在 renderer、render session、Coordinator 和 UIKit container：未发布的 SPI 在 render boundary 预派生 `(documentEpoch, blockIndex, kind)` identity，但生产路径仍在 adapter 内重新计算；Thought 折叠态同时存在于 block、session 与 UIView，并在 promotion 时手工复制和预注册 view。

块呈现连续性是正确性契约，UIView 复用和测量缓存只是优化。若继续让 renderer、block 或 view 各自承担一部分连续性，静态更新、promotion、environment 变化和 remount 会形成多套状态迁移规则，也会把 presentation lifetime 泄漏进 UIKit rendering engine。

## Decision

1. 采用根目录 [`CONTEXT.md`](../../CONTEXT.md) 中的“呈现周期”“逻辑块”“块呈现状态”和“块呈现连续性”定义。连续性覆盖静态更新、流式显示和 promotion；新的静态 host identity、新流式文档、`reset` 或 `cancel` 开启新周期。不得用 source hash 猜测静态周期切换。
2. 在 `InkMarkdownSwiftUI` adapter 内建立一个 deep Block Presentation Continuity module。`InkBlockRenderer` 只产出语义 block，不拥有 presentation identity、周期或状态。
3. 每个呈现周期拥有独立 continuity context。静态路径由 adapter Coordinator 持有；流式路径由 `InkMarkdownRenderSession` 持有其生命周期，使同一 session remount 后仍可恢复块呈现状态。UIKit attachment、callback、UIView 与测量缓存可以在 detach 时释放。
4. 逻辑块只通过严格证据延续：显式稳定 identity、流式 promotion lineage，或相同结构槽位与具体类型且对应 strategy 明确允许延续。不得使用通用文本相似度猜测；证据不足时按新块处理。
5. continuity module 是当前周期内 live 块呈现状态的 SSOT。block 提供初始或 caller-supplied 状态，UIView 上报用户变化，render session 继续只拥有 canonical source 与解析/显示阶段。
6. 状态输入采用受控/非受控兼容规则：首次输入初始化 live 状态；普通内容与 environment 更新保留用户状态；caller-supplied 状态相对上次输入明确变化时覆盖 live 状态。
7. promotion 必须延续 lineage 与块呈现状态；是否沿用同一个 UIView 由 block strategy 判断。无法安全复用时重建 view 并恢复状态。
8. configuration、宽度、Dynamic Type 或 trait 变化不结束连续性。它们可以触发 view 更新或重建，并按 slot revision 与 environment signature 失效测量缓存。
9. 内建 stateful block 通过 adapter 内部 strategy registry 参与 continuity。公开 `InkRenderableBlock` 保持最小 interface；`InkReusableBlock` 只表达 view 复用能力。未知 custom block 无法证明延续时局部重建，不 fatal，也不污染其他块。
10. adapter 通过原子 reconciliation interface 消费 ordered blocks、environment 和 lineage evidence，并产生 apply plan；调用者不得操作内部 identity、state journal、view registry 或 measurement maps。
11. 实施时删除 `0.0.1` 未包含且当前无生产消费者的 identity SPI：`InkBlockIdentity`、`InkBlockIdentityResolver`、`IdentifiedRenderableBlock`、`renderIdentified`、`zipIdentities`、streaming slot kind，以及 renderer 的 `documentEpoch` 参数。新的 lineage 类型只存在于 adapter 内部。

## Alternatives Considered

### Renderer 预派生 identity

拒绝。renderer 不知道 presentation cycle、promotion lineage、用户交互状态或 host attachment；把 `documentEpoch` 放入 renderer 会让 interface 承担不属于 Markdown 语义的知识。

### `InkThoughtBlock` / render session 继续持有 live 折叠态

拒绝。该方案要求静态、流式和 promotion 路径分别同步 block、session 与 view，无法形成统一连续性 seam。block 仍可携带初始或 caller-supplied 状态，但不再是周期内 live 状态的 owner。

### UIView 实例作为状态真相

拒绝。view 可能因 configuration、兼容性或 remount 被重建；正确性不能依赖实例复用。

### 通用内容 diff 推断逻辑块

拒绝。重复段落、重排和相似内容会把用户状态迁移到错误块。歧义时局部重建比错误延续安全。

## Consequences

- SwiftUI adapter 获得一个可独立推理的 continuity seam；static、streaming 与 promotion 共享同一状态和 identity 规则。
- `InkMarkdown` 继续保持 UIKit-first semantic renderer，不反向依赖 SwiftUI 或 presentation lifecycle。
- 同一 session remount 可以保留用户状态，同时安全释放旧 host 的 view、callback 和测量资源。
- 内建 stateful block 需要 adapter strategy；未来若 custom block 需要完整 continuity，应另行设计可选公开协议，不扩张本 ADR。
- ADR-008 关于 SwiftUI adapter 的总体方向仍然有效；其中将 Thought live 折叠态视为 `InkThoughtBlock` / session SSOT 的局部描述由本 ADR amend。
- 本 ADR 对应实现已进入 v0.0.2 working tree；这不表示版本已发布。当前测试、Example 手工证据与剩余 release blocker 仍以源码和 `docs/current-status.md` 为准。

## Related Documents

- [Block Presentation Continuity module 技术设计](../contributor-guide/11-block-presentation-continuity.md)
- [ADR-008：v0.0.2 以独立 SwiftUI Adapter Product 正式支持 SwiftUI](ADR-008-swiftui-adapter-architecture.md)
- [SwiftUI Adapter 总体技术设计](../contributor-guide/08-swiftui-adapter-architecture.md)
