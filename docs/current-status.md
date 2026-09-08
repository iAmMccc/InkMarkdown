# 当前项目状态

> 当前任务执行入口：[InkMarkdown 当前任务摘要](qa/InkMarkdown-current-task-summary-2026-08-28.md)。本页只记录项目交付事实与发布 blocker。

> 基线日期：2026-09-06。记录仓库可验证现状；计划与已交付能力严格区分。

`0.0.1` 已作为 UIKit-first public beta 发布。核心 UIKit 渲染管线、块级组件、流式渲染及基础测试已具备；`0.0.2` 的目标是交付正式 `InkMarkdownSwiftUI` adapter product。此前被拒绝的 SwiftUI spike 已移出仓库；当前 adapter 已按 ADR-008 / ADR-009 实现（提供 `InkMarkdownView`、`InkStreamMarkdownView`、`InkMarkdownRenderSession`、`.inkConfiguration()` 与内部 Block Presentation Continuity module）。ADR-010 已将 v0.0.2 最低平台提升为 iOS / iPadOS 15；manifest、consumer fixture、ExampleApp 与源码兼容路径均收敛为 15.0。2026-09-04 当前未提交工作树在独立 iPhone 17 Pro / iOS 26.5 上通过 `InkMarkdown-Package` 343 项测试、ExampleApp Debug/Release 构建及 1 项宿主测试。

## 2026-09-07 图片后端重构

### 二轮审查修复：Asset Scale

Asset 首次降采样固定使用 scale 1，曾将 16×8pt 的 2x/3x 图片读成 32×16pt / 48×24pt。现保留原始 scale，并把像素上限换算成 Kingfisher 点尺寸；仅为 Asset 缓存键增加版本前缀，防止旧错误条目短路解码，不主动删除旧缓存或改变其他来源的缓存键。公开 API 与依赖不变。

回归采用真实 UIImage 与 Kingfisher 降采样，覆盖 1x/2x/3x、12px 降采样和 64px 不放大两档预算；另通过公开后端接口验证旧 Asset 磁盘条目不被读取、回填或删除。纯 Package runner 的主 bundle 位于 Xcode 只读目录，原主 bundle 夹具方案因权限失败而撤回；最终 scale 测试边界为资源查找后的内部降采样函数，不包含真实 `UIImage(named:)` 资源名称查找或 UI 验收。

先失败再通过的证据：`/tmp/InkMarkdown-asset-scale-red-2.xcresult`（scale/点尺寸断言失败）、`/tmp/InkMarkdown-asset-cache-red-2.xcresult`（旧缓存绕过资源查找）。最终 `InkMarkdown-Package` 在独立 iPhone 17 Pro / iOS 26.3.1 上 **359 通过，0 失败、0 跳过**（参数化展开 441 次）；结果 `/tmp/InkMarkdown-asset-scale-final.xcresult`，日志 `/tmp/InkMarkdown-asset-scale-final.log`。沿用纯 Package 项目发现限制下的原生 xcodebuild 回退，destination 由 XcodeBuildMCP 核验。`git diff --check` 通过；未重跑 ExampleApp、iOS 15 或 iPad 验收。以下为前序阶段证据。

### 审查修复补充

两项 P2 已通过先复现、再修复的回归：磁盘缓存此前将 8pt 的 2x/3x 生成图读成 16pt/24pt，现通过 Kingfisher serializer 保存实际 scale，使用 v2 磁盘命名空间，并仅在首次生产时写盘；非 2xx 和响应超限此前统一返回 URLSession -999，现保留首个拒绝原因并传递给后端调用方及 `onFailure`，主动 Task 取消不报告失败。测试覆盖 1x/2x/3x、新实例读取、HTTP 状态、Content-Length、累计字节和主动取消。

最终 `InkMarkdown-Package` 在同一独立 iPhone 17 Pro / iOS 26.3.1 上 **357 通过，0 失败、0 跳过**（参数化展开 434 次），结果：`/tmp/InkMarkdown-review-fixes-final.xcresult`，日志：`/tmp/InkMarkdown-review-fixes-final.log`。失败复现分别保留在 `/tmp/InkMarkdown-review-scale-red.xcresult`、`/tmp/InkMarkdown-review-errors-red.xcresult`。`git diff --check` 通过；本次未重跑 ExampleApp UI 或 iOS 15 / iPad 验收。以下重构阶段记录保留为历史证据。

