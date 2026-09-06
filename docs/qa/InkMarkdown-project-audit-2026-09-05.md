# InkMarkdown 项目审核：事实与修复方案

> 日期：2026-09-05。状态：2026-09-06 已完成 F01–F17 修复及双版本回归，保留未提交工作树；验收范围与限制见文末。
> 范围与已确认约束见 [本轮 spec](../../.scratch/project-audit-2026-09-05/spec.md)。审核对象为 `feat/swiftUI` 的当前工作树，基线 HEAD 为 `46cb52f90ddc0d3648d07a8913f1a9ca24af2b02`，包含任务开始前已有的未提交改动。

## 结论与证据边界

现有职责分层方向可以保留。主要不足集中在：异步请求与呈现生命周期混用、未消费的增量更新没有完整合并、容器宽度没有进入布局失效模型、原始源码与已预处理内容边界不完整，以及图片配置和资源生命周期的所有权不清晰。

以下发现来自源码与调用链核对。首轮只有 F03 的 Mock 取消场景通过独立 Foundation 探针复现；实施阶段已增加对应回归测试。静态判断、实现状态与 Simulator 证据分别记录。

本轮已确认不验收 iOS 15，优先验证 iOS 18 与 iOS 26；本机可用 runtime 为 18.5 和 26.5。Deployment target 仍为 iOS 15。

## 发现

### F01 · P2 · 合帧时丢失最早变更位置

- 位置：`Sources/InkMarkdown/Rendering/InkStreamRenderer.swift:315-326,549-579`。
- 触发：先显示 `Title`，再于下一显示帧前连续追加 `\n---\n` 与 `next`。前一次解析把已显示段落改判为标题，后一次尾部更新覆盖较早的刷新位置，旧段落属性可能保留到 finish。
- 根因：待显示结果只存最新 `refreshLocation`，没有合并自上次显示消费以来的全部变更范围。`sourceFilter` 路径同样存在。
- 修复：在现有加锁的预加载状态中原子保存最新内容、版本及最早变更位置；显示端消费快照时同时划分下一批更新，避免覆盖或丢失并发到达的结果。
- 验证：在 finish 前比较绑定 text storage 与一次性渲染的属性；覆盖普通增量、非幂等 filter、多次合帧及 reset。

### F02 · P1 · 已完成会话更新环境后重新启动流式显示

