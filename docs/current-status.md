# 当前项目状态

> 基线日期：2026-07-13。本文描述仓库中可验证的现状，不替代产品决策或未来路线。

InkMarkdown 已经越过初始化阶段，当前处于 **v1.0 前的实现完善与发布准备阶段**。核心 UIKit 渲染管线、块级组件、流式渲染和基础测试均已落地；主要缺口集中在公开 API 收敛、语法契约覆盖、CI 与发布工程。

## 一句话状态

```text
swift-markdown Markup
  → NSAttributedString 富文本
  → 必要时路由为 UIKit 块级 UIView
  → 可选流式增量渲染
```

- 产品范围：UIKit only；不提供 SwiftUI 后端。
- 当前可构建平台：`Package.swift` 只声明 iOS 14+。
- 工具链：Swift tools 6.2，包内使用 Swift 5 language mode。
- 当前依赖：`swift-markdown` **固定 revision** `07ebc9c071b22a5d021031b798c3a84b76281213`（ADR-001；见 `Package.swift` / `Package.resolved`）。
- CI：`.github/workflows/ci.yml` **钉死** `macos-26` + **Xcode 26.6**（Build `17F113`）+ **iPhone 17 Pro / iOS 26.5**；详见 [CI 排坑](contributor-guide/07-ci-and-toolchain-pitfalls.md)。
- 验证状态：2026-07-15，依赖 pin 后本地 `xcodebuild test -scheme InkMarkdown -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`：**32 tests passed，0 failed**（`TEST SUCCEEDED`）。

## 已落地能力

| 领域 | 当前实现 | 主要证据 |
| --- | --- | --- |
| 解析 | swift-markdown 的 `Document` / `Markup`，由 `InkParser` 薄封装 | `Parser/InkParser.swift` |
| 富文本渲染 | 标题、段落、强调、链接、行内代码、列表、引用等转为 `NSAttributedString` | `InkAttributedRenderer` |
| 样式配置 | 按语法元素拆分的 `InkAppearance`，单次渲染配置 `InkConfiguration` | `Configuration/` |
| 固定行高 | paragraph style + baseline offset，覆盖混排字体 | `applyFixedLineHeight` 与相关测试 |
| 块级路由 | 不能可靠塞进富文本的内容转为 `InkRenderableBlock` / `UIView` | `InkBlockRenderer`、`InkBlockHandler` |
| 内置块 | 代码块、表格、分割线 | `Rendering/Components/` |
| 扩展能力 | 源预处理、行内语法、块 handler、链接点击回调 | `InkConfiguration` |
| 流式渲染 | 稳定前缀 / 活跃后缀增量解析，解析与显示双缓冲 | `InkStreamRenderer` |
| 示例 | 富文本、块渲染、SSE、流式表格、性能入口 | `ExampleApp/` |
| 测试 | 行高、上下文样式、流式边界、性能一致性、语义快照骨架 | `Tests/InkMarkdownTests/` |

## 已知限制

| 限制 | 当前行为 |
| --- | --- |
| 图片 | 只输出文本占位，不负责下载、缓存或附件布局 |
| 删除线 | 能保留文本内容，尚未施加删除线样式 |
| 表格 | 需要 `InkBlockRenderer`；纯 `InkAttributedRenderer` 不提供网格布局 |
| 代码高亮 | 不内置语法高亮引擎 |
| 自定义背景绘制 | 行内代码背景与引用竖线依赖库提供的 TextKit 1 布局管理器 / block view |
| 超长流式输入 | `maxParseLength` 当前硬编码为 50,000 |
| 测试覆盖 | 已有 32 个测试，但完整 CommonMark/GFM 语义矩阵尚未覆盖 |
| 发布工程 | 已有 iOS Simulator CI；尚无 CHANGELOG 与稳定版本标签 |

## 决策与仓库现状的差异

这张表用于防止“目标状态”被误写成“已经支持”。

| 主题 | 项目决策 / 目标 | 仓库现状 | 后续动作 |
| --- | --- | --- | --- |
| UI 范围 | UIKit only，不做 SwiftUI | 源码全部走 UIKit；已一致 | 文档持续保持 UIKit 定位 |
| 平台矩阵 | iOS 14+、macOS 11+、tvOS 14+、watchOS 7+ | `Package.swift` 只声明 iOS 14+，源码直接依赖 UIKit | 在完成条件编译与逐平台验证前，只对外宣称 iOS 14+ |
| 依赖策略 | **ADR-001**：对外固定 revision；本地 `Packages/Caches` 仅可选离线 | **已 pin** `swift-markdown` revision；传递依赖 `swift-cmark` 仍随上游 manifest 的 `gfm` 分支 + resolved revision；脚本与缓存仍可选 | 升级依赖时改 revision 并跑 CI/本地测试 |
| 平台矩阵 | **ADR-002**：v1.0 对外仅 iOS 14+；多平台为路线图 | `Package.swift` 仅 iOS 14+；源码 UIKit | 文档避免把目标矩阵写成已支持 |
| 图片 / 删除线 | **ADR-004**：v1 仅占位 / 不承诺删除线样式 | 与实现对齐 | 不阻塞 v1.0；实现时补 spec+测试 |
| 流式长度 | **ADR-005**：`maxParseLength` 可配置，默认 50_000 | 仍硬编码于 `InkStreamRenderer` | 后续改配置面并补测试 |
| CI | 建立 iOS Simulator 自动测试 | **已钉死** Xcode 26.6 + iPhone 17 Pro/OS 26.5（见 workflow `env`） | 镜像升级时显式改 `env` 并更新排坑文档 |
| SmartCodable | 早期知识中列为依赖 | 当前 manifest 和源码均未使用 | 若无明确用途，从项目依赖说明中移除；否则在引入时补设计说明 |
| 项目阶段 | 早期文档写“初始化” | 核心实现、ExampleApp 与测试已存在 | 统一改为 v1.0 前完善阶段 |

## 正确的构建与测试方式

本包直接依赖 UIKit。在 macOS host 上运行 `swift build` / `swift test` 会出现 `no such module 'UIKit'`，这不代表 iOS target 构建失败。

构建和测试默认使用 XcodeBuildMCP：先确认 session defaults，再发现工程、scheme 和可用 iOS Simulator。当前会话能发现 `ExampleApp/ExampleApp.xcodeproj` 和 `InkMarkdown` scheme，但没有暴露 SwiftPM package test workflow；工程中的 package scheme 也没有 test action。因此本次验证在记录结构化失败后，回退到 package 根目录的原生 `xcodebuild`。

完整步骤和回退命令见[开发指南](contributor-guide/04-development.md#构建与测试)。

## v1.0 前优先级

1. 补齐 CommonMark 与已支持 GFM 的语义断言。
2. 审计 public API，并为公开 API 补齐中文文档注释。
3. ~~固化依赖策略~~ → 已 pin revision（ADR-001）；后续按需升级 revision。
4. ~~建立 iOS Simulator CI~~ → 已添加 `.github/workflows/ci.yml`。
5. 增加 CHANGELOG、版本策略和稳定 tag。
6. 明确图片与删除线的 v1 行为契约（决策见 ADR-004；实现仍可后置）。

详细里程碑见 [roadmap.md](roadmap.md)。开发者学习路径见 [文档首页](README.md)。

## 维护触发条件

出现以下变化时必须更新本文：

- `Package.swift` 的平台、依赖或 Swift 版本变化；
- 新增或移除公开 Renderer、配置项或扩展点；
- Markdown 支持矩阵变化；
- 测试数量或验证方式发生实质变化；
- CI、版本标签或发布状态变化。
