# 九、SwiftUI UIViewRepresentable 踩坑指南

> **适用版本：v0.0.2 及后续版本**  
> **相关架构：[SwiftUI Adapter 总体技术设计](08-swiftui-adapter-architecture.md) | [ADR-008](../decisions/ADR-008-swiftui-adapter-architecture.md)**

在 [`InkMarkdownSwiftUI`](../../Sources/InkMarkdownSwiftUI/InkMarkdownSwiftUI.swift) 中，我们通过 [`UIViewRepresentable`](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownRepresentable.swift) 将底层 UIKit 渲染容器 [`InkMarkdownContainerView`](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift) 与富文本/块级组件桥接进 SwiftUI。

由于 SwiftUI（声明式布局与状态 Diff）与 UIKit（命令式布局与 Frame 计算）在生命周期与尺寸协商机制上的差异，跨框架桥接极易引发高度坍塌、布局死循环、流式掉帧、手势冲突和深色模式失效等问题。本文系统总结开发与维护过程中的核心踩坑点与避坑策略。

---

## 1. 动态高度坍塌

### 1.1 问题现象
在静态渲染首次加载、内容变更或流式渲染追加文本时，容器视图在更新 Markdown blocks 后高度保持为 0 或初始高度不变，导致外部容器（如 `VStack`、`List`、`ScrollView`）无法感知内容尺寸变化，出现内容重叠或被截断。

### 1.2 根因分析
SwiftUI 的布局系统依赖 UIKit 视图向外宣告自身的尺寸。在 iOS 14 / 15 中，SwiftUI 主要通过 `intrinsicContentSize` 进行尺寸协商。
当 [`InkMarkdownContainerView`](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift) 内部执行 `updateBlocks` 替换或增删子视图时，若未主动通知 UIKit/SwiftUI 布局系统该视图的固有尺寸已改变，SwiftUI 就不会触发重新测量和父容器重新布局，从而导致高度坍塌。

### 1.3 解决方案
1. **更新后主动失效尺寸**：在 [`InkMarkdownContainerView.updateBlocks(_:configuration:)`](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift) 替换子视图末尾，显式调用 `setNeedsLayout()` 与 `invalidateIntrinsicContentSize()`。
2. **严禁在 `layoutSubviews()` 中循环失效尺寸**：测量与布局共用 ``InkMarkdownContainerView`` 的块高度缓存；宽度变化时在 `measureContent` 入口换 cache 键并重测一次，不在 `layoutSubviews` 调用 `invalidateIntrinsicContentSize()`。
3. **精准尺寸计算**：在 `intrinsicContentSize` 与 `sizeThatFits(_:)` 实现中，遍历当前所有 block views，依据目标宽度通过各子视图的 `sizeThatFits` 累加高度。各 Block 自身按排版规范承担其外边距，容器不再额外盲目累加。

---

## 2. iOS 14 布局死循环

### 2.1 问题现象
在 iOS 14 / 15 环境下，视图渲染时出现 CPU 占用 100%、界面卡死、死循环重绘，或 Xcode 控制台持续打印布局循环警告。

### 2.2 典型反模式（硬性禁令）
**绝对不要在 SwiftUI 视图层使用 `GeometryReader` 读取宽度，然后写回 `@State` / `@Binding` 来驱动底层 UIKit 视图的布局！**

死循环数据流机制如下：
```text
GeometryReader 捕获宽度
      ↓
更新 SwiftUI @State
      ↓
触发 SwiftUI View 重新求值与重绘
      ↓
GeometryReader 尺寸微调 / 重新触发
      ↓
再次更新 @State（无限递归死循环）
```

### 2.3 解决方案
1. **尺寸协商交由系统原生机制**：
   - **iOS 14-15**：依靠 [`InkMarkdownContainerView`](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift) 的 `intrinsicContentSize` 与 `sizeThatFits(_:)` 向 SwiftUI 提供测量依据。
   - **iOS 16+**：在 [`InkMarkdownRepresentable`](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownRepresentable.swift) 中实现 `sizeThatFits(_:uiView:context:)`，直接响应 SwiftUI 的 `ProposedViewSize`。
2. **保持单向数据流**：SwiftUI 仅向底层单向注入 `markdown` 与 `configuration`，尺寸完全由布局引擎在测量阶段确定，视图内部不产生回写状态。

---

## 3. 高频流式 State Diff

### 3.1 问题现象
在 LLM / SSE 流式输出场景中，大模型每秒可能推送几十次文本分片（chunks）。若每次 `append` 都触发 SwiftUI 的 `@Published` 属性发布，会导致 SwiftUI 过于频繁地执行 View diff 与层级重构，引发明显掉帧、发热与 UI 卡顿。

