# 当前项目状态

核对日期：2026-09-09。本文记录当前源码可确认的能力和仍需验收的范围。版本发布记录见 [CHANGELOG](../CHANGELOG.md)；本地存在 `0.0.1` tag，本次未查询远端 Release。

## 当前实现

- UIKit-first：swift-markdown 解析，`NSAttributedString` 与可路由 `UIView` block 渲染；流式入口为 `InkStreamRenderer`。
- SwiftUI 是独立 presentation adapter，共享 UIKit 渲染语义；公开入口包括 `InkMarkdownView`、`InkStreamMarkdownView`、`InkMarkdownRenderSession` 和 `.inkConfiguration()`。v0.0.2 保持 Markup 直渲染，InkIR 仍为后续规划。
- [Package.swift](../Package.swift) 声明 iOS / iPadOS 15、Swift tools 6.2；生产 targets 使用 Swift 5 language mode。最低部署版本不等于已完成对应 runtime 验收。
- 五个 library products：`InkMarkdown`、`InkMarkdownSwiftUI`、`InkMarkdownLaTeX`、`InkMarkdownMermaid`、`InkMarkdownKingfisher`。
- 远程依赖固定为 swift-markdown revision `07ebc9c071b22a5d021031b798c3a84b76281213`、iosMath `2.3.1`、Kingfisher `8.12.0`。本地缓存只用于临时离线覆盖。
- 图片默认关闭。启用后由宿主注入 `InkImageBackend`，未配置后端报告 `backendNotConfigured`；可选 Kingfisher product 负责下载、解码、缓存、合并与取消。核心 Store 负责呈现订阅。详见 [图片后端](contributor-guide/12-image-backends.md)。
- SwiftUI 内部持有 block presentation continuity；表格呈现和宿主绑定按模块所有权维护。详见 [连续性](contributor-guide/11-block-presentation-continuity.md) 与 [布局测量](contributor-guide/13-layout-measurement-contract.md)。

## 已知边界

- 不承诺 macOS、tvOS、watchOS 或 visionOS；UIKit 包不能用 macOS host 的 `swift test` 结果验收。
- 纯 attributed-string 通道不提供表格网格和块级 UIView；LaTeX / Mermaid 按需启用。
- 删除线支持文本与行内代码；自定义 inline syntax 和图片的组合限制见 [语义规范](spec/extended-syntax.md)。
- 不内置代码语法高亮引擎。TextKit 1 仍承担自定义背景绘制。
- `maximumSourceLength` 默认 50,000，由 renderer/session 初始化时固定，流式与终态共享限制。
- 图片核心不替自定义后端检查其内部网络行为；Core 不依赖 Kingfisher target，但包级解析仍可能下载可选依赖。
- 无 App 宿主的 SwiftPM runner 不承担真实 Mermaid PNG 验收；该路径使用 ExampleApp app-hosted target。

## 尚需验收

本次仅整理文档和指令，未运行产品测试、构建、Simulator 交互或远端 CI；删除的旧候选测试数量不作为当前通过证明。v0.0.2 发布前仍需按 [发布清单](release-checklist.md) 为选定候选记录实际命令、SHA、scheme、destination 与结果。

- iOS / iPadOS 15 runtime、当前 iPhone / iPad 入口、Split View、旋转、Dynamic Type 与 VoiceOver。
- 布局测量最新改动的 chat 首轮高度、零宽恢复、表格与流式补通知，以及完整 layoutSubviews 调用栈的 ICS 观测；细项见 [当前布局验收项](qa/InkMarkdown-layout-measurement-contract-review-2026-09-08.md)。
- 真机滚动、长文流式、图片与生成图、WebKit 冷启动、峰值内存和长会话性能基线。
- 五个 product 的消费者构建、ExampleApp Debug / Release、app-hosted Mermaid 与受影响契约测试。
- 同一发布候选 SHA 的远程依赖解析、CI 和兼容性/迁移核验。ADR-012 已允许图片后端破坏式 API 迁移，不能再套用“所有旧 API 均不删除”的旧门槛。

## 维护方式

能力变化时更新对应指南与语义规范；状态变化只更新本页。不要复制历史测试计数、临时日志路径或另建“当前任务摘要”。测试和构建方式见 [开发指南](contributor-guide/04-development.md)，未来方向见 [路线图](roadmap.md)。
