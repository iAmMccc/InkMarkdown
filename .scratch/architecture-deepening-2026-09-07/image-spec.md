# 图片呈现订阅生命周期详细规格

Status: ready-for-agent

Parent spec: [三方向规格](spec.md)。本文件是实现设计，不是实施授权。

## 1. 当前事实

- [InkImageStore](../../Sources/InkMarkdown/Rendering/Image/InkImageStore.swift) 已统一缓存、inflight、排队、预算、loader identity 和最后订阅取消；保留它。
- [InkImageBlock](../../Sources/InkMarkdown/Rendering/Image/InkImageBlock.swift) 在 configure 中切换 ready/loading/queued/rejected，并维护 loadToken、subscription。
- [InkImageAttachment](../../Sources/InkMarkdown/Rendering/Image/InkImageAttachment.swift) 另有 MaterializationIdentity、materializationGeneration 和 subscription；纯富文本构造不启动加载。
- [InkImagePreviewController](../../Sources/InkMarkdown/Rendering/Image/InkImagePreviewController.swift) 用私有 InkPreviewStoreLoadBridge 把 Store subscription 转成 async；controller 另保留 highResGeneration 和 task。
- Store 的 subscriber 完成值为 `UIImage?`，失败原因已丢失；本轮不能假装从它恢复具体网络错误。

## 2. module 与 seam

新增 `Rendering/Image/InkImagePresentationLoad.swift`，内部 `@MainActor` 引用类型，代表某个呈现所有者当前的一次 Store 观察。它不拥有图片缓存或预算，不设置默认 Store，不处理 URL 业务规则，不参与像素尺寸计算。

概念 interface：

```swift
// internal @MainActor，具体拼写可遵循仓库习惯。
start(source:display:loader:store:onPending:onCompletion:)
cancel()
// async convenience 只在内部需要时增加，必须复用同一订阅生命周期。
```

- start 总是替换自身的前一次观察；传入已经选定的 Store 与 loader。
- 不做全局请求去重。Store 负责资源去重；attachment 自身仍用 MaterializationIdentity 决定是否需要 start。
- onPending 只表达 loading/queued 的占位阶段，不把队列数组或调度状态交给调用方操作。
- 完成结果为 image / loadFailed / rejected；cancel 不触发 block/attachment 的失败外观。async adapter 把 cancel 映射为 CancellationError。
- 不把 onLoad convenience 与 subscribe 同时使用，避免重复订阅。

### 真实 adapter

保留 `InkImageLoading` seam：默认 URL loader、生成内容 loader 与测试 controlled loader 已是真实变化。不要为每个 image view 另建协议。Block、attachment、preview 作为呈现 adapter，仅保留视觉/交互与必要的宿主 identity。

## 3. 状态、所有权与回调顺序

| 状态/事件 | 操作 | 外部回调 |
| --- | --- | --- |
| idle + start A | 生成 request generation；resolve 一次 | 由结果决定 |
| ready | 当前请求完成，不保留 subscription | image 同步可用，不先闪占位 |
| loading / queued | 注册并保存一个 subscription | onPending 一次，完成至多一次 |
| rejected | 完成并清理 | rejected 一次，无隐藏 retry |
| active A + start B | 先作废 A generation，再取消 A subscription，再启动 B | A 晚到不外发 |
| active + cancel | 作废 generation、断开 closure、取消 subscription | callback 模式不报错；async 等待者终止 |
| completed + cancel | no-op | 无重复终结 |
| completion 中再次 start | 旧请求终结状态已先写入 | 新请求不能被旧清理代码取消 |
| owner 释放 | 不保留 owner，订阅最终取消 | 不向已释放 owner 外发 |

实现要求：

1. 先使旧 generation 无效，再释放 subscription；不能先 cancel 再换 token。
2. ready 路径保持同步供图，block 不短暂进入 loading placeholder。
3. Store 在 broadcast 后仍清理自身 subscribers/inflight。来自 loading/queued 的结果应经一个 MainActor delivery turn 后再向呈现外发；在该 turn 再校验 generation。避免外部完成回调重入 resolve/cancel，干扰 Store 当前广播。只延迟异步完成，不延迟 ready 命中。
4. loading/queued 的 subscription 必须在调用 onPending 前安装到当前 generation；onPending 可能经高度回调同步触发重配/取消，返回后不得再把旧 subscription 写回。注册动作若同步终结，也必须检查 generation 后再保存句柄，失效句柄立即取消。
5. 待交付结果不需要保留 UIView。内部 transition 清理自己的 terminal state 后才调用外部 completion；旧 completion 返回后不得再清空新的 generation。
6. 切换/取消应在现有 actor isolation 下完成；不要新增 `@unchecked Sendable` 掩盖捕获错误。attachment 的 nonisolated init/measurement 不能直接访问 MainActor 状态。
7. deinit 无法直接调用 MainActor 方法时，使用已持有的取消句柄或不捕获 self 的 MainActor 清理任务；必须有释放测试，不能只让编译器通过。无需变更公开初始化器的 isolation。
8. 图片呈现 module 强持有注入的 Store 直到观察终止；默认 Store 长期生命周期仍由现有渲染宿主/attachment/preview 决定，不能让弱注册表变成强全局缓存。

