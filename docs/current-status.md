# 当前项目状态

> 基线日期：2026-08-20。记录仓库可验证现状；计划与已交付能力严格区分。

`0.0.1` 已作为 UIKit-first public beta 发布。核心 UIKit 渲染管线、块级组件、流式渲染及基础测试已具备；`0.0.2` 的目标是交付正式 `InkMarkdownSwiftUI` adapter product。此前被拒绝的 SwiftUI spike 已移出仓库；当前 adapter 已按 ADR-008 实现并通过 iPhone/iPad Simulator 自动化测试（提供 `InkMarkdownView`、`InkStreamMarkdownView`、`InkMarkdownRenderSession`、`.inkConfiguration()` 等）。ExampleApp 已补充 SwiftUI adapter 的静态、配置和流式示例入口，并以 iOS 14.0 部署目标完成编译；iOS/iPadOS 14 实际运行、完整语义/可访问性与性能基线仍未完成，不能视为已发布支持。

## 状态概览

```text
swift-markdown Markup
  → NSAttributedString 富文本
  → 路由为 UIKit 块级 UIView（按需）
  → 流式增量渲染（可选）
```

- **已发布产品范围**：`0.0.1` 仅支持 UIKit。
- **v0.0.2 目标范围**：独立 `InkMarkdownSwiftUI` adapter product，复用 UIKit rendering engine；详细设计见 [ADR-008](decisions/ADR-008-swiftui-adapter-architecture.md)。
- **正式目标平台**：iOS 14+、iPadOS 14+。`Package.swift` 与 ExampleApp 均收敛为 iOS 14.0；iOS/iPadOS 14 的实际运行验证仍是 release blocker。
- **工具链**：Swift tools 6.2，包内使用 Swift 5 语言模式。
- **依赖管理**：`swift-markdown` 锁定 revision `07ebc9c071b22a5d021031b798c3a84b76281213`（ADR-001，详见 `Package.swift` / `Package.resolved`）。
- **CI 环境**：`.github/workflows/ci.yml` 指定 `macos-26` + **Xcode 26.6**（Build `17F113`）+ **iPhone 17 Pro / iOS 26.5**（详见 [CI 排坑](contributor-guide/07-ci-and-toolchain-pitfalls.md)）。
- **验证结果**：SwiftUI adapter P0 闸门（`InkMarkdownP0GateTests`）与全量 SPM 测试需在 iOS Simulator 上执行；**iOS/iPadOS 14 实测未交付**（本机无 iOS 14 runtime）。ExampleApp 以 **iOS 14.0** 部署目标完成编译验证，不能视为最低版本运行支持。

## 已落地能力

| 领域 | 实现方案 | 主要证据 |
| --- | --- | --- |
| 解析 | swift-markdown `Document` / `Markup`（`InkParser` 薄封装） | `Parser/InkParser.swift` |
| 富文本渲染 | 标题、段落、强调、链接、行内代码、列表、引用等转为 `NSAttributedString` | `InkAttributedRenderer` |
| 样式配置 | 按语法元素拆分 `InkAppearance`，单次渲染配置 `InkConfiguration` | `Configuration/` |
| 固定行高 | paragraph style + baseline offset，覆盖混排字体 | `applyFixedLineHeight` 及相关测试 |
| 块级路由 | 非富文本内容路由至 `InkRenderableBlock` / `UIView` | `InkBlockRenderer`、`InkBlockHandler` |
| 内置块 | 代码块、表格、分割线 | `Rendering/Components/` |
| 思考过程块 | 以 `<think>` / `<thought>` 前缀识别为可折叠 `InkThoughtBlock`；仅同名闭标签终止并保全后续 Markdown | `InkThoughtScanner`、`InkThoughtBlockHandler`、`InkThoughtBlock` |
| 自定义扩展 | 源码预清洗、自定义行内语法扩展、自定义块级路由、链接点击回调 | `InkConfiguration` |
| 流式渲染 | 稳定前缀 / 活跃后缀增量解析，解析与显示双缓冲 | `InkStreamRenderer` |
| 图片（opt-in） | 默认文本占位；`InkImageRendering.isEnabled = true` 启用真图（行内 `InkImageAttachment` + 独占块 `InkImageBlock`、Store、安全策略、降采样） | `Rendering/Image/`、`ExampleApp/ExampleApp/Detail/ImageDemoViewController.swift` |
| 示例程序 | 富文本、块渲染、SSE、流式表格、性能测试、图片与公式/图表 Demo 入口 | `ExampleApp/` |
| SwiftUI 桥接 | Wave 2 critic 复审：Hosting 测量/identity/ReservedHeight 共享边界重构中；`InkMarkdownP0GateTests` 为 P0 闸门；iOS/iPadOS 14 实测与完整语义矩阵仍为 release blocker | [ADR-008](decisions/ADR-008-swiftui-adapter-architecture.md) |
| 测试集 | 行高、上下文样式、流式边界、性能一致性、语义快照骨架 | `Tests/InkMarkdownTests/` |

