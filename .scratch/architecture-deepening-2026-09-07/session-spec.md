# 渲染会话宿主接管详细规格

Status: ready-for-agent

Parent spec: [三方向规格](spec.md)。本文件是实现设计，不是实施授权。

## 1. 当前调用链

[InkStreamMarkdownView](../../Sources/InkMarkdownSwiftUI/Views/InkStreamMarkdownView.swift) → [InkMarkdownRepresentable](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownRepresentable.swift) → [InkMarkdownCoordinator](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift) → continuity.reconcile → container.apply → session.bindTextView。

Coordinator 在 apply 成功后依次保存 attachmentToken、应用暂存环境、安装 observer、绑定文本；teardown 则先 detach、移除旧 observer 和 text binding，再唤醒等待 owner。Session 的 textViewBindingOwner 与 presentationDisplayUpdateObserverOwner 分开保存。正确性依赖这些顺序在多处一致。

[InkBlockPresentationContinuity](../../Sources/InkMarkdownSwiftUI/Continuity/InkBlockPresentationContinuity.swift) 已是 deep module。保留其 staged apply、lineage、Thought live state、measurement 与 attachment authority，不再拆出第二套。

## 2. 最终所有权

| module | 保留/迁入的状态 | 不拥有 |
| --- | --- | --- |
| InkMarkdownRenderSession | canonical source、sourceLimit、Thought scanner、renderer、阶段、published hopper；continuity context 生命周期；一个成组呈现绑定记录 | 宿主 UIView 的强长期持有、环境等待队列 |
| InkBlockPresentationContinuity | cycle 内逻辑块匹配、live state、revision、attachment token、waiting reconcile registration | transport、canonical source、全局宿主配置 |
| 新 `InkStreamingPresentationHost` | 当前弱 session/container、streamTextView、已提交 token、session cycle 快照、pending environment、重入 guard；接管/释放整个流程 | 自己的 Thought 折叠真相、自己的 lineage/cache、解析输入 |
| InkMarkdownCoordinator | static/blocks 路径、静态 continuity、配置默认 handler；静态/流式模式切换入口 | 流式的 owner/token/observer/bind 顺序 |
| InkMarkdownContainerView | 既有 apply plan 和测量执行 | 新的接管状态机 |

新 host 放在 `Sources/InkMarkdownSwiftUI/Bridge/InkStreamingPresentationHost.swift`。必要的小 record 值类型同文件放置，不按每个状态新建一个 module。

## 3. 内部 interface 与类型关系

```swift
// 概念形状；全部 internal @MainActor，不对产品用户暴露。
InkStreamingPresentationHost.update(
  session: ..., container: ..., renderEnvironment: ...,
  constrainedWidth: ..., environmentSignature: ...
) -> Bool
InkStreamingPresentationHost.teardown(from: ...) // 幂等
```

`Bool` 表示这次是否成功应用呈现，不表示会话已经结束。可省略的 width/signature 用现有 container 度量解析。调用方不逐项绑定 observer、textView 或操作 token。

默认链接配置必须保持稳定语义身份。沿用 `InkMarkdownSwiftUI.default-link-opening.v1`；可以将现有 resolvedConfiguration 逻辑内聚成包内静态函数供两个路径复用，不新增逐次生成 identity 的 closure。

Session 成组绑定记录的概念 interface：安装 owner + 可选 textView + private display observer，返回一个内部 grant；更新/释放必须匹配该 grant。grant 只负责撤销 Session 内的一组资源，不拥有 continuity attachment 权限。只有 host 在 container.apply 成功后才可申请绑定。Observer 可以存在而 textView 为 nil（finished 状态仍需环境/尺寸更新）。旧 owner 的 release 不清掉新 owner 的记录。

迁移期保留旧内部函数的转发仅为编译兼容；ticket 25 删除所有已无调用者的旧 owner 字段与接口。公开 `onDisplayUpdate` 不得被覆盖、移除或改为 private observer。

## 4. 宿主状态与事件

| 宿主状态 | 含义 | 可发生操作 |
| --- | --- | --- |
| detached | 无当前 session attachment | 接收 update，开始登记 |
| waiting | 已登记新 host，旧 host 尚拥有 continuity attachment | 暂存环境；不能 bind renderer 或写 session 环境 |
| committed | apply 成功、token 有效 | 成组绑定、接收显示更新、应用环境、尺寸重算 |
| releasing | 正在释放自身资源 | 禁止旧 callback 重入；释放后唤醒等待者 |

不要求在源码公开这四个 enum；要求所有操作符合表中语义。continuity.ownsAttachment 是权限真相，host 不能用本地 committed bool 替代它。

### update/commit 顺序

1. 检查 session 或 container 是否变化；先释放旧上下文，再使用新上下文。不同 session 不继承 pending environment。
2. 暂存这次 host 的环境，登记 continuity reconcile callback；waiting 不得写 active host 的环境。
3. 按 session 当前阶段生成 snapshot，continuity.reconcile，再 container.apply。apply 失败保留 waiting，不能 commit binding 或 environment。
4. apply 成功后保存 token；在同一 MainActor 同步段建立 Session 成组绑定，使后续环境通知只到新有效 owner。
5. 仅在 token 仍有效时应用 pending environment。同步环境更新可能触发观察者；重入 guard 抑制嵌套 apply，退出后最多安排一次补充 reconcile。
6. 补充 reconcile 必须携带 session 身份、cycle 与 host generation 校验；等待执行期间 cancel/reset/换 host 后旧任务不得重新接管。