### 重构阶段验证

按 [ADR-012](decisions/ADR-012-pluggable-image-management.md) 完成图片管理边界重构：核心通过 `InkImageBackend` 注入完整后端，可选 `InkMarkdownKingfisher` product 提供 Kingfisher 8.12.0 实现。旧默认 URLSession 下载、传输代理与自有解码实现已删除，InkImageStore 仅保留呈现订阅桥接。生成图和全屏预览复用所选后端。接入与破坏式迁移见 [图片后端指南](contributor-guide/12-image-backends.md)。

Xcode 26.3（17C529）、独立 iPhone 17 Pro / iOS 26.3.1 上，`InkMarkdown-Package` 的 xcresult 汇总为 **354 项通过，0 失败、0 跳过**（参数化展开后 427 次通过）。证据：`/tmp/InkMarkdown-Kingfisher-final.xcresult`；终端日志 `/tmp/InkMarkdown-Kingfisher-final.log`。纯 Package 的根目录未被 MCP 项目发现识别为 project/workspace，因此仅 Package 测试使用原生 xcodebuild，destination 来自 MCP 发现的运行环境。

独立消费端 `InkMarkdownCoreConsumer` 与 `InkMarkdownKingfisherConsumer` 均构建通过；Core consumer 包含 `canImport(Kingfisher)` 编译期禁止检查，验证自定义后端不需要编译 Kingfisher。SPM 仍解析并下载包级依赖，不承诺零下载。这是本地未提交工作树验证，不是远端 CI 或发布验收；iOS 15 / iPad 尚未在本轮运行。

ExampleApp 使用 XcodeBuildMCP 完成 Debug 宿主测试：**8 通过，0 失败、0 跳过**。结果位于 `~/Library/Developer/XcodeBuildMCP/workspaces/InkMarkdown-d04b98d79ed6/result-bundles/test_sim_2026-09-07T11-41-20-673Z_pid38782_0ed8072a.xcresult`。仍有 Xcode 对 Markdown 的 dependency-scan 警告；manifest 已显式声明该依赖。混用普通 build 与 test-products 的 DerivedData 曾导致旧 swiftmodule 遮蔽新 framework，宿主测试使用独立 `/tmp/InkMarkdown-Kingfisher-Hosted-DD` 后通过。

最终 Release 经 XcodeBuildMCP 构建并启动成功，日志：`~/Library/Developer/XcodeBuildMCP/workspaces/InkMarkdown-d04b98d79ed6/logs/build_run_sim_2026-09-07T11-55-31-448Z_pid38782_3550558f.log`。Simulator 实际操作确认富媒体页的行内图片、真网块级图片、失败占位、行内公式和点击全屏预览显示正常。检查期间发现并修复直接 Auto Layout 宿主的零高度启动问题：图片初始/复用高度预留 placeholderHeight，加载结果更新 intrinsic content size；最终 354 项 Package 回归已包含此修改。全屏预览截图：`/var/folders/yp/356dkv3n2bq1pqqvdr5j7y5h0000gn/T/screenshot_optimized_21e19a5b-b3c5-4d7b-983e-24f0b947686f.jpg`。本次为局部 UI 冒烟，不代表完整人工矩阵或真机验收；8 项宿主测试记录早于最终布局调整。

## 2026-09-07 架构深化联合终检（历史证据）

表格 / SwiftUI 宿主等架构深化工作在合并 ADR-012 图片后端之前，曾在本地工作树完成联合终检（证据 SHA `f71cc292…` 附近）。本地证据：

| 检查 | 结果 |
| --- | --- |
| `InkMarkdown-Package` 全量 | **288** 通过，0 失败，0 跳过；iPhone 17 Pro / `10F638E2-…` |
| 四 product consumer build | Core / SwiftUI / LaTeX / Mermaid 均 **BUILD SUCCEEDED** |
| ExampleApp Debug / Release | 均 **BUILD SUCCEEDED**（ExampleApp 三方依赖临时 local cache overlay，构建后恢复 remote `project.pbxproj`） |
| Package.swift | 验证期 path overlay 后已恢复 remote pin；**不等于**远程可解析 |
| ExampleApp 手工交互 | **未验证**（本轮排除） |
| 远程 CI | **未执行**（未 push） |
| iOS 15 runtime | **未验证** |

