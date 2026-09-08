# 十一、Block Presentation Continuity Module 技术设计

> **状态：Implemented in v0.0.2 working tree；release acceptance pending**
>
> **适用版本：v0.0.2 重构阶段**
>
> **相关决策：[ADR-009](../decisions/ADR-009-block-presentation-continuity.md)**
>
> **上层设计：[SwiftUI Adapter 总体技术设计](08-swiftui-adapter-architecture.md)**

本文定义 `InkMarkdownSwiftUI` 内部 Block Presentation Continuity module 的职责、interface、状态模型、reconciliation、生命周期、降级规则、迁移顺序和验收边界。当前 working tree 已完成该迁移；测试、Example 手工证据与剩余 release blocker 仍以源码和 [`current-status.md`](../current-status.md) 为准。

## 1. 要解决的问题

SwiftUI adapter 会反复收到新的 Markdown、configuration、trait、可用宽度和 render-session 阶段。一次更新可能重新产生 block value、更新已有 UIKit view、替换 view、从流式临时呈现提升为终态 block，或把同一 session 挂载到新的 host。

这些变化中有两类性质不同的责任：

1. **正确性契约**：同一呈现周期内，同一逻辑块的用户可见状态和交互状态必须连续，例如 Thought 已被用户折叠后，内容继续增长或进入终态时不能无故展开。
2. **实现优化**：在安全时复用 UIView 和测量结果。优化失败可以局部重建，但不能改变第一类契约。

现有实现把 identity、Thought 状态复制、view 预注册、reuse、height callback 和 measurement cache 分散在 renderer、render session、Coordinator 与 container。Block Presentation Continuity module 的目标是把这些共同变化的知识收进一个 deep module，让外部只提交一次 presentation snapshot，并消费一个原子 apply plan。

## 2. 范围与非目标

### 2.1 范围

- `InkMarkdownView` 的静态内容更新；
- `InkStreamMarkdownView` 的流式临时呈现；
- 流式内容到终态 blocks 的 promotion；
- 同一流式 session 的 detach / reattach；
- configuration、颜色、Dynamic Type、宽度和 trait 变化；
- block-local UIView 更新、替换、height invalidation 与测量缓存；
- 当前内建 stateful block 的 presentation state，首先是 Thought 折叠态。

### 2.2 非目标

- 修改 Markdown parser、block routing 或 `InkConfiguration` 语义；
- 让 `InkBlockRenderer` 感知 presentation cycle；
- 把网络、SSE/LLM transport 或聊天业务状态带入 adapter；
- 在 v0.0.2 为 custom block 发布完整 continuity 协议；
- 跨呈现周期持久化用户状态；
- 用文本相似度或通用 diff 猜测逻辑块；
- 承诺具体 UIView 实例始终复用；
- 建立 native SwiftUI renderer。

## 3. Module seam 与依赖方向

```text
Static SwiftUI adapter                 InkMarkdownRenderSession
  (static cycle owner)                   (stream cycle owner)
             │                                  │
             └──────────────┬───────────────────┘
                            ▼
              Block Presentation Continuity
              ├─ lineage / ordered records
              ├─ live presentation-state journal
              ├─ internal strategy registry
              ├─ attached UIView registry
              └─ measurement slots / revisions
                            │
                    atomic apply plan
                            ▼
              InkMarkdownContainerView
                 (mount + geometry only)
                            │
                            ▼
              InkRenderableBlock / UIView
```

依赖始终从 `InkMarkdownSwiftUI` 指向 `InkMarkdown`：

- `InkBlockRenderer` 解析 Markdown 并产出语义 `[InkRenderableBlock]`；
- continuity module 消费这些 block 及 adapter-only presentation evidence；
- `InkMarkdownContainerView` 执行 mount、unmount、ordering 和 frame layout；
- core renderer 不接收 cycle、lineage、view registry 或 measurement cache。

module 是逻辑边界，不要求所有 implementation 塞进一个类型。它可以有 state journal、strategy registry 和 attached resources 等内部 seam，但对 Coordinator / container 暴露一个窄 interface。

## 4. 生命周期所有权

每个**呈现周期**只有一个 continuity context：

