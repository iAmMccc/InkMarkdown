# 十、SwiftUI ExampleApp 使用示例

本文说明如何在 `ExampleApp` 中验证 `InkMarkdownSwiftUI` adapter 的公开入口。示例程序仍由 UIKit AppDelegate / SceneDelegate 启动，然后从 UIKit 导航栈推入 `UIHostingController`；这对应 UIKit 宿主逐步接入 SwiftUI 的常见路径。

UIKit 与 SwiftUI 在 **六个对称场景** 下 1:1 对齐（见 `DemoCatalog` / `DemoScenario`）。走查中发现的问题、限制与系统噪声以 [ExampleApp 走查 SSOT](../qa/example-app-walkthrough-issues.md) 为准。

## 运行入口

1. 打开 `ExampleApp/ExampleApp.xcodeproj`。
2. 运行 `ExampleApp` scheme。
3. 首页选择 **SwiftUI 适配器** 或 **UIKit 渲染引擎**。
4. 进入以下六个对称示例：

| # | 场景 | SwiftUI 入口 | UIKit 入口 | 覆盖能力 |
| --- | --- | --- | --- | --- |
| 1 | 基础 Markdown 静态渲染 | `SwiftUIStaticMarkdownDemoView` | `UIKitStandardMarkdownDemoViewController` | 标题、列表、引用、代码块、表格、链接 |
| 2 | 自定义组件与富媒体 | `SwiftUIComponentsDemoView` | `UIKitComponentsDemoViewController` | 表格、图片 allowlist、LaTeX、Mermaid |
| 3 | 样式配置与动态主题 | `SwiftUIConfigurationDemoView` | `UIKitConfigurationDemoViewController` | 显式配置、`.inkConfiguration(...)`、Dark Mode |
| 4 | 流式 Markdown（单文档） | `SwiftUIStreamingMarkdownDemoView` | `UIKitStreamingMarkdownViewController` | 共用 `StreamingDemoViewModel` + `InkMarkdownRenderSession`；UIKit 经 `UIHostingController<InkStreamMarkdownView>` |
| 5 | AI SSE 对话问答 | `SwiftUIChatDemoView` | `SSEChatViewController` | 共用 `ChatDemoViewModel`；流式 `InkStreamMarkdownView`，promotion 后 `InkMarkdownView` |
| 6 | 综合长文与性能基线 | `SwiftUILongTextDemoView` | UIKit 长文入口 | `InkBlockRenderer` + `DemoBlockStackView`，无 Mermaid |

## 设计要点

### 静态内容：宿主拥有滚动

`InkMarkdownView` 是内容 adapter，不内嵌 `ScrollView`。ExampleApp 由 SwiftUI 宿主组合：

```swift
ScrollView {
    InkMarkdownView(markdown)
}
```

这样宿主可以决定列表、聊天气泡、分页和自动滚动策略，避免出现双滚动状态。

静态与长文示例经 `DemoInkConfigurationBuilder.makeStaticConfiguration()` 注入 `DemoLinkOpening.inkHandler`，链接点击行为一致。

### 配置：一份 `InkConfiguration`

配置示例同时展示两种入口：

```swift
InkMarkdownView(markdown, configuration: configuration)

InkMarkdownView(markdown)
    .inkConfiguration(configuration)
```

`.inkConfiguration(...)` 只是 Environment 注入 seam，不会创建第二套 SwiftUI Theme。静态视图仍通过同一个 UIKit rendering engine 渲染。

### 组件与富媒体：工厂 + allowlist

**2. 自定义组件与富媒体** 使用 `DemoInkConfigurationBuilder.makeComponentsConfiguration()`：

