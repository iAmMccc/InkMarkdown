# InkMarkdown implementation plan 验证记录（2026-09-04）

## 候选范围

- 分支：`feat/swiftUI`
- 基点：`eb7098f`
- 状态：未提交工作树；不是远端 CI 结果
- 工具链：Xcode 26.6（17F113），iPhone 17 Pro Max / iOS 26.5 Simulator
- 执行路径：当前 Agent 会话未暴露 XcodeBuildMCP；确认本机 `xcodebuildmcp` 2.6.2 已安装后，按仓库降级规则使用原生 `xcodebuild`，再用 `xcresulttool` 读取结构化结果

## 自动验证

| Gate | 结果 | 结构化摘要 |
| --- | --- | --- |
| `InkMarkdown-Package` test | 通过 | 342 tests，342 passed，0 failed，0 skipped；0 build warnings |
| `ExampleApp` Debug build | 通过 | 0 errors，0 build warnings |
| `ExampleApp` Release build | 通过 | 0 errors，0 build warnings |
| `ExampleApp` host test | 通过 | 1 test，1 passed，0 failed，0 skipped |
| consumer fixture manifest | 通过 | deployment platform 解析为 iOS 15.0；四个 consumer products 均存在 |
| `git diff --check` | 通过 | 无空白错误 |

ExampleApp host test 的依赖构建仍由 Xcode 报告两条警告，并已在全新 DerivedData 中复现：上游 `swift-cmark` 的 `DEFINES_MODULE was set, but no umbrella header could be found to generate the module map`，以及 Xcode 26 在 build-for-testing 中报告 `InkMarkdown` 缺少 `Markdown` 依赖。后者与 `Package.swift` 中已存在的显式 target dependency 不一致；添加 ExampleApp 侧重复 product dependency 不能消除，故未保留该无效改动，也未关闭 Explicit Modules 掩盖诊断。本记录不把这两条工具链/上游警告写成 0。

## 本轮新增或强化的回归

- 有序任务列表同时保留起始序号与 checkbox marker。
- 流式 `UITextView` 使用 `InkMarkdownLayoutManager`，覆盖 inline-code 背景与 blockquote bar 属性。
- `InkImageStore` 释放时直接移除 memory-warning observer；observer token 释放后也停止接收通知。
- 行内大图只抬升完整段落的 `maximumLineHeight`，保留最小行高、缩进、对齐与段落间距，且后到的小图不会降低既有上限。
- 零宽 UIKit host 从所属 window 建立首轮 intrinsic measurement width；detached 情形的 iOS 15 screen fallback 顺序由纯解析策略测试覆盖。这仍不是 iOS 15 runtime 证据。
- SwiftUI `ContentSizeCategory` 到 UIKit category 的关键映射与 accessibility 上界有直接测试。
- 亚像素宽度抖动复用 canonical measurement key，不清空也不扩张 continuity cache。

## 后续 XcodeBuildMCP 人工验收

- 设备：独立的 iPhone 17 Pro / iOS 26.5 Simulator（未复用其他项目占用的 iPhone 17 Pro Max）。
- 工具：会话重新加载后已使用 XcodeBuildMCP 2.6.2 完成最终 build、install、launch、截图与 host test；`ExampleApp` Debug build 通过，host test 为 1 passed、0 failed、0 skipped。
- 本轮按用户授权暂不执行 iOS 15 runtime 验收；该项仍是发布证据缺口，不视为已完成。

| 人工场景 | 结果 | 验收摘要 |
| --- | --- | --- |
| 静态 Markdown | 通过 | Thought 折叠、删除后，相邻 Thought 的展开状态与顺序保持。 |
| 自定义组件与富媒体 | 通过 | 表格、LaTeX、Mermaid 与宽图可见；更新自定义 H1 后 Thought 仍折叠。 |
| 网络图片 | 修复后通过 | `picsum.photos` 跳转至 `fastly.picsum.photos` 后仍通过 allowlist；图片加载、点击全屏预览与点击退出均通过，故意 404 的图片继续显示 fallback。 |
| 样式配置 | 通过 | 字号、段落间距、初始折叠策略与 Dark Mode 均即时更新。 |
| 单文档流式渲染 | 通过 | streaming、折叠、窄宽、卸载/重挂载、finish promotion 与终态 Dynamic Type 更新通过。 |
| AI SSE 对话 | 通过 | 预设自动发送、流式禁用发送、完成后恢复发送与终态内容展示通过。 |
| 综合长文 | 通过 | 可滚动至文末，代码块、表格及链接语义可见，无崩溃或空白。 |
| 旋转 | 通过 | 横屏内容重新布局，恢复竖屏后继续可交互。 |

人工验收暴露并修复两项 ExampleApp 集成问题：

1. 图片 allowlist 缺少 Picsum 实际 CDN 重定向主机，导致安全重定向校验按设计拒绝请求；现已加入 `fastly.picsum.photos`，没有放宽任意主机策略。
2. SwiftUI 页面每次计算配置都会重建未声明语义等价性的 `H1ActionCardBlockHandler`，状态变更后触发连续 reconcile，主线程长期占用 100%。该无状态 handler 现显式实现 `InkConfigurationSemanticsProviding`，更新 H1 后按钮、内容与折叠状态均稳定刷新。

针对图片重定向策略的单测曾单独发起，但新的 Package 测试 DerivedData 在解析 `swift-markdown` 时因 GitHub 443 连接失败而未进入测试执行；既有 `ImageBusinessPolicyTests.redirectDelegate_revalidatesWhenAllowlistConfigured` 已覆盖逐跳重校验。最终 ExampleApp build、host test 与人工红绿回归均通过。

## 尚未完成的发布证据

- iOS / iPadOS 15 runtime 实测（本轮按用户授权暂缓）。
- 真机性能基线、完整 VoiceOver。
- iPad Split View 人工验收。
- 最终候选 SHA 的远端 CI；当前未授权 commit 或 push。