| 路径 | 周期 owner | 周期结束 |
| --- | --- | --- |
| 静态 | 当前 SwiftUI adapter Coordinator | 静态 host 建立新的 presentation identity |
| 流式 | 当前 `InkMarkdownRenderSession` | `reset`、`cancel` 或开始下一份 session 文档 |

静态 Markdown 字符串变化本身不代表新周期：同一 Coordinator 收到的内容更新按同一周期 reconcile。adapter 无法仅凭字符串区分“编辑同一文档”与“替换为另一份文档”，因此宿主若切换到无关文档，必须建立新的 static presentation identity；module 不得用整篇 source hash 猜测。

流式 session remount 不开始新周期。为同时满足状态连续性和 UIKit 清理，module 内部分成两类 lifetime：

- **durable cycle state**：lineage、ordered records、last supplied state 和 live presentation state；跟随呈现周期；
- **attached resources**：host 引用、UIView、callback、measurement cache 与 attachment generation；跟随当前 UIKit attachment。

`detach` 必须释放 attached resources，但保留同一流式周期的 durable state。`reattach` 根据 durable state 创建新的 attachment；不要求沿用旧 UIView。`endCycle` 同时清空两类 state。

## 5. 核心模型

以下名称描述内部角色，不构成 public API 承诺。

### 5.1 Cycle identity

cycle identity 是 adapter 创建的 opaque token：静态 Coordinator 每次建立 presentation 时创建一次；render session 在新文档、`reset` 或 `cancel` 时更新。不得由整篇 Markdown hash 推导，也不得传入 `InkBlockRenderer`。

### 5.2 Lineage identity

lineage identity 表示一个逻辑块在当前周期内的连续生命线。它不是 block 内容 hash，也不是 UIView identity。判断顺序固定为：

1. adapter 内部调用者提供的显式稳定 identity；
2. 流式阶段与 promotion 之间的一一对应 lineage evidence；
3. 相同结构槽位、相同 concrete block type，且注册 strategy 明确确认可以延续；
4. 以上都不成立时创建新 lineage。

不得使用编辑距离、文本前缀相似度或“最像的旧块”等通用启发式。重复段落、重排或证据歧义时，错误迁移用户状态比局部重建更危险。

### 5.3 Presentation candidate

reconciliation 输入是 ordered presentation candidates：

- 静态和终态 candidate 包装 `InkRenderableBlock`；
- 流式 Thought candidate 可以携带与终态 Thought 一一对应的 lineage；
- stream remainder `UITextView` 是临时 presentation slot，不伪装成终态逻辑块。

一个临时 stream text slot 在 promotion 时退休；它可能对应多个终态 block，因此不能用单一负数 block index 冒充多条 lineage。只有能够证明一一对应的 candidate 才迁移 presentation state。

### 5.4 Continuity record

每条活跃 lineage 对应一个内部 record，至少包含：

- lineage identity；
- 最新 semantic block / candidate snapshot；
- 上一次 caller-supplied presentation state；
- 当前 live presentation state；
- 当前 strategy；
- 可选 attached UIView；
- slot-local revision；
- attachment generation。

ordered records 决定显示顺序。container 不读取 record，也不建立第二份 identity map。

## 6. 窄 interface

module 对 adapter 暴露四类 operation：

```text
attach(host)
reconcile(input) -> applyPlan
detach()
endCycle()
```

### 6.1 Reconciliation input

一次 input 是不可变 snapshot，包含：

- cycle identity；
- ordered candidates；
- resolved configuration / environment signature；
- 可用宽度；
- 明确的 promotion lineage evidence；
- 当前 attachment generation。

调用者不传“请复用这个 view”“清空某个 cache”或“预注册 identity”这类 implementation 指令。module 根据旧 record、strategy 和新 input 自己决定。

### 6.2 Atomic apply plan

一次 apply plan 完整描述当前 host 应执行的结果：

- ordered attached views；
- 需要 mount、unmount 或 replace 的 view；
- 需要重新布局或重新测量的 slot；
- 本轮 retired attachment；
- intrinsic-size invalidation 是否必要。

plan 必须绑定产生它的 attachment generation，且只能消费一次。container 负责执行 UIKit hierarchy 与 geometry，不得自行重新判断 identity、state migration 或 cache validity。

