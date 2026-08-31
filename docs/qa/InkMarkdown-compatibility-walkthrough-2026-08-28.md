# InkMarkdown 兼容性与 ExampleApp 可见走查（2026-08-28）

## 结论

本轮只能在当前机器已有的 iOS 18.5 与 iOS 26.5 Simulator 上执行。环境没有 iOS 14/15 runtime，也没有可用真机，因此不能把 iOS 14/15、发布目标的最低系统兼容性写成已验证。

已完成的最低可执行证据是：使用 XcodeBuildMCP 以 `ExampleApp` scheme 在 iPhone 17 / iOS 26.5 和 iPad Pro 11-inch (M5) / iOS 26.5 构建并启动；在 iPhone 上走查 UIKit 与 SwiftUI 入口、组件与富媒体页、静态页、配置页，并做截图与 runtime snapshot。iPad 本轮完成根页构建、启动、snapshot 和截图；由于任务时限，没有继续进入子场景。

## 已执行证据

### 环境、项目与构建

- `XcodeBuildMCP.list_sims` 返回 22 个可用 iOS Simulator：iOS 18.5 一组、iOS 26.5 一组；未返回 iOS 14 或 iOS 15 runtime。所有列出的设备最初为 Shutdown。
- 首次构建前已调用 `session_show_defaults`；当时 project、scheme、destination 均未配置。随后按实际发现结果配置 `ExampleApp/ExampleApp.xcodeproj`、`ExampleApp`、Debug、iOS Simulator、`useLatestOS=true`，没有在流程中预设 UUID。
- iPhone 构建/启动：scheme `ExampleApp`，destination `iPhone 17 / iOS 26.5`，bundle `Mccc.ExampleApp`，PID `40147`，XcodeBuildMCP 报告 Build & Run 成功（约 27.4 s）。
  - build log: `/Users/shizihan/Library/Developer/XcodeBuildMCP/workspaces/InkMarkdown-124472009cd9/logs/build_run_sim_2026-08-28T02-33-14-705Z_pid23692_f71662a2.log`
  - runtime log: `/Users/shizihan/Library/Developer/XcodeBuildMCP/workspaces/InkMarkdown-124472009cd9/logs/Mccc.ExampleApp_2026-08-28T02-33-38-735Z_helperpid40118_ownerpid23692_63407ff1.log`
- iPad 构建/启动：scheme `ExampleApp`，destination `iPad Pro 11-inch (M5) / iOS 26.5`，bundle `Mccc.ExampleApp`，PID `78585`，XcodeBuildMCP 报告 Build & Run 成功（约 56.4 s），diagnostics warnings/errors 为空。
  - build log: `/Users/shizihan/Library/Developer/XcodeBuildMCP/logs/build_run_sim_2026-08-28T02-56-04-002Z_pid23692_bbf2391d.log`
  - runtime log: `/Users/shizihan/Library/Developer/XcodeBuildMCP/logs/Mccc.ExampleApp_2026-08-28T02-56-54-505Z_helperpid78471_ownerpid23692_70fa6862.log`

### ExampleApp UI 覆盖

| 场景 | 设备 | 结果与证据 |
| --- | --- | --- |
| 根页与分类列表 | iPhone 17 / iOS 26.5 | 构建后 snapshot 成功；根页显示 UIKit 渲染引擎、SwiftUI 适配器。SwiftUI 分类页显示 6 个示例入口。 |
| UIKit 组件与富媒体 | iPhone 17 / iOS 26.5 | snapshot/截图成功；三个能力开关可见，表格、行内图片、块图片区域、公式与 Mermaid 入口均可到达。 |
| SwiftUI 组件与富媒体 | iPhone 17 / iOS 26.5 | snapshot/截图成功；LaTeX、Mermaid、图片开关可切换，外层 ScrollView 可滚动，Mermaid 图在等待稳定后可见。 |
| SwiftUI 静态 Markdown | iPhone 17 / iOS 26.5 | snapshot/截图成功；`InkMarkdownView` 内容、标题、段落、列表、行内代码、链接说明、表格说明等文本可见。宿主 ScrollView 与 adapter 非滚动内容的组合可见。未执行链接激活。 |
| SwiftUI 配置与动态主题 | iPhone 17 / iOS 26.5 | snapshot/截图成功；“放大正文与标题”“收紧段落间距”开关均可点按，等待后对应开关状态为 1，显式 configuration 与 Environment 说明均可见。 |
| SwiftUI 流式、AI Chat、综合长文 | — | 本轮未进入并未宣称通过；需要后续独立走查。 |
| iPad 根页 | iPad Pro 11-inch (M5) / iOS 26.5 | 构建、启动、snapshot、551×800 截图成功；根页两类入口可见。未进入子场景。 |

## 观察到的问题