详细命令与路径见规划目录证据 `27-integrated-final-gates.md`（`.scratch/architecture-deepening-2026-09-07/evidence/`）。该记录早于 ADR-012 合并，测试数量与当前候选不可直接等同；合并后需以新一轮验证为准。本轮不构成发布授权。

## 2026-09-06 审核修复验证

用户批准按 [本轮审核报告](qa/InkMarkdown-project-audit-2026-09-05.md) 修复现有能力，图片配置所有权按 [ADR-011](decisions/ADR-011-image-store-configuration-ownership.md) 实施。当前工作树在 iPhone 17 Pro / iOS 26.5 与 iPhone 16 Pro / iOS 18.5 上分别通过 `InkMarkdown-Package` **361 项，0 失败、0 跳过**。该结果由 XcodeBuildMCP 实际运行取得，使用精确 revision 的本地依赖覆盖；不是远端 CI，也不代表已发布。

本轮按用户要求不验收 iOS 15，优先覆盖 iOS 18 与 26；deployment target 仍为 15。以下旧版平台发布门槛保留为历史产品目标，不作为本轮审核修复的阻塞条件。示例 App、运行交互和最终依赖恢复证据见审核报告。

## 状态概览

```text
swift-markdown Markup
  → NSAttributedString 富文本
  → 路由为 UIKit 块级 UIView（按需）
  → 流式增量渲染（可选）
```

- **已发布产品范围**：`0.0.1` 仅支持 UIKit。
- **v0.0.2 目标范围**：独立 `InkMarkdownSwiftUI` adapter product，复用 UIKit rendering engine；详细设计见 [ADR-008](decisions/ADR-008-swiftui-adapter-architecture.md)，最低平台变更见 [ADR-010](decisions/ADR-010-v0.0.2-minimum-platform-ios-15.md)。
- **正式目标平台**：iOS 15+、iPadOS 15+。`Package.swift` 与 `ExampleApp.xcodeproj` 均收敛为 iOS 15.0。
- **工具链**：Swift tools 6.2，包内使用 Swift 5 语言模式。
- **依赖管理**：`swift-markdown` 锁定 revision `07ebc9c071b22a5d021031b798c3a84b76281213`（ADR-001，详见 `Package.swift` / `Package.resolved`）。
- **CI 环境**：`.github/workflows/ci.yml` 指定 `macos-26` + **Xcode 26.6**（Build `17F113`）+ **iPhone 17 Pro / iOS 26.5**（详见 [CI 排坑](contributor-guide/07-ci-and-toolchain-pitfalls.md)）。
- **验证结果**：2026-09-04 当前未提交工作树于独立 iPhone 17 Pro / iOS 26.5 使用 XcodeBuildMCP 2.6.2 完成 `InkMarkdown-Package` 全量回归：**343 通过**，**0 失败**，**0 跳过**；`ExampleApp` Debug/Release 构建均通过，宿主测试 **1 通过、0 失败、0 跳过**。构建与测试日志没有 Swift deprecated API 诊断；宿主测试仍有上游 `swift-cmark` module-map 与 Xcode 26 dependency-scan 警告，ExampleApp build 有 App Intents metadata extraction 跳过提示。真网图片、全屏预览、表格竖横屏重排及其余 ExampleApp 人工矩阵已通过；iPad Split View 仍待验收。详见[验证记录](qa/InkMarkdown-implementation-plan-verification-2026-09-04.md)。

## 已落地能力

