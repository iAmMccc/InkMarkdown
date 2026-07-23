# 当前项目状态

> 基线日期：2026-07-13。记录仓库可验证现状。

InkMarkdown 处于 **v1.0 发布准备阶段**。核心 UIKit 渲染管线、块级组件、流式渲染及基础测试已就绪；后续工作集中在公开 API 收敛、语法契约覆盖、CI 及发布工程。

## 状态概览

```text
swift-markdown Markup
  → NSAttributedString 富文本
  → 路由为 UIKit 块级 UIView（按需）
  → 流式增量渲染（可选）
```

- **产品范围**：仅支持 UIKit；不提供 SwiftUI 后端。
- **目标平台**：`Package.swift` 仅声明 iOS 14+。
- **工具链**：Swift tools 6.2，包内使用 Swift 5 语言模式。
- **依赖管理**：`swift-markdown` 锁定 revision `07ebc9c071b22a5d021031b798c3a84b76281213`（ADR-001，详见 `Package.swift` / `Package.resolved`）。
- **CI 环境**：`.github/workflows/ci.yml` 指定 `macos-26` + **Xcode 26.6**（Build `17F113`）+ **iPhone 17 Pro / iOS 26.5**（详见 [CI 排坑](contributor-guide/07-ci-and-toolchain-pitfalls.md)）。
- **验证结果**：2026-07-15，本地执行 `xcodebuild test -scheme InkMarkdown -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`：**32 项测试全部通过**。

## 已落地能力

| 领域 | 实现方案 | 主要证据 |
| --- | --- | --- |
| 解析 | swift-markdown `Document` / `Markup`（`InkParser` 薄封装） | `Parser/InkParser.swift` |
| 富文本渲染 | 标题、段落、强调、链接、行内代码、列表、引用等转为 `NSAttributedString` | `InkAttributedRenderer` |
| 样式配置 | 按语法元素拆分 `InkAppearance`，单次渲染配置 `InkConfiguration` | `Configuration/` |
| 固定行高 | paragraph style + baseline offset，覆盖混排字体 | `applyFixedLineHeight` 及相关测试 |
| 块级路由 | 非富文本内容路由至 `InkRenderableBlock` / `UIView` | `InkBlockRenderer`、`InkBlockHandler` |
| 内置块 | 代码块、表格、分割线 | `Rendering/Components/` |
| 自定义扩展 | 源码预清洗、自定义行内语法扩展、自定义块级路由、链接点击回调 | `InkConfiguration` |
| 流式渲染 | 稳定前缀 / 活跃后缀增量解析，解析与显示双缓冲 | `InkStreamRenderer` |
| 示例程序 | 富文本、块渲染、SSE、流式表格、性能测试入口 | `ExampleApp/` |
| 测试集 | 行高、上下文样式、流式边界、性能一致性、语义快照骨架 | `Tests/InkMarkdownTests/` |

## 已知限制

| 限制项 | 当前行为 |
| --- | --- |
| 图片 | 仅输出文本占位，不包含下载、缓存或附件布局 |
| 删除线 | 已实现 `.strikethroughStyle`；但 `inlineSyntaxes` 命中时（如 `@提及`）不继承删除线（详见 [spec](spec/extended-syntax.md)） |
| 表格 | 依赖 `InkBlockRenderer`；纯 `InkAttributedRenderer` 不提供网格布局 |
| 代码高亮 | 未内置语法高亮引擎 |
| 背景绘制 | 行内代码背景与引用竖线依赖 TextKit 1 布局管理器 / block view |
| 超长流式输入 | `maxParseLength` 当前硬编码为 50,000 |
| 测试覆盖率 | 包含 32 个测试，尚未完全覆盖 CommonMark/GFM 语义矩阵 |
| 发布工程 | 具备 iOS Simulator CI；尚无 CHANGELOG 和稳定版本 Tag |

## 决策与仓库现状差异

| 主题 | 项目决策 / 目标 | 仓库现状 | 后续动作 |
| --- | --- | --- | --- |
| UI 范围 | 仅支持 UIKit | 源码完全基于 UIKit | 保持纯 UIKit 定位 |
| 平台矩阵 | iOS 14+、macOS 11+、tvOS 14+、watchOS 7+ | `Package.swift` 仅声明 iOS 14+，源码直接依赖 UIKit | 完成条件编译与逐平台验证前，对外仅宣称 iOS 14+ |
| 依赖策略 | **ADR-001**：固定外部 revision | 已固定 `swift-markdown` revision；传递依赖 `swift-cmark` 遵循上游 manifest 的 `gfm` 分支与 resolved revision | 依赖升级时更新 revision 并验证测试 |
| 多平台实施 | **ADR-002**：v1.0 仅对外支持 iOS 14+ | `Package.swift` 仅声明 iOS 14+ | 文档不将多平台列为已支持 |
| 图片 / 删除线 | **ADR-004**：v1 仅占位 / 不承诺删除线样式 | 图片保留占位；已实现删除线样式 | 删除线已补充 spec；图片待实现时补充契约 |
| 流式长度 | **ADR-005**：`maxParseLength` 支持配置（默认 50_000） | 仍硬编码于 `InkStreamRenderer` | 开放配置项并补充测试 |
| CI 构建 | 建立 iOS Simulator 自动测试 | 统一使用 Xcode 26.6 + iPhone 17 Pro/OS 26.5 | 镜像升级时更新配置与排坑文档 |
| SmartCodable | 早期文档提及依赖 | 实际未引用 | 从依赖说明中移除 |
| 项目阶段 | 早期标识为“初始化阶段” | 已具备核心功能、ExampleApp 与测试 | 标记为 v1.0 发布准备阶段 |

## 构建与测试说明

项目依赖 UIKit。在 macOS 环境直接运行 `swift build` 或 `swift test` 会提示 `no such module 'UIKit'`，该现象不代表 iOS target 构建失败。

构建与测试应在包根目录使用原生 `xcodebuild` 工具：

```bash
xcodebuild test -scheme InkMarkdown -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

具体步骤详见 [开发指南](contributor-guide/04-development.md#构建与测试)。

## v1.0 前优先级

1. 补齐 CommonMark 与已支持 GFM 的语义断言。
2. 审计公开 API 并补齐中文文档注释。
3. 增加 CHANGELOG、版本策略与稳定版本 Tag。
4. 明确图片与删除线的 v1 行为契约（架构决策见 ADR-004）。

详细里程碑见 [roadmap.md](roadmap.md)。开发者学习路径见 [文档首页](README.md)。

## 维护触发条件

发生以下变更时需更新本文：

- `Package.swift` 的平台、依赖或 Swift 版本变更；
- 新增或删除公开 Renderer、配置项或自定义扩展点；
- Markdown 支持矩阵变更；
- 测试数量或验证方式调整；
- CI、版本标签或发布状态更新。
