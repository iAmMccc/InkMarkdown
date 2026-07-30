# Change Log (变更日志)

本项目遵守 [Semantic Versioning (语义化版本 2.0.0)](https://semver.org/lang/zh-CN/) 规范。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

## [Unreleased]

## [0.0.1] - 2026-07-30

首次公测发布（pre-release）。

### Added
- **富文本渲染引擎 (`InkAttributedRenderer`)**：
  - 支持将 CommonMark / GFM 文本转换为原生 `NSAttributedString`；
  - 实现双向锁死固定行高算法（`minimumLineHeight == maximumLineHeight`），消除跨字号/混排行高抖动；
  - 实现基于 `InkTextContext` 的自顶向下上下文传递机制。
- **块级视图路由引擎 (`InkBlockRenderer`)**：
  - 支持按节点类型将 AST 路由至原生 UIKit 视图组件；
  - 内置表格视图组件 (`InkTableView`)，支持列对齐与单元格文本交互；
  - 内置代码块视图组件 (`InkCodeBlockView`) 与分割线视图组件 (`InkThematicBreakView`)。
- **AI 增量流式渲染器 (`InkStreamRenderer`)**：
  - 基于 CADisplayLink 与后台解析队列的双缓冲增量更新机制；
  - 支持直接绑定 `UITextView` 进行无卡顿差量渲染；
  - 支持基于稳定前缀与活跃后缀的增量解析算法。
- **外观配置与扩展机制 (`InkConfiguration` / `InkAppearance`)**：
  - 支持全局与单次渲染的样式、字号、间距与颜色自定义；
  - 支持自定义行内语法扩展点 (`InkInlineSyntax`) 与自定义块路由处理器 (`InkBlockHandler`)；
  - 支持源文本预处理回调 (`sourceFilter`) 与链接点击捕获回调 (`linkTapHandler`)。
- **Opt-in 本地 LaTeX 与 Mermaid 支持**：
  - 支持行内公式 `$` / `\(` 及块级公式 `$$` / `\[` 的本地图片渲染；
  - 支持 Mermaid 围栏图表离线渲染与独立块路由 (`InkMermaidBlockView`)；
  - 提供受控统一内存图片 Store；
  - 升级支持 Mermaid 11+ 语法，并补充图类型测试用例。
- **测试套件与示例程序**：
  - 提供 iOS Simulator 自动化测试套件（涵盖行高、上下文、流式边界、性能、图片与 Mermaid）；
  - 提供完整的 ExampleApp 交互式演示程序。

---