**ExampleApp「公式与图表」**（用户可见总称，见 `CONTEXT.md`）提供三条验收路径：**组件 Pager**（LaTeX / Mermaid 分开展示）、**综合 Demo**（开启/关闭对照与失败错误条）、**SSE 流式**（块级闭合即生图）。LaTeX 与 Mermaid 均为 **opt-in**（默认关闭，不改变普通围栏语义）；架构与 Image Store 复用见 [ADR-007](decisions/ADR-007-local-generated-diagrams-and-formulas.md)。

## 已知限制

| 限制项 | 当前行为 |
| --- | --- |
| 图片 | **默认**输出文本占位（`InkImageRendering.isEnabled` 默认 `false`，与 ADR-004 一致）；opt-in 开启后走真图子系统（加载、缓存、附件/块布局），详见 [ADR-006](decisions/ADR-006-opt-in-image-rendering.md) |
| 删除线 | 文本与行内代码已实现 `.strikethroughStyle`；但 `inlineSyntaxes` 命中时（如 `@提及`）不继承删除线，图片叶子节点也不承诺删除线视觉效果（详见 [spec](spec/extended-syntax.md)） |
| 表格 | 依赖 `InkBlockRenderer`；纯 `InkAttributedRenderer` 不提供网格布局 |
| 代码高亮 | 未内置语法高亮引擎 |
| 背景绘制 | 行内代码背景与引用竖线依赖 TextKit 1 布局管理器 / block view |
| 超长流式输入 | `InkStreamRenderer.maximumSourceLength` 当前固定为 50,000；render session 使用同一上限以保证流式与终态 source 一致 |
| Mermaid 离线 PNG 测试 | Simulator 首次启动 WebProcess 可能被系统挂起；renderer 仅对 `.timedOut`、页面加载失败和页面进程终止丢弃页面并重试一次 |
| 测试覆盖率 | 2026-08-26 iPhone 17 Pro Simulator：adapter P0 闸门（`InkMarkdownP0GateTests`）+ 工作负载回归闸门（`InkMarkdownAdapterWorkloadTests`）；**iOS/iPadOS 14 实测未交付**（`list_sims` / `xcrun simctl list runtimes` 无 iOS 14 runtime，仅 iOS 18.5 / 26.5）；完整语义/交互矩阵与真机性能基线仍为 blocker |
| 发布工程 | 已有 `0.0.1` public beta 与 CHANGELOG；`0.0.2` 的 adapter 代码、基础契约测试和 SwiftUI ExampleApp 入口已具备，iOS/iPadOS 14 验证、可访问性、完整语义矩阵与性能基线仍是 release blocker |

## 决策与仓库现状差异