| 领域 | 实现方案 | 主要证据 |
| --- | --- | --- |
| 解析 | swift-markdown `Document` / `Markup`（`InkParser` 薄封装） | `Parser/InkParser.swift` |
| 富文本渲染 | 标题、段落、强调、链接、行内代码、列表、引用等转为 `NSAttributedString` | `InkAttributedRenderer` |
| 样式配置 | 按语法元素拆分 `InkAppearance`，单次渲染配置 `InkConfiguration` | `Configuration/` |
| 固定行高 | paragraph style + baseline offset，覆盖混排字体 | `applyFixedLineHeight` 及相关测试 |
| 块级路由 | 非富文本内容路由至 `InkRenderableBlock` / `UIView` | `InkBlockRenderer`、`InkBlockHandler` |
| 内置块 | 代码块、表格、分割线 | `Rendering/Components/` |
| 思考过程块 | 以 `<think>` / `<thought>` 前缀识别为可折叠 `InkThoughtBlock`；仅同名且不在 Markdown code span（含跨行 span）内的闭标签终止，并保全后续 Markdown。流式 PREFIX 由 core 增量 scanner 按 delta 推进，不在每片重扫完整 source | `InkThoughtScanner`、`InkThoughtScanner.StreamingScanner`、`InkThoughtBlockHandler`、`InkThoughtBlock` |
| 自定义扩展 | 源码预清洗、自定义行内语法扩展、自定义块级路由、链接点击回调 | `InkConfiguration` |
| 流式渲染 | 稳定前缀 / 活跃后缀增量解析，解析与显示双缓冲 | `InkStreamRenderer` |
| 图片（opt-in） | 默认文本占位；`InkImageRendering.isEnabled = true` 启用真图（行内 `InkImageAttachment` + 独占块 `InkImageBlock`、Store、安全策略、降采样） | `Rendering/Image/`、`ExampleApp/ExampleApp/Detail/ImageDemoViewController.swift` |
| 示例程序 | 富文本、块渲染、SSE、流式表格、性能测试、图片与公式/图表 Demo 入口 | `ExampleApp/` |
| SwiftUI 桥接 | Block Presentation Continuity module 统一拥有周期、lineage、Thought live state 与 attachment；container 仅执行原子 apply plan 和有界 measurement，static / streaming / promotion / remount 共用同一规则；宿主可提供 `preferredMeasurementWidth` 做首轮终态宽测量 | [ADR-008](decisions/ADR-008-swiftui-adapter-architecture.md)、[ADR-009](decisions/ADR-009-block-presentation-continuity.md)、[module 设计](contributor-guide/11-block-presentation-continuity.md)、[布局测量契约](contributor-guide/13-layout-measurement-contract.md) |
| 测试集 | 行高、上下文样式、流式边界、性能一致性、语义快照骨架 | `Tests/InkMarkdownTests/` |

**ExampleApp「公式与图表」**（用户可见总称，见 `CONTEXT.md`）提供三条验收路径：**组件 Pager**（LaTeX / Mermaid 分开展示）、**综合 Demo**（开启/关闭对照与失败错误条）、**SSE 流式**（块级闭合即生图）。LaTeX 与 Mermaid 均为 **opt-in**（默认关闭，不改变普通围栏语义）；架构与 Image Store 复用见 [ADR-007](decisions/ADR-007-local-generated-diagrams-and-formulas.md)。

## 已知限制

| 限制项 | 当前行为 |
| --- | --- |
| 图片 | **默认**输出文本占位（`InkImageRendering.isEnabled` 默认 `false`，与 ADR-004 一致）；opt-in 开启后走真图子系统。业务策略：空 host allowlist 默认允许有效 HTTP(S)；allowlist 可选。资源安全边界始终生效（scheme、2xx、图片数据、默认 20 MiB、最多 3 次重定向、最后订阅取消、loader identity 缓存隔离、相对 URL 需 `baseURL`）。详见 [ADR-006](decisions/ADR-006-opt-in-image-rendering.md) |
| 删除线 | 文本与行内代码已实现 `.strikethroughStyle`；但 `inlineSyntaxes` 命中时（如 `@提及`）不继承删除线，图片叶子节点也不承诺删除线视觉效果（详见 [spec](spec/extended-syntax.md)） |
| 表格 | 依赖 `InkBlockRenderer`；纯 `InkAttributedRenderer` 不提供网格布局 |
| 代码高亮 | 未内置语法高亮引擎 |
| 背景绘制 | 行内代码背景与引用竖线依赖 TextKit 1 布局管理器 / block view |
| 超长流式输入 | `InkStreamRenderer` 与 `InkMarkdownRenderSession` initializer 可配置 `maximumSourceLength`；默认 50,000，创建时固化 snapshot，流式与终态共用 canonical source |
| 首轮测量宽 | Chat / table 宿主应在 layout 前提供有限列宽；推荐 `preferredMeasurementWidth`。未提供时依赖 bounds / window /（容器 iOS 15）Scene fallback。块级 `sizeThatFits` 未知宽返回 `noIntrinsicMetric`，不再硬编码 320。[布局测量契约审查](qa/InkMarkdown-layout-measurement-contract-review-2026-09-08.md) F1–F3 已按建议修复（代码+契约测试）；Simulator 交互/远程 CI 仍待宿主验收。 |
| Mermaid 离线 PNG 测试 | 无 App 宿主的 SwiftPM runner 可能挂起离屏 WebProcess；唯一真实 PNG/右缘裁切关键链路已迁入 ExampleApp app-hosted test target，Package target 只保留确定性 addon/bridge 契约。Production renderer 仍只对 `.timedOut`、页面加载失败和页面进程终止丢弃页面并重试一次 |
| 测试覆盖率 | 最新本地工作树回归见本文“本地验证基线”；**非远端 CI**。Block continuity 保留数据/状态关键路径自动化；真网图片与核心交互矩阵已在独立 iPhone 17 Pro 验收；**iOS/iPadOS 15 runtime 实测未交付**，完整产品可访问性、iPad Split View 与真机性能基线仍为 blocker |
| 发布工程 | 已有 `0.0.1` public beta 与 CHANGELOG；`0.0.2` 的 adapter 代码、基础契约测试和 SwiftUI ExampleApp 入口已具备，iOS/iPadOS 15 验证、可访问性、完整语义矩阵与性能基线仍是 release blocker |

