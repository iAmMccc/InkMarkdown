# Change Log (变更日志)

本项目遵守 [Semantic Versioning (语义化版本 2.0.0)](https://semver.org/lang/zh-CN/) 规范。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

## [Unreleased]

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
- **无障碍 (VoiceOver) 与 Dynamic Type 增强**：
  - 为思考过程卡片、代码块、分割线等组件补充完整的无障碍标签、状态值与提示；
  - 适配超大字号 Dynamic Type 下的行高自适应与防截断排版。
- **性能与稳定性测试矩阵**：
  - 增加长文档 Block 渲染性能闸门与大屏幕宽视口适配测试，单测用例增至 252 项。

### Fixed
- 修复 `InkThoughtScanner.stripThoughtTags` 正则由于 `^` 锚点导致非行首开标签未被剥离的 Bug；
- 修复 `InkMarkdownRenderSession.updateRenderEnvironment` 在流式进行中 Trait 变化未同步刷新 `streamingThought` 配置的问题。

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