### 6.3 Interaction feedback

strategy 在创建或更新 view 时，把用户交互 callback 接回对应 lineage。module 收到变化后更新 live presentation state、递增受影响 slot revision，并请求 host 重新测量。旧 attachment generation 发出的迟到 callback 必须被忽略。

## 7. Reconciliation pipeline

每次 `reconcile` 按固定顺序执行：

1. **校验周期**：cycle 不同则结束旧周期；同周期继续。
2. **解析 environment**：计算本轮 environment signature，先确定全局 view / measurement 失效范围。
3. **匹配 lineage**：按严格 evidence chain 匹配旧 records；不做内容相似度猜测。
4. **合并 presentation state**：执行 caller input 与 live state 的优先级规则。
5. **选择 strategy**：内建 strategy 优先；custom block 进入 generic fallback。
6. **决定 view transition**：keep、update、adopt、replace 或 retire。
7. **更新 slot revision**：只对内容、状态、view 或 environment 影响到的 slot 标脏。
8. **生成 apply plan**：原子输出 ordered result；提交后再退休旧资源。

任何一步无法证明安全时，只降级当前 candidate，不回滚或清空其他 lineage。

## 8. Presentation state SSOT 与优先级

continuity module 是当前周期内 live presentation state 的 SSOT。以 Thought 折叠态为例：

| 事件 | 结果 |
| --- | --- |
| lineage 首次出现，incoming `isCollapsed = false` | 用 `false` 初始化 live state |
| 用户在 view 中折叠 | live state 更新为 `true`，对应 slot revision 增加 |
| Thought 文本增长，incoming 仍为 `false` | 视为普通内容更新；保留 live `true` |
| caller 后续把 supplied state 从 `false` 改为 `true` | 识别为明确 caller override，live state 设为 `true` |
| caller 再把 supplied state 从 `true` 改为 `false` | 再次识别为明确 override，live state 设为 `false` |
| 新 lineage 或新 cycle | 丢弃旧 live state，用新输入重新初始化 |

因此，block 的 presentation-state 字段是初始值或 caller input，不再是周期内 live 状态 owner。普通内容、configuration 和 trait 更新不能静默覆盖用户交互；caller 相对上次 supplied snapshot 的明确变化仍可控制状态。

## 9. Promotion 规则

promotion 是 representation transition，不是默认的新呈现周期。

- session 的 canonical source 与解析/显示阶段仍由 `InkMarkdownRenderSession` 拥有；
- continuity module 接收 streaming candidate 与 promoted block 的 lineage evidence；
- Thought lineage 和 live collapsed state 必须延续；
- session 不再把 view 中的 collapsed state 手工复制进 `session.blocks`；
- Coordinator 不再通过 `preRegisterView` 把 streaming UIView 塞入终态 identity map；
- strategy 可以 adopt compatible UIView，也可以重建并应用 live state；两者对调用者语义相同；
- 临时 stream text slot 在 promotion 时退休，终态 blocks 按各自证据建立 lineage。

Chat 终态继续绑定同一 `InkMarkdownRenderSession`，这是保留同一 presentation cycle 的前提；若宿主改用无 session 的静态 content snapshot，则进入新的静态周期，不承诺继承旧 state。

## 10. Strategy registry 与 custom block

adapter 内部 strategy registry 按 concrete candidate / block type 选择规则。一个内建 stateful strategy 负责：

- 判断相邻 snapshot 是否允许延续 lineage；
- 读取 caller-supplied state 并合并 live state；
- 创建、更新或 adopt UIView；
- 把 interaction callback 路由回 lineage；
- 判断内容或状态变化是否递增 slot revision。

v0.0.2 不把这些职责加入 `InkRenderableBlock`，也不把它们混入 `InkReusableBlock`：

- `InkRenderableBlock` 继续只要求 `makeView()`；
- `InkReusableBlock` 继续只表达完整语义等价与原地更新能力；
- 未注册的 custom block 不获得 presentation-state migration 保证；
- 同一结构槽位中的 custom `InkReusableBlock` 可以获得 best-effort view reuse，但该优化不能建立或迁移隐藏状态；
- custom block 无法确认兼容时，module 只重建该 view，不 fatal。