## 决策与仓库现状差异

| 主题 | 项目决策 / 目标 | 仓库现状 | 后续动作 |
| --- | --- | --- | --- |
| UI 范围 | UIKit rendering engine + v0.0.2 SwiftUI adapter | 已发布 `0.0.1` 为 UIKit；`InkMarkdownSwiftUI` 已按 ADR-008 / ADR-009 完成当前代码实现与关键契约测试；2026-09-04 ExampleApp Debug/Release、宿主测试与 iPhone 人工交互矩阵已通过 | 补齐 iPad Split View、可访问性与真机性能门槛 |
| 平台矩阵 | iOS 15+、iPadOS 15+；不支持其他平台 | `Package.swift` 已仅声明 `.iOS(.v15)`；iOS 15 可直接使用的 API 不再保留 iOS 14 availability 分支，显示尺寸从 view/window/前台 Scene 解析；当前最新自动回归目的地为独立 iPhone 17 Pro / iOS 26.5，iOS/iPadOS 15 runtime 尚未验证 | v0.0.2 前完成 iOS/iPadOS 15 实机或 Simulator 验证；不为其他平台建立支持路径 |
| 依赖策略 | **ADR-001**：固定外部 revision | 已固定 `swift-markdown` revision；传递依赖 `swift-cmark` 遵循上游 manifest 的 `gfm` 分支与 resolved revision | 依赖升级时更新 revision 并验证测试 |
| 平台实施 | **ADR-010**：v0.0.2 最低平台提升为 iOS/iPadOS 15+ | manifest、consumer fixture 与 ExampleApp deployment target 已收敛为 15.0；当前运行证据来自 iOS 26.5 Simulator，尚无 iOS/iPadOS 15 runtime 证据 | 补齐最低版本验证后才以 iOS/iPadOS 15+ 对外承诺 |
| 图片 / 删除线 | **ADR-004**（默认占位）+ **ADR-006**（opt-in 真图）；删除线样式已实现 | opt-in 图片栈与本轮稳定性修复已落地；删除线已实现 `.strikethroughStyle` | 补齐完整语义、最低版本、人工交互与性能证据 |
| 流式长度 | **ADR-005**：最大长度支持配置（默认 50_000） | renderer/session initializer 已开放配置，并共享不可变 source-limit snapshot；边界测试已落地 | 已收口；后续变更默认值须重跑性能基线 |
| CI 构建 | 建立 iOS Simulator 自动测试 | 工作流已配置为 Xcode 26.6 + iPhone 17 Pro/OS 26.5，并拆分 Core、SwiftUI、addon、ExampleApp app-hosted 与四 product 消费者任务；PR job 显式检出并校验 head SHA。2026-09-04 当前候选尚未 push，故无同一 SHA 的远端执行证据 | 维护者授权后 push，并以最终候选 SHA 执行远端 CI；未运行前不写成通过 |
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

1. 补齐静态、流式、configuration、生命周期、iOS/iPadOS 15 runtime 与可访问性语义测试矩阵；当前基础自动契约测试已通过。
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
