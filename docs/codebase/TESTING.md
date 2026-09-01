# Testing

## Core Sections (Required)

### 1) Framework and Runner

| Item | Value | Evidence |
|------|-------|----------|
| Framework | **Swift Testing + XCTest** | `import Testing` / `@Test` / `@Suite`；现有 XCTest 测试 |
| Location | `Tests/` 下的 Core、addon contract、LaTeX、确定性 Mermaid、SwiftUI adapter 与 ExampleApp policy targets；`ExampleApp/ExampleAppMermaidIntegrationTests/` 为 app-hosted WebKit integration target | `Package.swift` testTarget + `ExampleApp.xcodeproj` |
| Host requirement | **iOS Simulator**（UIKit / SwiftUI adapter） | `docs/current-status.md`、`AGENTS.md` |
| P0 release gate | SwiftUI adapter P0 闸门：`Tests/InkMarkdownSwiftUITests/InkMarkdownP0GateTests.swift`（静态/流式测量、thought identity、promotion、trait 重测）；iOS 14 ICS 用例标记 `.disabled`（**实测未交付**） | `@Suite("SwiftUI Adapter P0 闸门")` |
| Static declarations | Core `@Test` + XCTest；SwiftUI adapter 契约与 P0 闸门；参数化 `@Test(arguments:)` 会展开为额外 execution case | 测试源码 |
| Coverage gate | 无强制 coverage 阈值文件 | scan / 仓库根 |

### 2) Test File Map

| File | Focus |
|------|--------|
| `InkMarkdownTests.swift` | 固定行高、段落间距、appearance 默认值、混排、流式边界、标题/列表上下文样式 |
| `StreamingPerformanceTests.swift` | 增量与全量输出一致性；增量耗时 ≤ 全量 30% 闸门 |
| `../InkMarkdownMermaidTests/InkMermaidRendererTests.swift` | Mermaid fence、cache、limits 与 bridge 资源等无需 App 生命周期的确定性契约 |
| `ExampleApp/ExampleAppMermaidIntegrationTests/MermaidRenderingIntegrationTests.swift` | 唯一真实 WebKit → PNG 关键链路；宽 journey 在 400px 约束下检查右侧内容未裁切，使用 production 默认 timeout 与一次有界重试 |
| `Snapshots/RenderSnapshot.swift` | 快照模型 + `RenderContractAssertions` 助手 |
| `Snapshots/SnapshotScaffoldTests.swift` | 快照基建冒烟 |
| `../InkMarkdownSwiftUITests/InkMarkdownAdapterWorkloadTests.swift` | Adapter 单环境工作负载回归闸门（静态长文测量、百片流式、promotion 时长；非 FPS/hitch 签收） |
| `../InkMarkdownSwiftUITests/` | P0 闸门（`InkMarkdownP0GateTests`）、单次测量、性能基线、VoiceOver/Dynamic Type adapter 契约 |

### 3) Assertion and Access Patterns

| Pattern | Usage | Evidence |
|---------|--------|----------|
| `#expect` | 主断言 | 全部测试文件 |
| `Issue.record` | 性能失败附加说明 | `StreamingPerformanceTests` |
| `@testable import InkMarkdown` | 访问 internal | 快照 / 多数测试 |
| `@_spi(Performance) @testable import` | 性能基准 SPI | 行高与流式性能测试 |
| 无网络 mock 框架 | 不依赖外部服务 | 纯内存渲染断言 |

### 4) How to Run

**推荐：** 使用 [XcodeBuildMCP](https://www.xcodebuildmcp.com/) 配置 session defaults 后执行 `test_sim`；scheme 为 **`InkMarkdown-Package`**，destination 须为 **iOS Simulator**（UIKit / SwiftUI adapter 依赖）。

P0 闸门位于 `Tests/InkMarkdownSwiftUITests/InkMarkdownP0GateTests.swift`，随上述 iOS Simulator 测试一并运行；勿以 macOS host 结果判定库是否可用。

```bash
# XcodeBuildMCP 不可用时的回退：
xcodebuild -scheme InkMarkdown-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  test

# 唯一需要真实 App 生命周期的 Mermaid PNG integration：
xcodebuild -project ExampleApp/ExampleApp.xcodeproj \
  -scheme ExampleApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:ExampleAppMermaidIntegrationTests \
  test
```

**错误做法：** 在 macOS host 直接执行 `swift test` 会报 `no such module 'UIKit'`——这是 host 平台限制，**不算** InkMarkdown 库逻辑失败。

### 5) What Is Covered vs Gaps

| Covered (evidence in tests) | Not yet (documented gaps) |
|-----------------------------|---------------------------|
| 固定行高与 baselineOffset | 完整 CommonMark / GFM 语义矩阵 |
| 流式稳定前缀 / 未闭合 fence / 列表续行 | 删除线语义契约测试 |
| 增量与全量输出一致性 + 性能闸门 | opt-in 图片策略契约测试（默认占位 + 开启真图） |
| 快照脚手架可用性 | ExampleApp UI 自动化（库测试未覆盖） |
| appearance 默认数值 | SwiftUI 完整 Markdown 语义、交互与可访问性矩阵 |
| SwiftUI 静态配置刷新、会话状态机、headless finish、重置与配置 snapshot | iOS/iPadOS 14 验证与性能基线 |
| App-hosted Mermaid WebKit → PNG 与右缘裁切关键链路 | 网络图片、完整表格/链接交互与系统级 VoiceOver 人工验收 |
| CI 自动运行 iOS 测试（`.github/workflows/ci.yml`，push/PR 指定 Xcode 26.6 + iOS Simulator 26.5，见 `CONCERNS.md` High-2 Done） | SwiftUI ExampleApp UI 自动化 |

### 6) Performance Testing Notes

- `InkStreamingPerformanceBenchmark.measure()` 通过 `@_spi(Performance)` 暴露。
- 当前代码配置的上限为 **0.30**；其校准依据需由可复现 benchmark artifact 记录，不能把阈值反推为通用性能结论。
- 该测试为**回归闸门**，非微基准性能排行。

### 7) Evidence

- `Tests/InkMarkdownTests/**/*.swift`
- `Sources/InkMarkdown/Rendering/InkStreamRenderer.swift`（`InkStreamingPerformanceBenchmark`）
- `docs/current-status.md`
- `docs/codebase/.codebase-scan.txt`（PERFORMANCE & TESTING 段：无独立 perf 配置文件；CI/CD PIPELINES 段：`.github/workflows/ci.yml` 已核实存在）
- `.github/workflows/ci.yml`（push/PR 自动运行 iOS Simulator 测试）
- `docs/codebase/CONCERNS.md`（Top Risks：~~High~~ Done「无 CI」）