- 位置：`Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift:183-211`；`Sources/InkMarkdown/Rendering/InkStreamRenderer.swift:332-393,545-633`。
- 触发：消息已经 promotion 后切换深浅色或其他渲染环境。
- 根因：终态仍调用 `renderer.updateConfiguration`，其 reset 将 `isFinished` 设为 false，并为非空内容重启 display link；终态分支没有重新 finish，尾端仍逐帧空转。
- 修复：由会话阶段决定环境更新的接收方。终态仅同步内部配置快照、重建块呈现并通知宿主，不重置流式播放；仍在流式或终结显示的阶段才重解析流式 renderer。保留公开 `updateConfiguration` 的既有语义。
- 验证：终态环境更新后块样式与 renderer 配置正确，流式 renderer 不发生新 reset/display 周期；后续 reset/append 使用新配置，多条历史消息不会新增持续逐帧工作。
- 官方依据：[Apple CADisplayLink](https://developer.apple.com/documentation/QuartzCore/CADisplayLink?changes=_9)。当前未暴露 apple-docs MCP，本轮临时使用 Apple 官方网页核对生命周期。

### F03 · P1 · 取消的 SSE 请求仍能向新会话发送事件

- 位置：`ExampleApp/ExampleApp/Detail/SSE/MockSSEService.swift:22-55`；`ExampleApp/ExampleApp/Detail/SSE/Services/OpenAISSEService.swift:54-151,240-259,326-332`；`ExampleApp/ExampleApp/Presentation/Chat/ChatDemoViewModel.swift:89-141`。
- 触发：Mock 请求 A 在首字延迟的 0.6 秒内被取消，随后启动 B。
- 复现：复制当前 Mock 源码到临时 Foundation 探针，仅将回答路由替换为返回输入字符串。依次启动 A、取消、启动 B，运行主 RunLoop 1.1 秒，输出 `A:A, B:B, A:done, B:done`，`cancelled_request_A_emitted=true`。未修改仓库实现。
- 根因：取消仅覆盖已经存在的 Timer，未取消延迟启动。真实 SSE 的已排队 MainActor 回调也没有请求有效性检查；ViewModel 回调直接使用可变的当前 session。
- 修复：统一传输请求的身份和终止语义，将延迟启动、计时器、底层网络及已排队事件纳入同一有效性边界；消费者将事件绑定到发起请求时的会话，不能重定向到后来创建的会话。
- 验证：首字前取消、连续替换、迟到 chunk/error/complete、正常完成只一次；Mock 与真实解析事件走同一契约。

### F04 · P2 · 表格宽度依赖未随宿主尺寸失效

- 位置：`Sources/InkMarkdown/Rendering/Components/InkTableBlockView.swift:19-27,104-112,147-154`；`InkStreamTableView.swift:55-77,198-223`；`Sources/InkMarkdown/Rendering/InkDisplayMetrics.swift:27-31`。
- 触发：零尺寸构造表格后放入窄容器，或同一实例旋转、进入 Split View。初始化通常使用前台屏幕宽度，无可用 scene 时才回退 320；它不是最终宿主内容宽度。
- 根因：列宽或比例在构造/数据更新阶段固化，未建立宽度变化的失效规则。
- 修复：静态和流式表格共用有效内容宽度与列布局计算；测量、实际显示和宽度变化使用同一输入。仅在有效输入变化时更新约束，不在布局栈中递归触发尺寸失效。
- 验证：同实例 744→375→744，覆盖 wrap/scroll、首次挂载、复用及流式追加，检查列比例和高度。

### F05 · P2 · 表格重复执行顶层 sourceFilter

- 位置：`Sources/InkMarkdown/Rendering/Block/InkBlockRenderer.swift:12-19`；`Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift:90-115`；`InkTableRenderHelper.swift:96-139,229-250`；`Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift:118-128`。
- 触发：非幂等 filter 将 `@@` 替换为 `@`，原始 cell 为 `@@@user`。顶层预处理后应为 `@@user`，cell 测量/显示再次进入 raw inline 接口而重复过滤。
- 修复：把已有 prepared-source 边界延伸到表格 cell；测量和显示共享已生成的富文本。保留 public raw inline 接口的原始输入语义。
- 验证：filter 调用次数和非幂等输出，覆盖静态、复用及流式表格。

### F06–F09 · P2 · 富文本上下文与块序列规则存在重复实现

| 编号 | 问题与触发 | 位置 | 统一修复与回归 |
| --- | --- | --- | --- |
| F06 | Thought body/suffix 逐块直接 append，多个子块可能粘连。例如正文段落后紧跟标题。 | `InkAttributedRenderer.swift:793-819`，对照正常 document 的 `186-196` | 共享带 context 的块序列渲染，验证 body/suffix 的分隔及属性边界。 |
| F07 | 引用或 Thought 中的列表正文继承容器字体和颜色，marker 却取全局正文配置。 | `InkAttributedRenderer.swift:371-418` | marker 的字体、颜色和测宽由同一文本 context 派生，验证自定义容器样式及嵌套缩进。 |
| F08 | `- > 前置引用\n\n  后续段落` 中，首个 Paragraph 被提升到最前，反转原块顺序。 | `InkAttributedRenderer.swift:410-473` | 仅首 child 为 Paragraph 时与 marker 同行，其余子块按源顺序渲染；覆盖引用/代码先于段落的输入。 |
| F09 | 图片来源解析失败或被策略拒绝时，图片占位丢失外层链接；关闭图片或成功加载时却保留。 | `InkAttributedRenderer.swift:689-766` | 共用图片占位属性构造，保留外层 context；验证关闭、来源拒绝、策略拒绝、成功四态，不放宽安全策略。 |

上表路径均位于 `Sources/InkMarkdown/Rendering/AttributedString/`。这些修复保持公开 API，纠正的文本顺序、换行、颜色、点击行为和快照可能变化。

### F10 · P2 · 行内图片绑定缺少完整显示身份

- 位置：`Sources/InkMarkdown/Rendering/Image/InkImageAttachment.swift:98-112,180-193`。
- 根因：`didMaterialize` 将容器宽度、scale、Store 和 loader 的变化简化为一次性布尔状态。换 Store 后也可能保留旧订阅，宽容器会继续使用窄容器的解码位图。
- 修复：比较实际宿主的显示上下文及 Store/loader identity；相同身份复用，不同身份取消旧订阅并重新解析。宿主提供 display context，避免从全局屏幕猜测。
- 验证：相同绑定不重载；宽度 bucket、scale、Store 变化正确重载；迟到结果不可覆盖新绑定。

### F11 · P2 · 图片 Store 配置双重所有权与调度更新不完整

- 位置：`Sources/InkMarkdown/Rendering/Image/InkImageStore.swift:131-154,317-331`。
- 触发一：并发上限从 1 改为 2，已有排队请求仍等待旧任务完成。
- 触发二：`prepareForRendering` 用“是否等于默认值”判断是否显式配置，无法可靠表达恢复默认配置；不同宿主逐块修改共享 Store，使最终预算取决于调用顺序。
- 建议的所有权决策：显式注入的 Store 由其 owner 配置；默认路径根据完整渲染配置选择并持有 Store，不让 block 暗中重配共享预算。显式 `updateConfiguration` 统一协调缓存和调度，提升上限后主动调度，降低上限时不取消已运行任务。
- 已确认：用户批准该所有权决策，已记录 [ADR-011](../decisions/ADR-011-image-store-configuration-ownership.md)。保留源码兼容，混用“注入 Store 配置”与“rendering.storeConfiguration”的宿主需将资源预算配置到注入的 Store。
- 验证：恢复默认值、不同宿主隔离、提高并发立即启动排队项、降低并发仅约束后续任务；明确 pending 缩容时的规则。
- 建议的 pending 缩容规则：保留已经接受的排队请求，按新并发上限继续 FIFO 调度；新请求在队列达到新上限时拒绝，不静默丢弃已接受请求。

### F12–F13 · P2 · 图片预览的配置与取消生命周期不完整

- 位置：`Sources/InkMarkdown/Rendering/Image/InkImagePreviewController.swift:11-19,213-245,279-280`。
- F12：`PreviewLoadPolicy.bypassStore` 没有参与高清加载分支，设为 false 仍直接调用 loader。
- F13：Task 在 await 前把 weak self 升为强引用，控制器等待加载期间无法释放；宿主外部关闭预览未经过私有 dismiss 路径时，deinit 取消不足以打破等待。
- 修复：以一个预览加载生命周期统一直接加载任务或 Store 订阅；保留默认 bypass=true，false 使用 Store。等待阶段不持有控制器，结束展示时统一取消，迟到结果不写回。
- 验证：bypass 两种策略的加载次数/缓存命中，外部 dismiss、悬挂 loader、最后订阅取消和迟到结果。

### F14 · P2 · LaTeX 未遵守请求的输出像素宽度上限

- 位置：`Sources/InkMarkdown/Rendering/Image/DisplayContext.swift:2-35`；`Sources/InkMarkdownLaTeX/InkLaTeXAddonRenderer.swift:19-35,59-103`。
- 根因：公开 `.fit` 契约要求不超过 `maxPixelWidth`，实现只校验输入，实际输出仅受全局 4096px 限制。
- 修复：生成前的渲染计划同时约束输出像素宽度和高度，保持完整公式几何；更新 renderer version，避免复用旧生成语义的缓存。
- 验证：长公式像素宽度不超过请求上限，普通公式样式正确，高度预算继续生效。

### F15 · P2 · 等待接管的 SwiftUI 宿主可以改写活跃宿主环境

- 位置：`Sources/InkMarkdownSwiftUI/Views/InkStreamMarkdownView.swift:75-81`；`Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift:183-211`；continuity 的 attachment handoff 与 coordinator display observer 路径。
- 触发：同一会话由浅色宿主呈现，新的深色宿主登记为等待接管者，旧视图尚未释放。新宿主的 onAppear 已更新共享会话环境，即使它随后放弃接管，原宿主也可能被改为深色。
- 根因：attachment ownership 已区分活跃者和等待者，宿主环境写入却绕过该所有权边界。
- 修复：SwiftUI 宿主在 coordinator 中保存待应用环境，只有已提交的 attachment owner 可以驱动该次呈现的环境更新；接管成功时应用其环境快照。保留 UIKit 宿主直接更新会话环境的公开接口。
- 验证：等待者不影响旧 owner；接管成功后使用新环境；等待者先销毁时旧环境不变。

### F16 · P2 · HTTP 图片请求在取消登记竞态中可能永久等待

- 位置：`Sources/InkMarkdown/Rendering/Image/ImageHTTPSessionDelegate.swift` 的 `boundedData`。
- 根因：先向取消处理器暴露 URLSessionTask，再登记 continuation；取消完成回调可能在登记前找不到 pending，后续登记的等待无法结束。
- 修复：先在锁内登记 pending，再允许取消处理器安装任务；若取消已发生，通过统一的幂等 finish 路径移除 pending 并恢复 continuation。
- 验证：在登记与安装之间暂停请求，确定性取消后恢复，验证返回 cancelled，且不会发出网络请求或遗留 continuation。

### F17 · P2 · 极大或非法流式步长导致溢出或无效推进

- 位置：`InkStreamRenderer.onDisplayFrame()`。
- 复现：真实 F01 回归设置公开 `charactersPerFrame = Int.max`，显示过首段后继续追加，`displayIndex + chunkSize` 发生 `Swift runtime failure: arithmetic overflow`。Simulator 崩溃报告定位于原第 676 行。
- 修复：先将步长限制到 `[1, remainingLength]`，再推进游标；移除重复的可变 chunkSize 状态。非正值按 1 推进，极大值显示剩余内容。
- 验证：Int.max 的真实多批显示回归，以及 0、-1、Int.min 的推进测试。

## 不列为已确认缺陷

- Mermaid 对 `.timedOut`、页面加载失败和进程终止重试一次，符合当前任务摘要中的既定策略。注释对“冷启动”的表述可核对，不据此改变行为。
- SwiftUI container 的布局失效计数可能漏记同步 callback 内的失效，仍需确认可触发路径及真实影响。
- 公开 `@unchecked Sendable` 可变配置的跨线程契约需继续核对；不在未厘清兼容要求时直接给全部 API 添加 actor 隔离。
- iOS 15 runtime 缺少验收按本轮用户指令不计为本轮缺陷。

## 修复顺序与工程门槛

1. 先修复 F01–F03、F15 的异步生命周期、呈现所有权与更新合并，形成能够证明取消、版本和终态边界的关键路径测试。
2. 在同一轮表格重构中处理 F04–F05，统一已预处理的 cell 富文本与宽度计算输入。
3. 处理 F06–F09 的上下文和块顺序，复用现有 `InkTextContext` 和块分隔常量。
4. 确认 F11 的配置所有权后，联动处理 F10–F13，统一图片资源解析、绑定、预览和取消。
5. 修复 F14 的生成预算，并继续核对未覆盖的底层资源链路。
6. 在 iOS 18.5 与 iOS 26.5 上执行适用的 Package 回归、ExampleApp 构建和交互验证。实际结果见下方验证表。

## 实施记录（2026-09-06）

用户已明确批准按本报告实施，并确认 F11 的配置所有权。全部子代理使用独立任务说明，不继承主代理上下文。主代理复核共享边界并统一运行 XcodeBuildMCP。

- F01/F02/F15：锁内原子消费最早 dirty location；终态只同步配置快照；环境更新受 attachment ownership 约束，并覆盖 teardown、cancel/reset 与 handoff 回调。
- F03：新增单请求事件交付边界，统一取消、终止及迟到事件过滤；每个示例 ViewModel 持有独立传输服务，回调绑定发起时的 session；释放服务时清理底层资源。
- F04/F05：共享表格 prepared cell 富文本。wrap 依实际容器重测；scroll 保留内容自然宽度，容器变化更新 viewport。流式 raw cell 只在输入边界预处理，测量与复用不再过滤。
- F06–F09：共享块序列分隔与上下文；保留列表源顺序、容器 marker 样式及图片占位外层链接。
- F10–F13：图片绑定比较 display/Store/loader 身份并拒绝旧 generation 回写；正文、Thought、表格、流式与示例文本宿主通过统一入口提供真实尺寸；Store 配置与生命周期按 ADR-011 归属；预览支持两种缓存策略并处理外部关闭。
- F14：公式使用完整几何的整数像素渲染计划，限制实际输出宽高，结果尺寸与位图一致，renderer version 更新为 `iosMath-2.3.1-r2`。
- F16：HTTP pending 先登记后暴露取消，取消通过同一幂等结束路径恢复 continuation。
- F17：流式游标以剩余长度为界推进，极大或非正字符步长不再溢出或倒退。

## 验证证据

依赖 Git mirror 拉取曾超时。实施阶段按 `Package.resolved` 的精确 revision 从 GitHub codeload 准备了被忽略的本地依赖缓存，再临时使用 path 覆盖进行 Simulator 验证。该方式验证固定源码，不代表远端依赖解析或 CI 已通过。验证结束已逐字节恢复发布 manifest、ExampleApp package references、两个 resolved 文件及缓存 swift-markdown manifest；Git diff 确认这些发布配置没有本轮改动。本轮不提交本地路径依赖。

最终双版本结果如下。全部以 XcodeBuildMCP 的实际 scheme/destination 执行；结构化结果和完整日志、xcresult 路径见 [证据 JSON](project-audit-2026-09-06-evidence.json)。历史 343 项通过数量不作为当前工作树证据。

| Scheme / 配置 | Destination | 结果 | 最终日志文件名 |
| --- | --- | --- | --- |
| InkMarkdown-Package / Debug | iPhone 17 Pro / iOS 26.5 | 361 通过，0 失败，0 跳过 | `test_sim_2026-09-06T10-47-08-800Z_pid3868_95e08598.log` |
| InkMarkdown-Package / Debug | iPhone 16 Pro / iOS 18.5 | 361 通过，0 失败，0 跳过 | `test_sim_2026-09-06T10-47-49-062Z_pid3868_9c34e3c1.log` |
| ExampleApp / Debug hosted tests | iPhone 17 Pro / iOS 26.5 | 8 通过，0 失败，0 跳过 | `test_sim_2026-09-06T11-02-57-546Z_pid3868_55ef235d.log` |
| ExampleApp / Debug hosted tests | iPhone 16 Pro / iOS 18.5 | 8 通过，0 失败，0 跳过 | `test_sim_2026-09-06T10-58-48-164Z_pid3868_3d489bae.log` |
| ExampleApp / Release build | iPhone 17 Pro / iOS 26.5 | 构建通过，无编译诊断 | `build_sim_2026-09-06T11-02-02-032Z_pid3868_42ab9ea2.log` |

日志目录：`~/Library/Developer/XcodeBuildMCP/workspaces/InkMarkdown-124472009cd9/logs/`。Package 全量回归无警告；ExampleApp hosted 构建仍有 Xcode dependency scan 的 `InkMarkdown is missing a dependency on Markdown` 警告，manifest 已显式依赖该 product，本轮未增加重复依赖来掩盖工具链诊断。

运行交互证据：两系统均成功启动 Debug ExampleApp；SwiftUI 组件页先折叠 Thought，再更新自定义 H1，折叠态及后续内容保持。iOS 18.5 完成横屏/竖屏切换，Mermaid 宽图的 Act 与 Export report 右侧内容可见。截图：[iOS 18.5 横屏 Mermaid](assets/project-audit-2026-09-06/ios18-mermaid-landscape.jpg)、[iOS 26.5 Thought 状态保持](assets/project-audit-2026-09-06/ios26-thought-preserved.jpg)。图片预览的两种缓存策略、取消与释放通过自动回归验证；本轮没有重做全部真网来源与预览手势的人工组合矩阵。

### 中间失败与保留风险

- 表格首轮回归误将 scroll cell 的自然宽度当成应随 viewport 缩放的列宽。实现与测试已明确 wrap/scroll 分工，最终全量均通过。
- LaTeX 初轮发现返回逻辑尺寸与实际位图像素取整不一致，已改为整数像素计划并验证非整数上限。
- F01 真实显示回归触发 F17 的算术溢出；崩溃堆栈已定位，游标推进修复后回归通过。TextKit 会补全无属性换行符，测试比较可见文字 run 的完整属性，避免要求系统保留空属性分隔符。
- iOS 18.5 的 Mermaid hosted test 曾连续两次 `.timedOut`，日志包含 WebProcess unresponsive / RBS NearSuspended 失败。仅添加阶段日志后单项通过，移除日志恢复原逻辑后的全量 8 项再次通过，前台组件页也实际出图。当前 renderer 的 WKWebView 仍是 detached view，宿主 App 前台不等同于 WebView 已附着到 window；这属于仍待专项评估的生命周期/模拟器稳定性风险，不能宣称已被本轮修复。没有增加 retry 或放宽 timeout。
- 未运行 iOS 15、真机或远端 CI；未完成完整 VoiceOver、iPad Split View 与真机性能矩阵。按用户指令，iOS 15 不作为本轮阻塞条件。


## 覆盖与后续审核

首轮覆盖 Core 富文本/块/流式/Thought/表格、SwiftUI 会话与呈现桥、图片 Store/绑定/预览、LaTeX/Mermaid 入口、ExampleApp 聊天与传输、Package/消费者 fixture/CI 配置。三个审查子代理均使用独立说明，没有继承主代理上下文；主代理抽样核对关键调用链并独立复现取消缺陷。

实施阶段补充核对 HTTP delegate、ImageIO downsampler 与 Mermaid scheduler/request state/page-load router；HTTP 取消登记缺陷记录为 F16。图片来源与资源策略、Mermaid addon/bridge 的已有契约测试纳入全量回归。完整 Mermaid 资源脚本的逐行安全审计、全部示例页面的人工组合矩阵、完整 VoiceOver 与真机性能基线不属于本次已完成验证证据；本文不证明全仓不存在剩余缺陷。