未来若出现真实 custom stateful block 需求，应另行设计独立、可选的 public continuity protocol；不得通过继续扩大 `InkReusableBlock` 快速塞入 identity 和状态职责。

## 11. Environment、view 与 measurement

### 11.1 Transition matrix

| 变化 | Lineage | Live state | UIView | Measurement |
| --- | --- | --- | --- | --- |
| 完全等价 input | 保留 | 保留 | strategy 可复用 | 保留 |
| 同 lineage 内容变化 | 保留 | 保留；明确 caller override 除外 | update 或 replace | 仅 affected slot 失效 |
| semantic configuration 变化 | 保留 | 保留 | 按 strategy update / replace | 全局 environment 失效 |
| width / Dynamic Type / trait 变化 | 保留 | 保留 | 能兼容则保留 | 新 environment signature 下重测 |
| streaming → promotion | 有证据者保留 | 必须保留 | adopt 可选 | affected slot 失效 |
| detach | 保留 durable lineage | 保留 | 释放 | 释放 attached cache |
| 同 session reattach | 保留 | 恢复 | 重建或安全 adopt | 重新测量 |
| 新 cycle / reset / cancel | 清空 | 清空 | 释放 | 清空 |

### 11.2 Measurement key

测量结果至少由以下维度确定：

```text
(lineage identity, slot-local revision, constrained width, environment signature)
```

- semantic content、live state 或 attached view 变化时，仅递增 affected slot revision；
- configuration 或全局 trait 变化时切换 environment signature，并清理不可再使用的旧 cache；
- Thought 展开/折叠必须递增自身 revision；
- removed lineage 立即移除对应 measurement；
- cache key 不使用整篇 source hash，也不依赖 UIView object identity。

height invalidation callback 必须携带 lineage 与 attachment generation。若 callback 来自已退休 view、旧 generation 或已结束 cycle，module 忽略它，避免旧异步结果污染新布局。

运行时宽度解析、`preferredMeasurementWidth`、高度门闩与宿主禁令见 [13 布局测量契约](13-layout-measurement-contract.md)；本文只定义 continuity measurement key 与失效语义。

## 12. MainActor 与资源清理

continuity module 操作 UIView、interaction callback 和 layout invalidation，因此 reconciliation 与 attachment operation 全部在 `MainActor` 上执行。Markdown parsing 是否在后台进行是 renderer 的独立决策；进入 module 的 input 必须已经是本轮不可变 snapshot。

`detach` 的最低清理要求：

- 断开 host 与 module 的强引用；
- 取消或替换 view callback；
- 退休 attached UIView registry；
- 清理 attachment-scoped measurement cache；
- 递增 attachment generation，使迟到 callback 无效；
- 不覆盖宿主自己注册的 render-session callback。

`endCycle` 在此基础上清空 lineage、state journal 和 last supplied state。清理必须幂等；重复 detach / end 不产生额外副作用。

## 13. 局部降级与诊断

以下情况进入同一个局部 fallback：strategy 缺失、lineage evidence 歧义、view 类型不兼容、原地更新拒绝、state 无法恢复或 apply plan 已过期。

fallback 行为固定为：

1. 当前 candidate 创建新 lineage 或新 view；
2. 只清除当前 block 无法证明安全的 presentation state；
3. 只失效当前 slot measurement；
4. 其他 records 与 views 保持不变；
5. Debug 构建输出可定位的诊断信息；Release 安静降级；
6. 不使用 fatal error，不猜测另一个旧 block，也不让未知 custom block 崩溃。

## 14. 实施顺序

本轮已按以下可验证路径完成迁移，避免一次性改写 renderer、session、Coordinator 与 container：

### Phase 1：建立内部 module

- 新增 continuity context、reconciliation input / apply plan、record 与 strategy registry；
- 先用 Thought strategy 和 generic fallback 打通最小 interface；
- 保持 public SwiftUI interface 与 `InkRenderableBlock` 不变。

### Phase 2：接入静态路径

- `InkMarkdownCoordinator.updateStatic` 只提交 semantic blocks 与 environment snapshot；
- container 不再自行派生 identity 或维护 previous-block truth；
- 验证内容、configuration、宽度和 Dynamic Type 更新。

### Phase 3：接入 streaming 与 promotion

