# 06: 收缩旧 renderer identity seam

Status: complete

**What to build:** 在静态、环境、custom fallback、流式 promotion 和 lifecycle 路径全部迁移后，删除未发布且已经失去职责的 renderer-side presentation identity 通道及重复状态路径，让 renderer、continuity module 与 UIKit container 的边界唯一且清晰。

**Blocked by:** 02: 覆盖环境与测量变化下的连续性; 03: 收紧身份判定并隔离 custom block 降级; 04: 打通流式 Thought promotion 连续性; 05: 完成 attachment 与呈现周期边界

- [x] 删除未包含在 `0.0.1` 中的 identity SPI、identified-render helpers、streaming slot kind、source-derived epoch helper 和 renderer presentation-epoch 参数。
- [x] renderer 只产生 Markdown 语义 blocks，不持有 cycle、lineage、view registry、measurement cache 或 live presentation state。
- [x] Coordinator、render session 与 container 不再各自维护可竞争的 identity/state truth；continuity module 是周期内唯一事实源。
- [x] container 只执行 apply plan 所描述的 ordering、mount、unmount、replace 和 invalidation，不重新 reconcile。
- [x] 保留 `InkReusableBlock` 的独立 view-reuse 职责，并保持 `0.0.1` 已发布 public API 源兼容。
- [x] 全仓确认无旧 identity/epoch seam 的生产引用，也没有为兼容未发布 SPI 留下转发壳或双写路径。
- [x] 当前 checkout 的 iOS Simulator 构建和三条关键链路测试保持通过；本票不新增行为测试矩阵。

执行前读取父 spec、ADR-009 和仓库协作规则，并先检查当前 dirty working tree。若委派 subagent，必须使用无上下文继承模式，并提供包含仓库、范围、依赖、约束、证据和输出契约的完整 brief。

## Comments

- 2026-08-28：`Sources/`、`Tests/` 与 `ExampleApp/` 中搜索旧 identity/epoch symbols 为 0 命中。`InkRenderableBlock` 保持最小 `makeView()` 契约，`InkReusableBlock` 仍只表达 view reuse；非 Sendable 自定义 `InkBlockHandler` 的源兼容契约测试通过。
- 2026-08-28：continuity module 独占 cycle、lineage 与 live state；Coordinator 负责提交 snapshot，container 只执行一次性 plan 与 geometry。三条关键链路和完整 iOS Simulator 回归通过，未为本票新增测试矩阵。