### 3.2 根因分析
SwiftUI 的响应式重绘是基于状态快照比对的。高频的状态变更会打乱 SwiftUI 运行时的帧渲染节奏，尤其当 Markdown 文本较长时，频繁触发上层 View 树的重绘会带来极大的计算浪费。

### 3.3 解决方案
1. **帧率同步节流**：底层 `InkStreamRenderer` 内部已基于 `CADisplayLink` 实现了 60/120 fps 的逐帧吐字节流与解析/显示双缓冲机制，文本累加不会直接阻塞主线程。
2. **避免在 append 时触发全量 Diff**：[`InkMarkdownRenderSession.append(_:)`](../../Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift) 只负责将分片压入底层流式缓冲，不直接通知 SwiftUI 进行全量视图重建。
3. **按帧刷新尺寸**：仅在底层 `renderer.onDisplayUpdate` 回调触发时（由 CADisplayLink 同步触发），由 [`InkMarkdownCoordinator`](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift) 调整当前活跃文本视图的 Frame 并调用 `container.invalidateIntrinsicContentSize()`，确保高帧率流式排版且无多余 SwiftUI Diff 开销。

---

## 4. 选择手势冲突

### 4.1 问题现象
Markdown 文本中的 `UITextView` 无法正常响应长按选词、放大镜和系统编辑菜单（Copy / Share 等），或者在长按文本时误触发了 SwiftUI 祖先容器的点击、长按或滑动手势。

### 4.2 根因分析
`UITextView` 内部自带复杂的手势识别器集合（Pan、LongPress、Tap）。如果 `UITextView` 的可交互属性配置不当，或者在 SwiftUI 层对 Markdown 视图添加了强占式手势修饰符，SwiftUI 手势系统将抢占或阻断 UIKit 的原生事件响应链。

### 4.3 解决方案
1. **正确配置文本视图交互属性**：
   - 保持 `isEditable = false`：禁止调起系统软键盘；
   - 保持 `isSelectable = true`：允许用户选中文本与点击链接；
   - 保持 `isScrollEnabled = false`：避免与外层 `ScrollView` / `List` 发生双重滚动冲突。
2. **禁止在 SwiftUI 视图层外挂手势修饰符**：不要在 SwiftUI 层直接给 [`InkMarkdownView`](../../Sources/InkMarkdownSwiftUI/Views/InkMarkdownView.swift) 或 [`InkStreamMarkdownView`](../../Sources/InkMarkdownSwiftUI/Views/InkStreamMarkdownView.swift) 添加 `.gesture(TapGesture())` 或 `.highPriorityGesture(...)`，以免拦截原生文本选择与链接点击手势。
3. **业务交互通过配置通道注入**：链接点击、自定义 Block 交互等业务逻辑，统一通过 `InkConfiguration.linkTapHandler` 与自定义 Handler 注入处理。

---

## 5. 暗黑模式刷新

### 5.1 问题现象
系统在浅色模式（Light Mode）与深色模式（Dark Mode）之间切换时，已渲染的 Markdown 富文本或代码块颜色未自动同步更新，依然保留切换前的视觉样式。

### 5.2 根因分析
`InkAttributedRenderer` 排版生成的 `NSAttributedString` 中的文本颜色属性（如 `.foregroundColor`）在生成时刻被固化为具体的颜色快照。当宿主系统的外观模式切换时，已生成的富文本字符串属性不会自动反向刷新。

### 5.3 解决方案
1. **捕获外观环境变化**：在 SwiftUI 宿主视图中通过 `@Environment(\.colorScheme)` 监听系统外观模式变更，或在 UIKit 层通过 `UITraitCollection.current.userInterfaceStyle` 捕获模式变化。
2. **驱动属性重绘**：当宿主环境的 `colorScheme` 发生变化时，在 `updateUIView` 中通过最新配置触发重新生成 blocks 或刷新 `InkRenderEnvironment`，确保 `NSAttributedString` 使用对应外观模式下的动态颜色重新渲染。

---

## 6. 配置变化与 updateUIView 幂等性（防无限重绘与 OOM 崩溃）

### 6.1 问题现象

- **现象 A（配置漏更）**：Markdown 文本没有变化，但 `.inkConfiguration(...)`、`sourceFilter`、字体、图片/公式 opt-in 或 Dark Mode 改变后，界面仍显示旧结果。
- **现象 B（死循环与 OOM 崩溃）**：在 SwiftUI 界面中动态切换配置（如切换字号、段落间距开关），页面瞬间卡死，每秒分配数千个 TextKit 对象，内存暴涨数 GB 直至被系统 Jetsam 以 OOM（Code 9）强制终止。

