# ExampleApp 走查问题 SSOT

本文档记录 ExampleApp 人工走查中发现的 6 类问题：症状、复现路径、归因分桶、本次处理与是否仍为已知限制。走查基于 UIKit / SwiftUI 对称示例（见 [DemoCatalog](../../ExampleApp/ExampleApp/Model/DemoCatalog.swift) 六个 `DemoScenario`）。

**归因分桶说明**

| 分桶 | 含义 |
| --- | --- |
| 库契约 | 库按 ADR / 公开 API 设计的预期行为，宿主需正确配置 |
| 库缺陷 | 库实现与契约不符，已在库或 adapter 侧修复 |
| adapter | `InkMarkdownSwiftUI` 桥接、会话或 SwiftUI 生命周期问题 |
| Example | ExampleApp 演示代码配置不完整或样例选择不当 |
| 系统噪音 | Simulator / iOS 系统、第三方 IME 或 WebKit 进程日志，非库 bug |

---

## P1 / P5 — 点链接出现黄色警告（链接仍可跳转）

### 症状

点击 Markdown 内链接后，Xcode 控制台出现 LaunchServices 相关黄色警告，例如 `canmaplsdatabase`、`sandbox extension`；链接本身通常能正常打开。

### 复现路径

1. 运行 ExampleApp → **SwiftUI 适配器** 或 **UIKit 渲染引擎** → **1. 基础 Markdown 静态渲染**（或 **6. 综合长文与性能基线**）。
2. 点击样例中的 `https://` 链接。
3. 观察 Xcode 控制台。

### 归因分桶

**系统噪音** — LaunchServices 在 Simulator / 沙盒环境下映射 URL scheme 时的常见日志，与 InkMarkdown 渲染无关。

### 本次处理

- **只文档化，不修代码。**
- Example 静态与长文路径已统一经 `DemoLinkOpening.inkHandler` + `DemoInkConfigurationBuilder.makeStaticConfiguration()` 注入 `linkTapHandler`（UIKit / SwiftUI 均适用）。
- SwiftUI adapter 在 handler 为 `nil` 时仍可注入 `UIApplication.shared.open` 作为 Hosting / 预览 seam；Example 演示路径不依赖该 fallback。

### 是否仍为已知限制