## 4. 三个呈现入口保留的差异

| 入口 | 保留在 adapter 的知识 | 移入共享 module |
| --- | --- | --- |
| Block | containerWidth/scale、placeholder/fallback、load 后尺寸、tap、prepareForReuse | subscription、loading/queued 接线、当前请求晚到抑制 |
| Attachment | display + Store + loader 身份的重复 materialize 判定、layoutManager、段落高度、notification、renderedImage 纯测量快照 | Store 观察与取消、加载 generation 的重复实现 |
| Preview | maxPreviewPixel、bypassStore、手势、high-res task、降采样图保底、controller 显示 generation | Store subscribe→async 的取消与一次终结 |

attachment 的 MaterializationIdentity 与 preview 的 highResGeneration 不是必须删除的重复字段：前者决定是否重请求，后者保护 controller 跨 task 生命周期。只有完全被共享模块覆盖的请求 token 才删除。

预览 `bypassStore=true` 继续直接 await loader；不得为了“统一”强制通过 Store。`false` 必须使用注入/自持 Store。取消或失败继续显示原降采样图，不新增错误弹窗。

## 5. async adapter 终结规则

将当前 private bridge 的 continuation 一次终结责任迁入共享 implementation 或紧邻的 private adapter；它可以有自己的 continuation 状态，但不能再次解释 Store 四分支。

- cancellation 在 continuation 安装前发生：安装后立刻抛 CancellationError，不能启动请求或永久挂起。
- 安装后取消：先终结/取消当前观察，resume 一次；迟到结果忽略。
- 同步 ready：continuation 成功一次；之后 cancel 无效。
- rejected / nil completion：分别维持现有 rejection 和 decodeFailed 等内部错误映射，不承诺新的 public 错误精度。
- 任务取消 handler 如在非 MainActor 执行，只安排捕获安全取消句柄的清理，不能跨 actor 操作 UIKit。

## 6. 验收场景

| ID | 场景与可观察断言 |
| --- | --- |
| I-01 | ready 命中不调用 loader、不调用 pending、不闪占位，结果一次。 |
| I-02 | loading 和 queued 均只订阅一次；完成 image 一次，nil 失败一次；无自动重试。 |
| I-03 | A 未完成即被 B 替换，A 成功或失败晚到都不改 B 的图片/占位；B 正常完成。 |
| I-04 | queued 最后订阅 cancel 后请求不启动；inflight 最后订阅 cancel 到达 loader；还有另一订阅时不取消共享加载。 |
| I-05 | pending/completion 重入 start/cancel 不取消新请求、不写回旧句柄；同一实例重复 cancel 无重复外发。 |
| I-06 | Block prepareForReuse 清除图片与旧结果；缓存命中仍保持紧凑尺寸，失败 fallback/tap/.button 语义不变。 |
| I-07 | Attachment 同 identity 不重启；display、Store 或 loader 变化重请求；布局重绑后只失效当前段落/宿主。 |
| I-08 | Attachment 构造/纯测量不发起网络；图片抬升段落最大行高但保留缩进/对齐/最小行高等几何。 |
| I-09 | async 的 pre-cancel、安装后 cancel、同步 ready、失败均有界结束且至多 resume 一次。 |
| I-10 | Preview bypassStore 的两条语义保留；关闭预览取消当前任务，旧 high-res 不覆盖后续显示。 |
| I-11 | 默认 Store/显式 Store/生成内容 loader 隔离保持；释放呈现宿主不被 callback 或 bridge 留住。 |
| I-12 | 三个 Store 呈现入口不再各自 switch resolve/持有重复 subscription 状态；公共 interface 与资源安全约束无变化。 |

## 7. 证据与迁移

沿用 [ImageRenderingTests](../../Tests/InkMarkdownTests/ImageRenderingTests.swift) 的 inflight、queue、cancel、loader identity、paragraph、block 测试。新的 controlled loader 共享测试支撑放在同一 test target 的 Support 目录，不为此建立 target。必要时增加 `InkImagePresentationLoadTests.swift`，只测试 request 事件和可见结果。

采用 tickets 10–17。先共享 load module，后 block、attachment、async 和 preview；最后删除无人引用 bridge/token。不要重写 Store 调度算法，若回归证据指向 Store 本身，记录并单独评估范围。
