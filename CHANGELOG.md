# Change Log (变更日志)

本项目遵守 [Semantic Versioning (语义化版本 2.0.0)](https://semver.org/lang/zh-CN/) 规范。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

## [Unreleased]

> 本节记录当前 `feat/swiftUI` 分支的未发布工作，不表示 `0.0.2` 已发布。

### Added
- **SwiftUI 声明式适配器 (`InkMarkdownSwiftUI`)**：
  - 提供独立的 `InkMarkdownSwiftUI` target，使 SwiftUI 宿主复用 UIKit 核心渲染引擎语义；
  - 提供静态渲染入口 `InkMarkdownView`，支持参数传入与 `.inkConfiguration(...)` 环境修饰符；
  - 提供流式渲染入口 `InkStreamMarkdownView` 与单向数据流会话管理 `InkMarkdownRenderSession`；
  - 实现从流式打字机富文本到终态静态块级视图的原生无缝提升（Block Promotion）。
- **深度思考过程块 (`InkThoughtBlock` / `InkThoughtScanner`)**：
  - 核心解析层内置 `<think>...</think>` 与 `<thought>...</thought>` 语法扫描与块级路由；
  - 提供原生可交互、支持点击折叠/展开的 `InkThoughtBlockView` 卡片；
  - 支持尾随正文保全（Suffix Preservation），保证闭标签后的 Markdown 内容 100% 续接渲染；
  - 支持流式 PREFIX 思考卡片早期挂载与 Promotion 全生命周期的折叠状态保持（SSOT）。
- **Chat 列表滚动与吐字控制 (`ChatScrollPolicy`)**：
  - 统一管理 120pt 粘底判定（stickToBottom）与用户拖拽/减速期间的吐字暂停（shouldPauseDisplay）。
- **可替换图片后端（ADR-012）**：
  - 真图仍为 opt-in（`isEnabled` 默认 `false`）；开启后须注入 `InkImageBackend`，空 host allowlist 默认允许有效 HTTP(S)；
  - 可选 `InkMarkdownKingfisher` product 提供有界下载、解码、缓存、请求合并与取消；相对 URL 需 `baseURL`，核心校验来源，后端负责网络响应与资源限制；
  - 移除旧默认 URLSession loader，生成图复用所选后端；未配置后端时报告 `backendNotConfigured`。
- **无障碍语义与 Dynamic Type 路径**：
  - 为已实现组件补充可访问性状态表达与字号变化相关处理；
  - 完整 VoiceOver、系统级 Dynamic Type、全部组件语义与 iOS/iPadOS 15 runtime 验证仍未完成，不能据此宣称“完整无障碍”或最低系统支持。
- **自动化验证与手工验收边界**：
  - 验证结果与未验收项统一维护在 [当前状态](docs/current-status.md)，不以旧候选结果代替当前验收。
  - 自动化聚焦数据、状态、调用次数与关键渲染语义；UI / 真网图片 / 旋转 / Split View 见 ExampleApp 验收记录；该记录不表示 `0.0.2` 已达到发布条件。

### Changed
- 按 ADR-012 将资源预算、缓存和并发调度归所选图片后端，核心 Store 仅负责呈现订阅；旧接口按 [图片后端迁移指南](docs/contributor-guide/12-image-backends.md) 迁移。
- 将未发布的 SwiftUI adapter、LaTeX 与 Mermaid 能力拆为独立 products；已发布 `0.0.1` 仍只有 `InkMarkdown` product，消费者不应在 `0.0.1` 中导入 `0.0.2` 专用模块。
- v0.0.2 最低部署目标由 iOS / iPadOS 14 提升为 15；详见 ADR-010。历史 `0.0.1` 平台声明不变。
- 图片业务策略默认从 fail-closed 调整为开启真图后开放有效 HTTP(S)（仍与 ADR-004 默认占位兼容）。

### Fixed
- 流式合帧保留最早变更位置，已完成会话切换环境不重启打字机；极大或非正步长不会溢出、倒退或停滞。
- SwiftUI 等待接管的宿主不会改写活跃宿主环境，取消、重置和 handoff 保持单一呈现所有者。
- 表格 wrap 随实际内容宽度重排，scroll 保留自然宽度；cell 预处理、测量与复用共用 prepared source，避免重复 sourceFilter。
- Thought fallback 分隔、列表块顺序及 marker 上下文、拒绝图片的外层链接保持一致。
- 行内图片按实际宿主尺寸、scale、Store 和 loader 重新绑定；预览遵守缓存策略，外部关闭取消任务；HTTP 取消登记不会遗留 continuation。
- LaTeX 完整公式按请求像素预算缩放，并以整数像素控制实际输出尺寸。
- ExampleApp SSE 的延迟启动、已排队回调、服务释放和会话替换共用请求终止边界，迟到事件不再污染新消息。
- 修复 `InkThoughtScanner.stripThoughtTags` 正则由于 `^` 锚点导致非行首开标签未被剥离的 Bug；
- 修复 `InkMarkdownRenderSession.updateRenderEnvironment` 在流式进行中 Trait 变化未同步刷新 `streamingThought` 配置的问题。
- 修复 `InkImageStore` 在最后订阅取消时未取消 inflight，以及 `DisplayKey` 未纳入 loader identity 导致缓存串用的问题。

## [0.0.1] - 2026-07-30

首次公测发布（pre-release）。

### Added
- **富文本渲染引擎 (`InkAttributedRenderer`)**：
  - 支持将 CommonMark / GFM 文本转换为原生 `NSAttributedString`；
  - 实现双向锁死固定行高算法（`minimumLineHeight == maximumLineHeight`），消除跨字号/混排行高抖动；
  - 实现基于 `InkTextContext` 的自顶向下上下文传递机制。
- **块级视图路由引擎 (`InkBlockRenderer`)**：
  - 支持按节点类型将 AST 路由至原生 UIKit 视图组件；
  - 内置表格 block（`InkTableBlock`），支持列对齐与单元格文本交互；
  - 内置代码块 block（`InkCodeBlock`）与分割线 block（`InkThematicBreakBlock`）。
- **AI 增量流式渲染器 (`InkStreamRenderer`)**：
  - 基于 CADisplayLink 与后台解析队列的双缓冲增量更新机制；
  - 支持直接绑定 `UITextView` 进行差量更新；
  - 支持基于稳定前缀与活跃后缀的增量解析算法。
- **外观配置与扩展机制 (`InkConfiguration` / `InkAppearance`)**：
  - 支持全局与单次渲染的样式、字号、间距与颜色自定义；
  - 支持自定义行内语法扩展点 (`InkInlineSyntax`) 与自定义块路由处理器 (`InkBlockHandler`)；
  - 支持源文本预处理回调 (`sourceFilter`) 与链接点击捕获回调 (`linkTapHandler`)。
- **Opt-in 本地 LaTeX 与 Mermaid 支持**：
  - 支持行内公式 `$` / `\(` 及块级公式 `$$` / `\[` 的本地图片渲染；
  - 支持 Mermaid 围栏图表离线渲染，并通过独立块路由生成 `InkImageBlock`；
  - 提供受控统一内存图片 Store；
  - 升级支持 Mermaid 11+ 语法，并补充图类型测试用例。
- **测试套件与示例程序**：
  - 提供 iOS Simulator 自动化测试套件（涵盖行高、上下文、流式边界、性能、图片与 Mermaid）；
  - 提供完整的 ExampleApp 交互式演示程序。

---