**是** — 预期可在 Simulator 控制台看到；不影响链接跳转。排查入口见 [FAQ §控制台噪声](../contributor-guide/06-faq.md#19-控制台噪声simulator--系统)。

---

## P2 — 自定义组件与富媒体

对应示例：**2. 自定义组件与富媒体**（`SwiftUIComponentsDemoView` / `UIKitComponentsDemoViewController`）。

### P2.1 图片不显示，仅见 `[🖼 …]`

#### 症状

开启「图片」开关后仍无真图，文本占位 `[🖼 image]` 或类似 compact 占位。

#### 复现路径

1. 进入 **2. 自定义组件与富媒体**。
2. 打开图片相关开关，滚动至含远程图片的段落。

#### 归因分桶

- **库契约**：`InkImageRendering.isEnabled` 默认 `false`；`ImageSecurityPolicy` **fail-closed**（空 allowlist + `rejectAll`）时即使 `isEnabled=true` 也会拒绝加载（见 [ADR-006](../decisions/ADR-006-opt-in-image-rendering.md)）。
- **Example**：早期演示仅 toggle `isEnabled`，未配置 `allowedHosts`。

#### 本次处理

- Example 增加 `demoImageEnabled` allowlist（`placehold.co`、`picsum.photos`），经 `DemoInkConfigurationBuilder.makeComponentsConfiguration()` 工厂注入。
- **库默认 fail-closed 未改** — 宿主必须同时配置 `isEnabled` 与 allowlist（或等价安全策略）。

#### 是否仍为已知限制

**否（Example 路径）** — 在组件示例中按工厂配置后应可见远程图。未配置 allowlist 的宿主仍会得到 fail-closed 行为，属库契约。

---

### P2.2 多行 `$$` 块级公式未识别

#### 症状

跨段落或多段 `$$ … $$` 未渲染为块级 LaTeX，回退为纯文本。

#### 复现路径

1. 组件示例中启用 LaTeX。
2. 查看含跨段 `$$` 的样例（测试样例含「块级积分公式」场景）。

#### 归因分桶

**库缺陷**（已修） — 块 handler 未跨 Markup 段消费闭合 `$$`。

#### 本次处理

- 库新增 `InkBlockHandler.consume`；`InkLaTeXBlockHandler` 支持跨段识别。
- 契约测试含「块级积分公式」样例。

#### 是否仍为已知限制

**否** — 走 `InkBlockRenderer` 且 opt-in LaTeX 时应正确渲染。纯 `InkAttributedRenderer` 路径仍为文本回退（见 [FAQ §16](../contributor-guide/06-faq.md#16-公式与图表怎么-opt-in)）。

---

### P2.3 占位盖正文 / 布局异常

#### 症状

图片加载失败时大块占位遮挡正文；或行内未加载图片占用过高。

#### 复现路径

1. 组件示例，启用图片但使用被拒绝或无效 URL。
2. 或断网后加载远程图。

#### 归因分桶

**库缺陷**（已修） — 失败 fallback 与 placeholder 可见性、行内高度不合理。

#### 本次处理

- 失败无 fallback → 紧凑 `[🖼 image]` 文本占位。
- 行内未加载高度约一行；placeholder 默认 **hidden**。
- 加载中块级仍可用 160pt 骨架。

#### 是否仍为已知限制

**否** — 上述为当前契约行为；块级加载中骨架 160pt 仍为有意 UX。

---

### P2.4 Mermaid / WKWebView 控制台噪声

#### 症状

启用 Mermaid 或反复切换网络图开关时，控制台出现例如：

- `GPU IdleExit` / `Failed to terminate`
- `web-browser-engine` / entitlement 相关提示
- 短暂骨架屏后再显示图

#### 复现路径

1. **2. 自定义组件与富媒体** → 打开 Mermaid。
2. 或切换网络图开关观察缓存与重建。

#### 归因分桶

- **系统噪音**：`InkMermaidImageRenderer` 使用 WKWebView 离线渲染时的 Simulator / WebKit 进程日志。
- **库契约 / Example**：配置语义变化会重建视图；**generated 缓存命中**时不应再先露出 160pt 骨架。

#### 本次处理

- **只文档化系统噪声；不申请 web-browser-engine 等 entitlement。**
- 开关导致配置变化时会重建 block（预期）；缓存命中路径应避免多余骨架闪烁。

#### 是否仍为已知限制

**是（系统噪声）** — Mermaid 渲染依赖 WebKit，Simulator 下相关日志可忽略。缓存未命中时的短暂骨架属加载态，非 defect。无 App 宿主的 SwiftPM runner 可能挂起离屏 WebProcess，因此唯一真实 PNG 关键测试 `rendersWideJourneyWithoutRightEdgeClipping` 已迁入 ExampleApp app-hosted target；它沿用 production 默认 timeout 与一次有界冷启动重试，并检查 400pt 宽图右缘像素。UIKit/SwiftUI 组件页同时提供“Mermaid 宽图裁切验收”手工入口。超时应按宿主/WebKit 生命周期单独诊断，不能直接归类为 Demo 控制台噪声或 Mermaid 语法缺陷。

---

## P3 — 流式 Markdown（单文档）

对应示例：**4. 流式 Markdown 渲染 (单文档)**（`SwiftUIStreamingMarkdownDemoView` / `UIKitStreamingMarkdownViewController`）。

SwiftUI 与 UIKit **共用** `StreamingDemoViewModel` 与同一 `InkMarkdownRenderSession`；UIKit 侧经 `UIHostingController<InkStreamMarkdownView>` 接入 adapter，**不再**自建 `InkStreamRenderer` 或独立 partition 引擎。

### P3.1 TextKit 1 `layoutManager` 警告

#### 症状

流式输出时控制台出现 TextKit 1 / `layoutManager` 相关警告。

#### 复现路径

1. 进入流式单文档示例，点击模拟分片 / 追加分片。
2. 观察控制台。

#### 归因分桶

**库契约** — v1 刻意使用 TextKit 1 路径（自定义绘制、代码块、引用线等）；非迁移 TextKit 2 的疏漏。

#### 本次处理

**只文档化，不改 TextKit 2。** 见 [FAQ §10](../contributor-guide/06-faq.md#10-会不会改成只支持-textkit-2)。

#### 是否仍为已知限制

**是** — 预期日志；不影响功能。

---

### P3.2 TLS / 网络错误（-1200 / -9816）

#### 症状

流式示例连接预设 LLM 网关失败，NSError `-1200`，`_kCFStreamErrorCodeKey` 为 `-9816`（TLS / 证书相关）。

#### 复现路径

1. 流式示例使用真实网络 preset（非纯 Mock 按钮路径）。
2. 网关证书或 TLS 与设备信任链不匹配时触发。

#### 归因分桶

- **Example**：预设 endpoint / 模型配置；`LLMErrorMapper`（位于 `ExampleApp/Presentation/Shared/`，**非库 API**）识别 `-1200` / `-9816` 等错误码并映射为面向用户的中文说明。
- **库契约**：Demo 与宿主均 **禁止关闭 ATS** — 不得通过 `NSAllowsArbitraryLoads` 等方式绕过证书校验。

#### 本次处理

- Example 预设改为 `https://www.rightapi.ai/codex/v1`，model `gpt-5.6-luna`。
- Example `LLMErrorMapper` 识别 `-1200` 与底层 `-9816`（TLS 握手重置）等 NSURLError。
- **库侧无错误映射 API**；TLS 失败时宿主自行处理网络层，且 **禁止关闭 ATS**。

#### 是否仍为已知限制

**视网络环境而定** — Example `LLMErrorMapper` 已落地；具体 endpoint 可达性取决于用户网络与网关证书，非库渲染问题。

---

### P3.3 流式阶段表格呈「管道文本」

#### 症状

流式过程中表格行显示为 `| col | col |` 纯文本；`finish()` 后才变为可交互真表。

#### 复现路径

1. 流式示例使用含 GFM 表格的 prompt / Mock 样本。
2. 在 `finish()` 前观察表格区域。

#### 归因分桶

**库契约 / 已知限制** — `InkStreamRenderer` **无 GFM 增量表**解析；终态 promotion 后由 `InkBlockRenderer` 升格为真表。

#### 本次处理

- **未做「假完整表」** — 不在流式阶段伪造表格布局。
- Mock  transport 按句 / 行切分，减轻半成品管道文本暴露时间。
- 默认 prompt 改为结构体与类对比样本，避免因「对比 / 表格」关键词落到集合概览类 Mock。

#### 是否仍为已知限制

**是** — v0.0.2 流式路径不支持增量表格；finish 后块级表为预期终态。

---

## P4 — AI SSE 对话

对应示例：**5. AI SSE 对话问答**（`SwiftUIChatDemoView` / `SSEChatViewController`）。

SwiftUI 与 UIKit **共用** `ChatDemoViewModel` 作为 Chat 状态机 SSOT；assistant 气泡在流式与 promotion 后均用 `InkStreamMarkdownView(session:)`（活跃流绑定 `viewModel.session`，历史消息绑定 `msg.renderSession`）。折叠态 SSOT 为 session 内 `streamingThought` / `blocks` 的 `isCollapsed`，**不** re-parse Markdown。UIKit 经 `UIHostingController` 承载上述 SwiftUI 视图。

滚动粘底 / 吐字暂停：`ChatScrollPolicy`（ExampleApp 内编译，120pt 阈值）为 **唯一** `shouldAutoScroll` 谓词；`session.isDisplayPaused` 绑定 `shouldPauseDisplay`。SwiftUI 在 `DragGesture` 期间 pause；手指抬起后靠 preference `offsetChanged` 刷新粘底 latch（iOS 14 ScrollView **无** `isDecelerating`，惯性滑动期间 pause 行为与 UIKit 不完全对称，见下方 P4.4）。

### P4.1 Chat Publishing / 更新风暴（SwiftUI + UIKit）

#### 症状

高频 SSE chunk 导致 SwiftUI 卡顿、重复 layout，或 `Publishing changes from within view updates`；UIKit Chat 若 chunk 路径额外发布视图状态，亦可能出现重复 layout 或过早切静态视图。

#### 复现路径

1. 进入 **SwiftUI 适配器** 或 **UIKit 渲染引擎** 下的 AI Chat，发送会触发 Mock 或真实 SSE 的消息。
2. 观察流式 append 时 UI 流畅度与控制台；finish 后确认块级组件在 `isPromoted` 后再出现。

#### 归因分桶

**adapter / Example** — `@ObservedObject` 订阅整个 session、`@Published` 与 `onChunk` 时机不当，或 finish 后未等 `isPromoted` 即写入终态 content。

#### 本次处理

- **adapter（`InkStreamMarkdownView` + `InkMarkdownRenderSession`）**：
  - **不得** `@ObservedObject` 整个 session；SwiftUI 流式入口**不订阅** session 高频 `@Published`（如 `state`）；`onReceive(session.$isPromoted)` 仅驱动 Representable `updateUIView`（`promotionGeneration`），**不**切换无 session 的 blocks 模式。
  - `state` 仍 `@Published` 供 UIKit Combine；finish 回调写 `state` 不驱动 SwiftUI 换树（`updateUIView` 方向 SwiftUI → UIKit）。
  - 仅 `isPromoted` 的 `@Published` 写入走 `NSObject.perform(_:with:afterDelay:inModes:)`（`afterDelay: 0`、`inModes: [.default]`）；**禁止** `main.async`。
  - `append` / `finish` / `cancel` / `reset` 状态机仍同步；流式阶段 `updateRenderEnvironment` **不** `objectWillChange`。
- **Example（SwiftUI + UIKit 共用 `ChatDemoViewModel`）**：
  - `onChunk` **仅** `session.append(...)`。
  - `streamDisplayPulse` = 链式 `onDisplayUpdate` 的宿主别名：UIKit 用于 cell 高度；SwiftUI **可** `onReceive` **仅** 驱动 `scrollTo`，**不得**修改 `@Published` / 重建流式视图。
  - `handleStreamComplete()` 先 `session.finish()`，等 `isPromoted == true` 后将 session 挂到 `messages[].renderSession` 并设 `isStreaming = false`。
  - 流式与终态 UI：`InkStreamMarkdownView(session:)`（含 PREFIX 思考卡片折叠态）；取消/错误回退 `InkMarkdownView`。
  - 滚动：`ChatScrollPolicy.shouldAutoScroll` 为唯一谓词；ViewModel 不得二次 distance 判定。
- UIKit `SSEChatViewController` 与 SwiftUI `SwiftUIChatDemoView` 均消费同一 ViewModel。

依据见 [09 §12](../contributor-guide/09-swiftui-uiviewrepresentable-gotchas.md#12-publishing-与-session-defer)（Apple `ObservedObject` / `updateUIView`、TCA、MarkdownUI、RunLoop 语义）。

#### 是否仍为已知限制

**否** — adapter + Example（SwiftUI / UIKit 对称）已按上述契约实现；宿主若在 `onChunk` 内额外 `@State` / `@Published` 全量赋值仍可能自致卡顿。

---

### P4.2 Mock 路由与样本

#### 症状

特定问题（如「介绍 Swift 闭包」）未命中期望的长文 Mock，或落到错误样本。

#### 复现路径

1. Chat 输入「介绍 Swift 闭包」或同类关键词。
2. 对比 Mock 输出与预期闭包教学样本。

#### 归因分桶

**Example** — `MockAnswerRouter` 路由规则。

#### 本次处理

- 「介绍 Swift 闭包」走 `MockAnswerRouter` 闭包专用样本。

#### 是否仍为已知限制

**否** — 对该关键词路径已固定；其他未注册关键词仍走默认 Mock 规则。

---

### P4.3 搜狗输入法 / usermanagerd / RBS / 键盘占位日志

#### 症状

Chat 输入框聚焦或切换输入法时，控制台出现第三方 IME、`usermanagerd`、`RBSAssertionErrorDomain` 或 `UIKeyboardImpl` / `placeholder` 相关日志。

#### 复现路径

1. Simulator 或真机使用搜狗等第三方输入法。
2. 在 Chat 输入框编辑；或流式输出期间键盘弹出/收起。

#### 归因分桶

**系统噪音**

#### 本次处理

**只文档化。** 见 [FAQ §19](../contributor-guide/06-faq.md#19-控制台噪声simulator--系统)、[09 §13.1](../contributor-guide/09-swiftui-uiviewrepresentable-gotchas.md#131-问题现象)。

#### 是否仍为已知限制

**是** — 与 InkMarkdown 无关，可忽略。

---

### P4.4 SwiftUI ScrollView 惯性滑动 vs UIKit deceleration

#### 症状

SwiftUI Chat 在手指离开屏幕后惯性滑动（fling）期间，流式吐字 pause 行为与 UIKit `SSEChatViewController`（`willDecelerate` + `scrollViewDidEndDecelerating`）不完全一致。

#### 归因

iOS 14 `ScrollView` **无** `isDecelerating` API；ExampleApp **未** 引入第二套 `UIScrollView` 包装。SwiftUI 路径：`DragGesture` 仅在手指接触时 pause；手指抬起后通过 GeometryReader preference 的 `offsetChanged(distanceFromBottom:isDragging:false)` 刷新 **粘底 latch**（120pt），但不延长 pause。

#### 是否仍为已知限制

**是** — 文档化传感器差异；粘底与 auto-scroll 仍由单一 `ChatScrollPolicy` 驱动。UIKit 路径保留完整 deceleration 语义。

---

## P6 — UIKit 综合长文与性能基线

对应示例：**6. 综合长文与性能基线**（`SwiftUILongTextDemoView` / UIKit 长文入口）。

### P6.1 链接与 dataDetector 冲突

#### 症状

长文页链接行为与静态页不一致，或出现系统 `dataDetector` 与自定义 handler 争抢。

#### 复现路径

1. UIKit **6. 综合长文** → 点击文内链接。
2. 对比是否仍出现 P1 类 LaunchServices 警告（链接应可跳转）。

#### 归因分桶

**Example / 库契约** — 长文 stack 须与静态页一致使用 `InkBlockRenderer` + 配置，而非裸 `UITextView.dataDetectorTypes`。

#### 本次处理

- 已改 `InkBlockRenderer` + `DemoBlockStackView` 路径。
- **无**「渲染模式 `UITextView` + `dataDetectorTypes`」演示。

#### 是否仍为已知限制

**否（Example 长文路径）** — 链接经 `DemoLinkOpening.inkHandler` 与静态配置一致。

---

### P6.2 样例范围与 Mermaid 进程噪声

#### 症状

长文页仍见 `Failed to terminate` 等 WebKit 相关日志，但页面未展示 Mermaid。

#### 复现路径

1. 打开长文示例并滚动。
2. 或此前会话中 Mermaid 示例未完全释放进程。

#### 归因分桶

**Example + 系统噪音** — 长文样例**仍较短、不含 Mermaid**，该页 **不 new WKWebView**；日志多来自其他示例 Mermaid 进程残留或 Simulator 噪音。

#### 本次处理

- 文档化：长文页本身不触发 Mermaid WebView。
- 若仅见长文页仍出现 terminate 日志，先确认是否刚访问过组件示例 Mermaid，或重启 Simulator。

#### 是否仍为已知限制

**是（系统噪音）** — WebKit 子进程在 Simulator 中不一定立即干净退出。

---

## 快速索引

| 编号 | 主题 | 仍为已知限制？ | 主文档 |
| --- | --- | --- | --- |
| P1/P5 | 链接 LaunchServices 警告 | 是（系统） | 本文 §P1/P5、[FAQ §19](../contributor-guide/06-faq.md#19-控制台噪声simulator--系统) |
| P2.1 | 图片 fail-closed | 宿主未配 allowlist 时仍是 | [FAQ §6](../contributor-guide/06-faq.md#6-图片只有--image) |
| P2.2 | 跨段 `$$` | 否（Block 路径） | [FAQ §16](../contributor-guide/06-faq.md#16-公式与图表怎么-opt-in) |
| P2.4 | Mermaid WebKit 噪声 | 是（系统） | 本文 §P2.4、[09 §13](../contributor-guide/09-swiftui-uiviewrepresentable-gotchas.md#13-simulator--系统控制台噪声) |
| P3.1 | TextKit 1 警告 | 是（契约） | [FAQ §10](../contributor-guide/06-faq.md#10-会不会改成只支持-textkit-2) |
| P3.3 | 流式无增量表 | 是 | [10 — Demo 限制](../contributor-guide/10-swiftui-example-app.md#demo-限制与走查结论) |
| P4.1 | Chat Publishing（SwiftUI + UIKit） | 否（onReceive isPromoted + 0-delay perform + pulse + 不 ObservedObject session） | [09 §12](../contributor-guide/09-swiftui-uiviewrepresentable-gotchas.md#12-publishing-与-session-defer) |
| P6 | 长文无 Mermaid 仍见 WebKit 日志 | 是（残留/噪音） | 本文 §P6.2 |

## 维护

- ExampleApp 行为或走查结论变化时，**先更新本文**，再同步 [FAQ §6 / §19](../contributor-guide/06-faq.md)、[09](../contributor-guide/09-swiftui-uiviewrepresentable-gotchas.md)、[10](../contributor-guide/10-swiftui-example-app.md) 交叉引用。
- 提交 Issue 前请对照本文与 FAQ，避免重复上报系统噪音或库契约项。