以下是本轮真实可见结果，不等同于已经定位根因：

1. **LaTeX（已定位并修正 Demo 输入）：** 首次走查时，UIKit 与 SwiftUI 组件页的行内公式已进入附件路径，但块公式 `$$ ... $$` 仍显示原文。根因是组件 Demo 的说明文字与 opening `$$` 之间缺少空行，CommonMark 将二者合并为同一 Paragraph，不满足“块公式独占段落”的公开契约。现已同时修正 UIKit/SwiftUI 示例输入，并在最终代码上重新构建、安装、启动 ExampleApp。库内 `InkLaTeXBlockHandler` 与 addon pipeline 契约测试均通过；修正后的块公式仍需一次人工可见复核，不能仅凭编译写成视觉通过。
2. **图片与 ReservedHeight：** 组件页等待 UI settled 后，块图片位置显示为紧凑的 `[🖼 image]` 占位，而非可见远程图片。本轮没有稳定网络/白名单/资源响应证据，也没有测量占位高度随图片加载的变化，因此“图片加载失败/占位策略”和“ReservedHeight 是否正确”都只能记为未定结论，不能直接判定为单一布局 bug。
3. **表格窄屏：** iPhone 竖屏组件截图中，表格右侧“交互支持”等列文字被屏幕右边缘裁切；UIKit 与 SwiftUI 组件页均能看到窄列现象。此轮没有在 iPad 子页或手势上验证横向滑动/复制是否可用，故只记录为 iPhone 可见布局风险。
4. **Mermaid：** SwiftUI 组件页启用 Mermaid 后，等待 settled 后可见生成的流程图；本轮没有把 WebKit 冷启动、旋转或错误日志单独量化。
5. **链接：** 静态页 snapshot 能看到“链接”内容说明，但自动化 target 中没有链接激活目标，本轮未点击/未验证外部 URL 路由。现有走查文档记载的 LaunchServices 提示应作为系统噪声候选，不作为本轮应用失败证据。
6. **Thought：** 未进入 AI Chat，未执行包含 Thought/思考块的 mock 对话，因此没有通过/失败结论。
7. **Dynamic Type 与可访问性：** 配置页的“放大正文与标题”是示例内配置开关，不等同于系统 Dynamic Type。没有切换系统 content-size category，也没有 VoiceOver、键盘辅助、对比度或完整 accessibility tree 走查，均未验证。

## 系统噪声与测试隔离

- iPhone runtime log 出现：`Class UIAccessibilityLoaderWebShared is implemented in both ... WebCore.axbundle/WebCore and ... WebKit.axbundle/WebKit`。这是 Simulator/WebKit 的重复类警告；本轮未见 ExampleApp 自身异常，XcodeBuildMCP 构建 diagnostics 为空。
- iPhone 17 Pro Max Simulator 在早期被同机其他任务切换到另一应用界面，故排除其 UI 作为证据，改用独立的 iPhone 17 destination 重跑。该现象是测试隔离问题，不计为 InkMarkdown UI 失败。

## 无法执行的 blocker

- **iOS 14/15：** 当前 Xcode 安装仅有 iOS 18.5 与 iOS 26.5 runtime；没有可启动的 iOS 14 或 iOS 15 runtime，且无在线真机。无法执行目标最低系统验证。这是精确外部环境 blocker，不是“未发现问题”。
- **旋转 / Split View：** 本轮已用 XcodeBuildMCP 进行构建、启动、snapshot、截图和滚动；当前暴露的 UI 自动化能力没有可靠的旋转或 iPad Split View 分屏控制。未手工改变窗口方向/分栏状态，故不能声称覆盖。
- **无初始宽度：** 没有在 iOS 14/15、iPad 分栏窄列或宿主未提供初始宽度的独立容器条件下运行，未验证 adapter 的无初始宽度测量。
- **真图片高度与网络链路：** 未获得稳定资源响应/允许列表证据，ReservedHeight 的加载前后行为无法复现为可量化结论。

## 建议后续

1. 安装并启动 iOS 14、iOS 15 Simulator（或提供相应真机），按 iPhone/iPad、竖屏/横屏、Split View 宽度矩阵重跑。
2. 在专用、可控的本地图片资源和远程 allowlist 下复测图片加载前后高度，并记录 `ReservedHeight` 实际尺寸变化。
3. 对修正后的 UIKit/SwiftUI 组件页各做一次块公式可见复核；保留“说明文字与块分隔符之间必须有空行”的 CommonMark 输入约束。
4. 在 iPad 子场景完成表格横向滑动/复制、链接激活、Mermaid WebKit 冷启动和长文滚动检查。
5. 通过系统 Dynamic Type 设置和 VoiceOver 完成可访问性走查；进入 AI Chat 的 mock 流程验证 Thought 生命周期、折叠/完成态和滚动跟随。