| 主题 | 项目决策 / 目标 | 仓库现状 | 后续动作 |
| --- | --- | --- | --- |
| UI 范围 | UIKit rendering engine + v0.0.2 SwiftUI adapter | 已发布 `0.0.1` 为 UIKit；`InkMarkdownSwiftUI` 已按 ADR-008 完成代码实现并通过基础 iPhone/iPad 契约测试 | 补齐语义、交互、可访问性与性能测试矩阵并作为发布门槛 |
| 平台矩阵 | iOS 14+、iPadOS 14+；不支持其他平台 | `Package.swift` 已仅声明 `.iOS(.v14)`，源码直接依赖 UIKit；当前验证目的地为 iOS/iPadOS 18.5 | v0.0.2 前完成 iOS/iPadOS 14 实机或 Simulator 验证；不为 macOS/tvOS/watchOS/visionOS 建立支持路径 |
| 依赖策略 | **ADR-001**：固定外部 revision | 已固定 `swift-markdown` revision；传递依赖 `swift-cmark` 遵循上游 manifest 的 `gfm` 分支与 resolved revision | 依赖升级时更新 revision 并验证测试 |
| 平台实施 | **ADR-008**：v0.0.2 仅承诺 iOS/iPadOS 14+ | manifest 与 ExampleApp deployment target 已收敛为 14.0；当前运行证据为 iOS Simulator 26.5 | 补齐最低版本验证后才以 iOS/iPadOS 14+ 对外承诺 |
| 图片 / 删除线 | **ADR-004**（默认占位）+ **ADR-006**（opt-in 真图）；删除线样式已实现 | opt-in 图片栈已落地；删除线已实现 `.strikethroughStyle` | spec 已更新；图片稳定性修复进行中 |
| 流式长度 | **ADR-005**：最大长度支持配置（默认 50_000） | 当前为 `InkStreamRenderer.maximumSourceLength` 固定值；render session 已复用该上限 | 开放配置项并补充测试 |
| CI 构建 | 建立 iOS Simulator 自动测试 | 统一使用 Xcode 26.6 + iPhone 17 Pro/OS 26.5 | 镜像升级时更新配置与排坑文档 |
| SmartCodable | 早期文档提及依赖 | 实际未引用 | 从依赖说明中移除 |
| 项目阶段 | `0.0.1` public beta 后的能力完善 | 已具备 UIKit core、ExampleApp 与 iPhone/iPad Simulator 测试；SwiftUI adapter 已实现并通过基础契约测试 | v0.0.2 完成最低版本、完整语义、可访问性、性能与 SwiftUI ExampleApp 验证后再发布 |

## 构建与测试说明

项目依赖 UIKit。在 macOS 环境直接运行 `swift build` 或 `swift test` 会提示 `no such module 'UIKit'`，该现象不代表 iOS target 构建失败。

构建与测试应优先使用 XcodeBuildMCP：先发现 workspace、scheme 与可用 iOS Simulator destination，再运行测试。仅在 MCP 不可用且已完成其安装/注册排查后，才回退为包根目录的原生 `xcodebuild`：

```bash
xcodebuild test -scheme InkMarkdown-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

具体步骤详见 [开发指南](contributor-guide/04-development.md#构建与测试)。

## v0.0.2 优先级

1. 补齐静态、流式、configuration、生命周期、iOS/iPadOS 14 与可访问性语义测试矩阵；当前基础 iPhone/iPad 契约测试已通过。
2. 建立可复现的性能基线与回归门槛；不以未经复现的 FPS、内存或竞品结论作为发布宣传。
3. 完成 SwiftUI ExampleApp 的设备验收并补齐可访问性覆盖；README、贡献者指南与状态证据已同步当前实现状态。
4. 持续补齐 CommonMark/GFM、图片 opt-in 等 UIKit core 契约。

详细里程碑见 [roadmap.md](roadmap.md)。开发者学习路径见 [文档首页](README.md)。

## 维护触发条件

发生以下变更时需更新本文：

- `Package.swift` 的平台、依赖或 Swift 版本变更；
- 新增或删除公开 Renderer、配置项或自定义扩展点；
- Markdown 支持矩阵变更；
- 测试数量或验证方式调整；
- CI、版本标签或发布状态更新。