### 6.2 根因分析

SwiftUI 会在布局测量、滚动、环境变量变化以及父视图状态求值时频繁调用 `updateUIView`。
- 如果 Coordinator 仅仅简单使用 `markdown == currentMarkdown` 进行命中判定，会吞掉配置的动态修改。
- 反之，如果因为“配置含闭包”而采取**无条件全量重新生成 blocks**并在每次 `updateStatic` 中调用 `container.updateBlocks` 与 `invalidateIntrinsicContentSize()`，就会导致视图向 SwiftUI 宣告自身尺寸改变；SwiftUI 随即安排下一次 layout pass 并再次调用 `updateUIView`，陷入**主线程无限递归更新死循环**，产生毁灭性的内存泄漏与 CPU 占满。

### 6.3 解决方案

1. **配置语义比较能力**：
   - 为 `InkAppearance` 及其所有子样式结构体（`Text`、`Heading`、`Table`、`CodeBlock` 等）实现 `Equatable`。
   - 在 `InkConfiguration` 上实现 `isSemanticallyEqualTo(_ other: InkConfiguration) -> Bool`，准确对比样式（`appearance`）、环境（`renderEnvironment`）与扩展点顺序。
   - 有内部状态的 `InkInlineSyntax` / `InkBlockHandler` 通过 `InkConfigurationSemanticsProviding` 明确声明完整语义；未知扩展保守视为不等价，不能只比较动态类型、数量或闭包存在性。
2. **Coordinator 幂等脏检查**：
   - `InkMarkdownCoordinator` 记录 `lastRenderedMarkdown` 与 `lastRenderedConfiguration`。
   - 当 Markdown 文本未变且配置在语义上等价（`isSemanticallyEqualTo == true`）且容器已有渲染内容时，`updateStatic` **直接 return 成为 no-op**，杜绝无意义的重复解析与对象重建。
3. **流式路径**：由 `InkMarkdownRenderSession.configuration` 持有从 append 到 promotion 的唯一配置快照；不要向 streaming Coordinator 传入第二份独立配置。
4. **trait 变化**：将最新 `InkRenderEnvironment` 写入 session，并以同一份 `currentText` 重置/重新解析 renderer；finish 阶段继续完成最终解析和 promotion。

---

## 7. `finish()` 不等于“已经完成”

### 7.1 问题现象

调用 `finish()` 后立即读取终态 blocks，得到空数组或旧内容；在没有挂载 `UITextView` 的 headless 测试、后台预热或快速卸载场景中，会话一直停留在 finishing，永不 promotion。

### 7.2 根因分析

流式结束至少包含四个不同事件：

```text
输入结束
  → 最终全量解析完成
  → 显示追赶最终 attributed string
  → Block Promotion 完成且终态可交互
```

`CADisplayLink` 只在有活跃 UIKit text view attachment 时驱动。如果实现把 `onFinishDisplay` 唯一地绑在 display link 上，未挂载视图时就没有任何东西推动会话离开 finishing。

### 7.3 解决方案

1. 用显式状态区分 `finishing`、`displayingFinalContent` 和 `finished`，不要用一个 `isFinished` 布尔值覆盖解析、显示和 promotion。
2. 最终后台解析完成后，先通知 parse completion；若当前没有 text view，则直接把已解析内容视为已显示并触发 display completion。
3. 测试必须覆盖真实异步路径：不能只在测试中手动调用 `renderer.onFinishDisplay?()` 来掩盖 headless 路径没有完成驱动的问题。
4. 取消、reset 和 teardown 时清理 display link 与 callbacks，避免旧解析任务或旧 attachment 在新会话中回写。

---

## 8. 流式输入长度必须只有一个 canonical source

### 8.1 问题现象

流式过程中用户看到的内容与 finish 后的终态 blocks 不一致：尾部内容在流式阶段没有显示，但 promotion 后又突然出现；或超长输入的流式结果与静态终态截断位置不同。

### 8.2 根因分析

常见错误是：会话完整保存 `currentText`，renderer 在解析或 finish 时才单独截断。这样 renderer 实际处理的是一个 source，promotion 又对另一个更长 source 调用 `InkBlockRenderer`。

### 8.3 解决方案