### teardown/handoff 顺序

1. 先进入 releasing，作废 host 自身排队 callback generation。
2. 仅当 ownsAttachment(token) 时尝试 continuity.detach + container.apply。
3. container 不存在或 apply 失败时，使用既有 token 验证的 discardAttachment 路径；不得无条件清理其他 owner 的 attachment。
4. 移除自己的 continuity observer、Session binding grant 和 container callbacks；不能移除新 host 的登记。
5. 清空自身 session/container/textView/环境引用和 transient 状态；同一 session 的 live Thought 状态留在 continuity context。
6. 最后唤醒等待 owner。旧 observer 必须已移除，因为新环境 apply 可能同步发显示通知。

## 5. 阶段、块与呈现周期

- idle/cancelled：不要求 remainder text attachment；snapshot 为空。finish 空会话仍按既有行为完成。
- streaming/finishing/displayingFinalContent：显示可选 Thought 和 remainder；Thought structural slot 0、remainder slot 1 的既有规则保持。
- promoted：消费 Session blocks，只给首个符合条件的 Thought 传递现有 promotion evidence，不能用文本相似度猜测。
- remainder stable identity、content revision 继续来自 Session；不在 host 另造第二个序列号。
- reset/cancel 开启新呈现周期；token 可能已失效，但周期变化是当前 mounted host 合法清理旧视图的原因。不能仅以 token 无效就忽略本次周期清理。
- 同 session remount 保留 live 块状态；Session 替换不继承旧 pending environment 或 binding。静态/流式模式切换先 teardown 当前模式，再让另一个模式使用 container。
- UIKit reader 的 source/parse/display 逻辑、Session public state 顺序和 PublishHopper 保持；本轮不能把 default-mode deferred publish 换成 DispatchQueue.main.async。

## 6. 验收场景

| ID | 场景与可观察断言 |
| --- | --- |
| S-01 | 单 host append→finish 后完整文本、Thought 和终态块保持；公共 state 顺序不变。 |
| S-02 | B 等待 A 的 attachment 时，B 的 dark 环境不改变 A 的 light；A 可继续接收 delta。 |
| S-03 | 等待中的 B 先 teardown，不解绑 A 的 textView/observer；A 后续 delta 可见。 |
| S-04 | A teardown 后 B 同步接管最新内容，应用 B 最后暂存环境；旧 A 回调不再进场。 |
| S-05 | B 接管后旧 A 再 teardown/release binding 无副作用；B 后续正文正常。 |
| S-06 | 同 session detach/remount 后 Thought 展开态保持，即使 UIView 被重建；不同 session 不迁移状态。 |
| S-07 | cancel/reset 使旧 mounted Thought/remainder 清理；旧异步环境补充 reconcile 不复活旧 cycle。 |
| S-08 | finish 后修改 environment 仍更新终态呈现；公开 onDisplayUpdate 与内部 observer 都保持自身角色。 |
| S-09 | width、Dynamic Type、trait 修改不结束呈现周期；仅受影响测量/块按现有 continuity 规则更新。 |
| S-10 | container 缺失或 detach plan apply 失败时可释放自己的 attachment 并让等待者继续，不能遗留 owner。 |
| S-11 | static→streaming→static 与 session A→B 切换不遗留旧 observer、textView 或 pending environment。 |
| S-12 | completion/promotion 延迟发布前 cancel/reset，旧 @Published 变更被作废；不在 SwiftUI update 栈同步发布。 |
| S-13 | 真实 UIHostingController 的移除/重新插入 InkStreamMarkdownView 可继续显示相同 Session 的后续文本；不是仅手工调 Coordinator 的替代验收。 |
| S-14 | Coordinator 不再维护流式的 token/cycle/observer/text-binding 接线；没有第二套 continuity 状态或公共新协议。 |

## 7. 测试策略与迁移

保留 [InkBlockPresentationContinuityTests](../../Tests/InkMarkdownSwiftUITests/InkBlockPresentationContinuityTests.swift) 的真实 host handoff、stale callback 与 cycle 测试；保留 [Session tests](../../Tests/InkMarkdownSwiftUITests/InkMarkdownRenderSessionTests.swift)、[workload](../../Tests/InkMarkdownSwiftUITests/InkMarkdownAdapterWorkloadTests.swift)、[loop prevention](../../Tests/InkMarkdownSwiftUITests/InkMarkdownLoopPreventionTests.swift)、[source limit](../../Tests/InkMarkdownSwiftUITests/InkRenderSessionSourceLimitTests.swift)。

新增 host 测试可放 `InkStreamingPresentationHostTests.swift`，通过 real Session + continuity + container 测试新内部 interface，不 mock continuity 决策。真实 SwiftUI remount 放现有 SwiftUI test target，以 UIHostingController + 明确 rootView 切换/布局驱动；不新建 App target 或 broad UI 自动化矩阵。

执行 18–26：先固化生命周期事实、Session 成组绑定；展开 host 的 snapshot、所有权释放、环境/事件流程；生产 Coordinator 一次切换到完整 host；补实际 remount；删除旧代码后方向验收。阶段性代码必须编译、受测，未接入生产的 host 不算已交付。