- 图片：`demoImageEnabled` 开关 + `allowedHosts`（`placehold.co`、`picsum.photos`）。**仅 `isEnabled=true` 不够**，见 [FAQ §6](06-faq.md#6-图片只有--image)。
- LaTeX / Mermaid：opt-in 开关；Mermaid 可能产生 WebKit 控制台噪声（只文档化）。

### 流式内容：宿主拥有 transport

**场景 4（单文档流式）** 与 **场景 5（AI Chat）** 在 SwiftUI / UIKit 下均共用 ViewModel + adapter，**不是**「UIKit 另有一套 `InkStreamRenderer`」：

| 场景 | 共用 ViewModel | SwiftUI 视图 | UIKit 接入 |
| --- | --- | --- | --- |
| 4 流式单文档 | `StreamingDemoViewModel` | `InkStreamMarkdownView(session:)` | `UIHostingController<InkStreamMarkdownView>` |
| 5 AI Chat | `ChatDemoViewModel` | 流式 `InkStreamMarkdownView`；终态 `InkMarkdownView(..., configuration:)` | 同上，assistant cell 内 Hosting |

示例中的「追加分片」按钮代表 SSE / WebSocket 回调；实际应用应在收到网络 delta 时调用：

```swift
session.append(delta)
```

输入完成后调用 `session.finish()`。如果需要中止或重新使用同一会话，分别调用 `cancel()` 或 `reset()`。网络连接、重试、滚动和聊天业务状态不属于 adapter。

**Chat 契约（`ChatDemoViewModel`，SwiftUI / UIKit 对称）**：

1. `onChunk` **仅** `session.append(...)` — 不在 chunk 路径写入 `messages.content` 或切换静态视图。
2. `handleStreamComplete()` 先 `session.finish()`，再等待 `session.isPromoted == true`（订阅 `$isPromoted`），然后将 **当前 session** 转移到 `messages[].renderSession`，写入 `content` 快照并设 `isStreaming = false`，再 `recreateSession()` 供下一条消息使用。
3. 流式阶段 UI 绑定 `InkStreamMarkdownView(session: viewModel.session)`；promotion 完成后 UI **仍**绑定 `InkStreamMarkdownView(session: msg.renderSession)`（同一会话，Coordinator 内部切换块级布局）；仅错误/取消回退 `InkMarkdownView(msg.content, ...)`。
4. 配置经 `DemoInkConfigurationBuilder.makeChatConfiguration` 注入 session；trait 变化须对所有 `messages[].renderSession` 调用 `updateRenderEnvironment`。

finish 路径的 `@Published` defer 见 [09 §12](09-swiftui-uiviewrepresentable-gotchas.md#12-publishing-与-session-defer)。

## Demo 限制与走查结论

以下行为为 **已知限制或演示边界**，完整症状与复现见 [走查 SSOT](../qa/example-app-walkthrough-issues.md)：

| 主题 | 限制 |
| --- | --- |
| 流式表格 | `InkStreamRenderer` 无 GFM 增量表；流式阶段表格呈管道文本，`finish()` 后 promotion 为真表 |
| 远程图片 | 须 `isEnabled` + `allowedHosts`；库默认 fail-closed 未改 |
| 真实 LLM | 预设网关 `https://www.rightapi.ai/codex/v1`，model `gpt-5.6-luna`；Example `LLMErrorMapper`（非库 API）映射 TLS 等 NSURLError。**禁止关 ATS** |
| 控制台噪声 | LaunchServices、WebKit/Mermaid、TextKit 1、第三方 IME — 见 [FAQ §19](06-faq.md#19-控制台噪声simulator--系统) |
| 长文样例 | 当前样例较短、不含 Mermaid；该页不创建 WKWebView |

## 对应源码

- `ExampleApp/ExampleApp/CategoryListViewController.swift`：UIKit 分类入口与 `UIHostingController` 集成。
- `ExampleApp/ExampleApp/Model/DemoCatalog.swift`：六个对称场景目录。
- `ExampleApp/ExampleApp/Presentation/Shared/DemoInkConfigurationBuilder.swift`：`makeStaticConfiguration` / `makeComponentsConfiguration` / `makeChatConfiguration` 等配置工厂。
- `ExampleApp/ExampleApp/Presentation/Streaming/StreamingDemoViewModel.swift`：场景 4 共用 ViewModel。
- `ExampleApp/ExampleApp/Presentation/Chat/ChatDemoViewModel.swift`：场景 5 共用 ViewModel（`onChunk` / `isPromoted` 契约）。
- `ExampleApp/ExampleApp/Presentation/Shared/DemoLinkOpening.swift`：链接 handler。
- `ExampleApp/ExampleApp/Presentation/Shared/LLMErrorMapper.swift`：Example 网络错误映射（非库）。
- `ExampleApp/ExampleApp/SwiftUI/`：SwiftUI 六个示例视图。
- `ExampleApp/ExampleApp/Detail/`：UIKit 对称示例 ViewController。
- `ExampleApp/ExampleApp.xcodeproj/project.pbxproj`：将本地包的 `InkMarkdownSwiftUI` product 链接到示例 App。

这些示例只证明 adapter 的接入路径和交互入口；它们不代表尚未完成的 iOS/iPadOS 14 全量验证、完整语义/可访问性矩阵或性能基线已经交付。