1. 在 `append` 入口统一执行最大长度策略；被接受的文本才同时写入 session 的 `currentText` 和 `InkStreamRenderer`。
2. `finish()`、最终 attributed-string 解析和 Block Promotion 都只能使用同一个已接受 source；禁止各阶段各自 `prefix` / 截断。
3. 默认值只有一个来源：`InkStreamRenderer.maximumSourceLength`；自定义值通过 renderer/session initializer 注入。
4. 配置在会话创建时固化为不可变 source-limit snapshot，session 与 renderer 共享该 snapshot；禁止运行中修改上限或只改 renderer 的局部值。

---

## 9. Block Promotion 必须消费已完成产物

### 9.1 问题现象

流式结束后虽然已经生成了终态 blocks，但 adapter 又从 `currentText` 重新调用一次 `InkBlockRenderer`。表面结果通常相同，却增加了解析和 block 创建成本，并给配置、source 或 trait 漂移留下机会。

### 9.2 解决方案

1. `InkMarkdownRenderSession` 负责生成并持有 promotion 产物；视图切换到终态时直接把 `session.blocks` 交给 `InkMarkdownContainerView`。
2. promotion 切换前解除 `onDisplayUpdate`、解绑旧 `UITextView` 并移除旧子视图，避免流式 text view 与终态 blocks 同时存在。
3. `dismantleUIView`、重复 mount、会话替换和 reset 都要验证 callback、display link、text view attachment 已清理。
4. 终态渲染不要通过“看起来一样”的二次 render 绕过 session 的生命周期契约。

---

## 10. Block View 尺寸协商与 Auto Layout 零高度冲突

### 10.1 问题现象

控制台打印大量 `Unable to simultaneously satisfy constraints` 约束冲突报错，如：
```text
<NSAutoresizingMaskLayoutConstraint: ... InkCodeBlockViewImpl:...height == 0 (active)>
<NSLayoutConstraint: ... UILabel:...bottom == UIView:...bottom - 8 (active)>
```
或表格、代码块在首次测量时高度被折叠为 0。

### 10.2 根因分析

1. **默认 `sizeThatFits` 返回 `(0, 0)`**：`UIView` 的默认 `sizeThatFits` 实现仅返回当前 `frame.size`（初始为 `.zero`）。如果自定义 Block View（如 `InkCodeBlockViewImpl`、`InkTableBlockView`）内部使用 Auto Layout 却没有重写 `sizeThatFits(_:)`，外层 Frame 容器在预测量时就会得到高 0。
2. **`translatesAutoresizingMaskIntoConstraints` 冲突**：当容器将其 frame 高度设为 0 时，系统生成的 autoresizing mask 约束 `height == 0` 会与子视图内部的最小内容约束产生无法满足的死锁冲突。

### 10.3 解决方案

1. **全员重写 `sizeThatFits` 与 `intrinsicContentSize`**：
   - **`InkCodeBlockViewImpl`**：根据代码文本行数、字号、行高与上下边距精确计算高度并以 Frame 排版。
   - **`InkTableBlockView`**：通过内部 `StackView.systemLayoutSizeFitting(...)` 加上边框与 `verticalInset` 返回精确高度。
   - **`InkThematicBreakView`**：返回固定线宽加下方留白（`lineThickness + spacingAfter`）。
   - **`InkImageBlock`**：根据图片原图宽高比与容器可用宽度计算适应高度。
   - **`InkAttributedBlockTextView`**：通过 `layoutManager.usedRect(for: textContainer)` 与 `textContainerInset` 计算高度。
2. **软化内部垂直约束优先级**：在涉及外部 frame 调整的视图内部（如表格外层容器与 ScrollView），将坚硬的底部 pinning 约束优先级设为 999（`defaultHigh`），杜绝与瞬时零尺寸 autoresizing mask 冲突。

---

## 11. 避坑自查清单

在提交与维护 `InkMarkdownSwiftUI` 相关代码时，请按此清单逐一核对：