- 用 presentation candidates 取代负 index streaming identities；
- Thought streaming candidate 与 promoted block 共享 lineage evidence；
- 删除 session 的 collapse 手工复制和 Coordinator 的 view pre-registration；
- detach / reattach 走 continuity context，而不是复制 callback 与 cache 清理规则。

### Phase 4：移除错误 seam

- 删除 core 中未发布的 `InkBlockIdentity`、`InkBlockIdentityResolver`、`IdentifiedRenderableBlock`、`InkStreamingSlotKind` 与 `InkDocumentEpoch`；
- 删除 `InkBlockRenderer.renderIdentified` / `zipIdentities`；
- 删除 renderer 的 `documentEpoch` 参数；
- 保留独立的 `InkReusableBlock` view-reuse interface。

### Phase 5：验收与文档收口

- 在现有 ExampleApp 场景内加入 continuity 手工检查入口；
- 运行最小关键链路自动化测试；
- 完成 build、manual check 和性能证据后，才更新 `current-status.md` 与发布状态。

2026-08-28 历史证据：三条关键 reconciliation 链、公开 API 兼容与 workload gate 通过；Example static/configuration/components/streaming/chat continuity 矩阵已手工检查。当前 v0.0.2 的 iOS/iPadOS 15 实际运行仍是 release blocker，因此这里的 implemented 不等于 v0.0.2 已发布。

## 15. 验收策略：Example 手工检查优先

UI 逻辑通过 ExampleApp 手工检查，不新增 UI automation 或 snapshot test。优先扩展现有场景 3–5，不为了 continuity 再复制一套顶层 demo。

### 15.1 Example 手工用例

| 用例 | 操作 | 必须观察到 |
| --- | --- | --- |
| 静态 continuity | 折叠 Thought；修改后续 Markdown、configuration、宽度与 Dynamic Type | 同一逻辑 Thought 保持折叠；高度及时更新，无空白或重叠 |
| 流式 promotion | 流式 Thought 尚未完成时切换折叠；继续追加并 `finish()` | promotion 前后状态一致；允许 UIView 改变，但画面与交互连续 |
| 同 session remount | 保留同一 session，离开并重新进入承载 view | 状态恢复；旧 view callback 不再触发，新布局正确 |
| 周期结束 | 执行 `reset` / `cancel` 或创建新静态 host | 使用新输入的初始状态，不继承旧周期 state |
| 歧义与 custom fallback | 插入、删除或替换无法可靠匹配的 block | 仅目标 block 重建；状态不串到相似 block；无崩溃 |

### 15.2 最小自动化关键链路

自动化测试只覆盖数据与状态决策的关键路径，可用 table-driven fixture 合并相邻变体：

1. **状态链路**：initial state → user mutation → content/environment update → caller override → promotion；
2. **identity 边界**：严格 evidence match → 歧义 fallback → new cycle reset → custom block 安全重建；
3. **生命周期与 revision**：detach → same-session reattach → stale callback ignored → affected slot revision 变化。

禁止为每个 block type、每种排列或每个内部分支复制测试；不断言 private dictionary、内部类型布局或具体 UIView 实例 identity。性能 locality 通过现有 profiling / debug counter 与 Example workload 核对，不把 view 复用实现写成公开行为契约。

## 16. Implementation guardrails

- 不新增从 `InkMarkdown` 到 `InkMarkdownSwiftUI` 的依赖；
- 不把 cycle / lineage 参数重新塞回 renderer；
- 不扩大 `InkRenderableBlock` 的必选 witness；
- 不让 state continuity 依赖 UIView 存活；
- 不让 container、Coordinator 或 session 保存第二份 identity / state journal；
- 不用 source hash 代表 presentation cycle；
- 不为当前 Thought 症状写 type-specific promotion 补丁；新增 stateful built-in 应通过 strategy seam 接入；
- 不在实现完成前把本设计写入 `current-status.md` 作为已交付事实。

## 17. 延后事项

- custom stateful block 的 public continuity protocol；
- 跨呈现周期或跨进程持久化 presentation state；
- block reorder animation；
- 通用 source-edit diff；
- native SwiftUI block implementation；
- 在真实 baseline 前承诺固定性能数字。