- [ ] `InkMarkdownCoordinator` 是否实现了幂等脏检查（`isSemanticallyEqualTo`），避免在 `updateUIView` 中无条件全量重配？
- [ ] `InkMarkdownContainerView.layoutSubviews()` 中是否**绝对没有**调用 `invalidateIntrinsicContentSize()`？
- [ ] 所有自定义 `InkRenderableBlock` 视图是否均重写了 `sizeThatFits(_:)` 与 `intrinsicContentSize`？
- [ ] 是否存在使用 `GeometryReader` 读取宽度并回写 `@State` 的反模式？
- [ ] 流式渲染是否依赖 `CADisplayLink` 节流，避免了在 `append` 时触发高频 SwiftUI Diff？
- [ ] `UITextView` 是否设置了 `isEditable = false`、`isSelectable = true` 与 `isScrollEnabled = false`？
- [ ] 是否避免了在 SwiftUI 视图层直接挂载强占式手势？
- [ ] 公开 `InkRenderableBlock` 是否只依赖公开契约，没有要求消费者实现 internal / SPI witness？
- [ ] 视图复用是否比较全部可见语义，而不是截断文本、hash 或省略状态的 fingerprint？
- [ ] session 切换到空输入时，是否仍把空快照写入复用的 `UITextView`？
- [ ] 流式 dirty state 是否包含完成态、折叠态等 presentation state，而不只比较正文？
- [ ] Dynamic Type 的绘制、测量、baseline 与增量扩宽是否使用同一 trait 和缩放字体？
- [ ] TextKit 同步测量回调是否保持纯函数，不进行 actor hop、异步回写或订阅启动？
- [ ] 静态更新是否把 configuration / trait 变化纳入 render input，而不是只比较 Markdown？
- [ ] 流式阶段、最终解析和 promotion 是否共享同一 canonical source 与 configuration snapshot？
- [ ] `finish()` 在未挂载 text view 时是否仍能完成 headless promotion？
- [ ] promotion 是否直接消费 session 生成的 blocks，并清理旧 text view / callbacks？
- [ ] 切换 Dark / Light 模式时，富文本与块级组件颜色能否正确同步刷新？
- [ ] 异步缓存测试是否等待 Store 的完成契约，而不是观察 loader 内部计数猜测缓存已写入？
- [ ] 测试报告是否区分总数、通过数与跳过数，避免把 skipped 同时计入 passed？
- [ ] 是否在 iOS 14、iOS 16+ 及 iPadOS 上均完成了布局与尺寸验证？

---

## 12. Publishing 与 session defer

### 12.1 问题现象

AI SSE / Chat 场景中（SwiftUI `SwiftUIChatDemoView` 与 UIKit `SSEChatViewController` 共用 `ChatDemoViewModel`），若在 SwiftUI 视图更新周期内同步修改多个 `@Published` 属性、把整个 session 挂到 `@ObservedObject`，或 `onChunk` 除 `session.append` 外还写入 `messages.content` / 提前切静态视图，可能出现：

- 控制台 `Publishing changes from within view updates`
- 流式 append 时 UI 卡顿、重复 layout

### 12.2 根因与依据

| # | 依据 | 契约 |
| --- | --- | --- |
| 1 | Apple [`ObservedObject`](https://developer.apple.com/documentation/swiftui/observedobject) | 对象任一 `@Published` 变化都会 invalidate 依赖该对象的 View。`InkStreamMarkdownView` **不得** `@ObservedObject` 整个 session；SwiftUI 流式入口**不订阅** session 高频 `@Published`（如 `state`）。 |
| 2 | Apple [`updateUIView(_:context:)`](https://developer.apple.com/documentation/swiftui/uiviewrepresentable/updateuiview(_:context:)) | 方向 SwiftUI → UIKit。finish 回调里写 `state` 不应驱动 SwiftUI 换树。 |
| 3 | [TCA — Avoiding objectWillChange](https://github.com/pointfreeco/swift-composable-architecture/discussions/1069) | 避免在 view update 周期内通过 `objectWillChange` 同步失效视图。 |
| 4 | [MarkdownUI](https://github.com/gonzalezreal/MarkdownUI) | 原生 SwiftUI 渲染，不把 UIKit 中间态挂到 `ObservedObject`；adapter 同理，中间态留给 UIKit / Combine。 |
| 5 | adapter 分层 | `state` 仍 `@Published` 供 UIKit Combine 订阅；SwiftUI 流式入口**不订**。 |
| 6 | RunLoop 语义 | **唯一**驱动 SwiftUI 换树的 `isPromoted`，须用 `NSObject.perform(_:with:afterDelay:inModes:)`（`afterDelay: 0`、`inModes: [.default]`）离开当前 view update。**禁止** `DispatchQueue.main.async`；**禁止** `RunLoop.perform(inModes:)`。 |

Chat 层若在 chunk 路径重复发布视图级状态，或在 `finish()` 后未等 `isPromoted` 即写入终态 content，则与 adapter 帧率同步机制冲突。

### 12.3 解决方案

1. **`InkMarkdownRenderSession`**：
   - `append` / `finish` / `cancel` / `reset` 状态机逻辑仍**同步**执行。
   - `state` 等高频字段仍 `@Published`，仅 UIKit / Combine 订阅；SwiftUI 流式入口**不订**。
   - 仅 `isPromoted` 的 `@Published` 写入走 `NSObject.perform(_:with:afterDelay:inModes:)`（`afterDelay: 0`、`inModes: [.default]`）；**不用** `main.async`。
   - `updateRenderEnvironment` 在流式阶段**不**触发 `objectWillChange`。
2. **`InkStreamMarkdownView`**：
   - **不得** `@ObservedObject var session`。
   - body **始终** `InkMarkdownRepresentable(mode: .streaming(session:))`；promotion 后由 Coordinator 在同一会话上切换块级布局（含 `setPromotedThoughtCollapsed` 写回），**不得** body 切无 session 的 `.blocks` 模式。
3. **Chat / 宿主 transport（ExampleApp `ChatDemoViewModel` 契约，SwiftUI / UIKit 对称）**：
   - `onChunk` **仅**调用 `session.append(...)`。
   - `streamDisplayPulse` 为链式 `onDisplayUpdate` 的宿主别名：UIKit 用于 cell 高度重算；SwiftUI **可** `onReceive` 该 pulse **仅** 驱动 `scrollTo`，**不得**用它修改 `@Published` 或重建 `InkStreamMarkdownView`。
   - `handleStreamComplete()` 先 `session.finish()`，再等待 `session.isPromoted == true`，然后将 session 转移到 `messages[].renderSession` 并设 `isStreaming = false`；终态 UI 仍用 `InkStreamMarkdownView(session: msg.renderSession)`。
4. 流式尺寸刷新仍依赖 [§3 高频流式 State Diff](#3-高频流式-state-diff) 中的 `onDisplayUpdate` + `invalidateIntrinsicContentSize`，而非每个 chunk 触发 SwiftUI 全量重建。

ExampleApp 走查结论见 [P4.1 — Chat Publishing（SwiftUI + UIKit）](../qa/example-app-walkthrough-issues.md#p41-chat-publishing--更新风暴swiftui--uikit)。

---

## 13. Simulator / 系统控制台噪声

### 13.1 问题现象

在 ExampleApp 或 SwiftUI Preview 中操作链接、Mermaid、流式文本或 Chat 输入时，Xcode 控制台出现黄色警告，**功能往往仍正常**。常见关键字：

| 场景 | 典型日志 | 说明 |
| --- | --- | --- |
| 点击 Markdown 链接 | `canmaplsdatabase`、`sandbox extension` | LaunchServices / 沙盒映射 |
| Mermaid / 网络图 | `GPU IdleExit`、`Failed to terminate`、`web-browser-engine` | WKWebView 子进程与 entitlement 提示 |
| 流式 TextKit 1 | `layoutManager` 相关 | v1 刻意 TextKit 1，见 [FAQ §10](06-faq.md#10-会不会改成只支持-textkit-2) |
| Chat 输入框 | 搜狗输入法、`usermanagerd` | 第三方 IME / 系统服务 |
| Simulator 进程权限 | `RBSAssertionErrorDomain`、`task name port right` | RunningBoard 系统噪音，与 InkMarkdown 无关 |
| 键盘占位 | `UIKeyboardImpl`、`placeholder`、InputSystem | 输入框聚焦/切换键盘时的 Simulator 占位日志 |

### 13.2 处理原则

1. **只文档化，不当库 defect 修** — 尤其 LaunchServices、WebKit 进程终止、第三方 IME。
2. **不申请** `web-browser-engine` 等额外 entitlement 来消除 Mermaid 相关日志；Mermaid 离线渲染依赖 WebKit 是已知架构选择（见 [ADR-007](../decisions/ADR-007-local-generated-diagrams-and-formulas.md)）。
3. 长文示例页不含 Mermaid 时仍见 `Failed to terminate`，多为**其他示例** Mermaid 进程残留或 Simulator 噪音，见 [走查 P6.2](../qa/example-app-walkthrough-issues.md#p62-样例范围与-mermaid-进程噪声)。

汇总表见 [FAQ §19](06-faq.md#19-控制台噪声simulator--系统)。

---

## 14. 公开 Block 扩展点不得要求 SPI witness

### 14.1 问题现象

普通消费者只写 `import InkMarkdown` 并实现公开 `InkRenderableBlock` 时，编译器提示不符合协议；ExampleApp 为了满足协议而给 internal 属性添加 `@_spi`，又触发 `internal property cannot be declared '@_spi'`。

### 14.2 根因与规则

公开协议一旦把 SPI identity、fingerprint 或可写 stamping 状态设为 requirement，普通消费者就无法看见或实现完整 interface。identity 属于 adapter diff 实现，不属于自定义 block 的公开职责。

当前 interface 分为两层：

1. `InkRenderableBlock` 只要求 `makeView()`，普通消费者无需 SPI。
2. `InkReusableBlock` 是可选能力；只有能完整比较内容并安全更新已有视图的 block 才实现。
3. adapter 统一根据文档 epoch、block index 与动态类型派生 identity，禁止把可写 diff 元数据塞回业务 block。
4. 未实现复用能力的自定义 block 在文档变化时保守重建，正确性优先于对象复用。

---

## 15. Block 复用不得使用有损 fingerprint

### 15.1 问题现象

链接 URL 改变、粗体改斜体、附件改变，或第 65 个字符之后发生等长修改时，adapter 误判内容未变，继续展示旧链接、旧样式或旧文本。

### 15.2 根因与规则

“长度 + 前缀”不是内容语义。即使改成全量 hash，也仍有碰撞、未知属性和附件语义缺失问题。当前容器保存上一次 block，由 `InkReusableBlock.hasEquivalentContent(to:)` 做类型专属的完整语义比较：

- 富文本使用 `NSAttributedString.isEqual(to:)`，覆盖全文、属性 runs、链接和附件；
- 表格比较 headers、逐行 rows、alignments、layout mode 与完整渲染配置；
- thought 比较正文、完成态、折叠态、样式与内部渲染配置；
- 代码块与分隔线也必须比较影响可见输出的样式；
- 图片比较 source 与完整 rendering（loader、Store、安全策略、回调与尺寸）；source 或 rendering 变化时因不可安全原地配置而重建 view。

新增 block 时，若无法证明比较完整或更新安全，应不实现 `InkReusableBlock`，禁止返回“猜测相等”或在错误 view 类型上静默成功。

---

## 16. Session ownership 转移必须覆盖空快照

复用 `UITextView` 时，`displayIndex == 0` 不是“无需同步”，而是“新 owner 的正确快照为空”。`bindTextView` 必须始终以当前 renderer 的 `0..<displayIndex` 快照覆盖 `textStorage`；否则 A 会话正文会残留到空 B 会话，B 的后续字符还会追加在 A 后面。

测试至少覆盖 A→空 B 与 A→有内容 B。对象复用不能隐含内容所有权复用。

---

## 17. Dirty tracking 必须比较 presentation state

thought 的正文未变不代表展示未变。单独到达 `</think>` 时，`isComplete` 会从 `false` 变为 `true`，标题、指示器和 VoiceOver 标签都需要刷新。dirty 判定必须覆盖完整 presentation state，至少包括正文、完成态和折叠态；多个槽同批变化时使用可组合集合，禁止用互斥枚举丢掉其中一个刷新。

---

## 18. 渲染与测量必须共享同一 Dynamic Type 值

字体渲染、列宽测量、固定行高和 baseline 必须从同一个 `InkRenderEnvironment.traitCollection` 派生。不能让 cell 使用缩放字体，却让列宽继续用原始 `UIFont.systemFont`，也不能用未缩放 `lineHeight` 计算已缩放字体的 baseline。

表格当前通过 `InkTableRenderHelper.font(...)` 统一字体来源；增量表格的“新行是否扩列”也使用同一 attributed 渲染路径测量。新增测量路径时应复用该 helper，而不是重新创建字体。

---

## 19. TextKit nonisolated 测量回调必须保持纯函数

`NSTextAttachment.attachmentBounds(...)` 是 nonisolated override。不能在该回调中把 attachment `self` 发送到 MainActor、启动加载或改写 TextKit 状态；这既会产生 Swift 6 数据竞争诊断，也可能在布局栈内触发重入。

当前约束：

1. `attachmentBounds` 只读取不可变 rendering 与已发布图片快照，计算 bounds。
2. Store 绑定、订阅、图片应用和布局失效均在显示层 MainActor 路径执行。
3. 宽度建立后，由 text view 测量/绑定路径再次调用 `bindAttachments`，不依赖 layout callback 产生副作用。
4. 注册表等跨任务共享状态必须收敛进单一加锁状态容器；静态属性只保留不可变容器引用。

---

## 20. 异步测试必须等待所属模块的完成契约

图片 loader 返回只代表解码结束，不代表 `InkImageStore` 已在 MainActor 写入缓存、广播订阅并清理 inflight。测试若轮询 loader 的完成计数后立即断言 Store 状态，会留下取决于 actor 调度的竞态，单测可能通过、全量并发回归却偶发失败。

缓存命中测试应等待 `InkImageStore.resolve(..., onLoad:)` 的完成回调，或重复查询直至返回 `.ready`；不能读取依赖组件的内部计数推断上层状态。通用规则是：断言哪个模块的状态，就等待哪个模块公开的完成边界。

---

## 21. 测试总数不能直接写成通过数

Swift Testing、XCTest、`xcodebuild` 与 XcodeBuildMCP 对 skipped 的摘要格式不同。分组日志中的 “tests in suites” 可能包含 skipped；把各组数量直接相加并写成“全部通过”，会得到“300 项通过、另 1 项跳过”这种总数多算一次的矛盾结论。

状态文档必须分别记录：总计、通过、失败、跳过，并优先采用结构化 result bundle 或 XcodeBuildMCP 汇总。本轮最终结果为共 340 项：339 项通过、0 失败、1 项跳过。

---

## 22. 闭包与 loader 不能只比较 nil 性

Swift 闭包、类型擦除 loader 和交互回调没有通用值相等性。只比较“两边都非 nil”会把新的 `sourceFilter`、链接处理、图片 loader 或复制反馈误判为旧行为，Coordinator 便会留住过期配置。反过来，把所有含闭包配置都永久视为不等，又会破坏 SwiftUI 幂等性。

当前规则：

1. 配置值拷贝保留不透明成员的语义身份。
2. 直接重新赋值保守地生成新身份，保证不会误跳过更新。
3. SwiftUI `body` 反复构造行为完全等价的闭包或 loader 时，使用 `setSourceFilter`、`setLinkTapHandler`、`setLoader` 等带 `InkSemanticIdentity` 的 API。
4. 只有逻辑与所有捕获状态都等价时才能复用同一身份；状态改变必须更换身份。
5. 内置 LaTeX / Mermaid loader 通过自身的 mode、style 与 limits 做值语义比较，不依赖实例地址。

这是渲染正确性契约，不是单纯性能 hint。新增不透明配置字段时，必须同时定义其语义身份与回归测试。

---

## 23. 尚未复现但必须预防的坑

本节是风险登记，不表示仓库已出现对应缺陷。只有取得运行证据后，才能把条目改为“已踩坑”或“已验证无影响”。

| 风险 | 触发条件 | 预防与验收 |
| --- | --- | --- |
| 最低系统行为分叉 | iOS / iPadOS 14–15 不提供新版本 `UIViewRepresentable` 尺寸入口 | 保留 intrinsic-size 兼容路径；在真实 14、15 runtime 分别验证首次宽度为 0、宽度建立、旋转和重复挂载 |
| `sizeThatFits` 重复调用 | SwiftUI 在一次 layout pass 内多次提议相同或不同宽度 | 测量保持无副作用并命中 width-keyed cache；用计数探针验证不会重建 blocks 或发布状态 |
| iPad Split View 连续宽度变化 | 分屏拖动、Stage Manager、窗口多次 resize | 只使旧宽度测量槽失效；验证窄宽表格、代码、图片与长链接不截断、不产生布局循环 |
| 超大 Dynamic Type 与 Bold Text | 辅助功能字号、粗体文本、运行时类别切换 | 字体、行高、baseline、列宽和 ReservedHeight 使用同一 trait；用 AX5 及以上字号走查文本裁切与控件命中区域 |
| RTL / 混合书写方向 | 阿拉伯语、希伯来语、数字列表与英文混排 | 不硬编码 left/right 对齐语义；验证列表 marker、引用竖线、链接和表格 reading order |
| VoiceOver 焦点在 promotion 时丢失 | 用户正在读流式 Thought 或链接，随后切终态 blocks | 复用稳定 view identity；验证焦点不跳到页面顶部，完成态提示只播报一次 |
| App 后台 / 前台切换 | 流式过程中挂起、display link 暂停、WKWebView 页面进程回收 | 恢复后从 canonical source 继续；不重复 chunk、不重复 promotion；LaTeX / Mermaid 只按既定策略重试 |
| 内存警告与缓存回收 | 长会话、大图、多个公式/图表同时存在 | Store 与 WebKit 缓存可清理且不破坏当前可见内容；用 Allocations / Leaks 记录峰值与回落 |
| 多窗口 trait 漂移 | iPad 多 scene 使用不同宽度、色彩模式或 Dynamic Type | render environment 属于各自 session / host 快照；禁止读取全局 trait 代替宿主环境 |
| 快速 attach / detach | `List` cell 复用、导航返回、条件视图频繁切换 | dismantle 清理 callback、display link、订阅与旧 text view owner；验证无旧会话回写和 retain cycle |

走查记录必须区分三类状态：`已复现`、`已验证未复现`、`环境不可用`。不能用“代码看起来兼容”替代最低版本、真机或辅助功能运行证据。

---
