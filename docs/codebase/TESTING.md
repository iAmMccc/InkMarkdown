# Testing

## Core Sections (Required)

### 1) Framework and Runner

| Item | Value | Evidence |
|------|-------|----------|
| Framework | **Swift Testing + XCTest** | `import Testing` / `@Test` / `@Suite`；现有 XCTest 测试 |
| Location | `Tests/InkMarkdownTests/`、`Tests/InkMarkdownSwiftUITests/` | `Package.swift` testTarget |
| Host requirement | **iOS Simulator**（UIKit / SwiftUI adapter） | `docs/current-status.md`、`AGENTS.md` |
| Last runner result | **178 passed, 0 failed**（2026-08-18，XcodeBuildMCP / iPhone 16 与 iPad Pro 11-inch (M4) / iOS 18.5）；同日 iPhone 17 Pro / iOS Simulator latest 全量 **192 passed / 1 failed**（`InkMermaidDiagramTypeRendererTests` / fixture `flowchart` / `.timedOut` @ 30s）；过滤该套件 **25/26 passed**；另一次全量曾 193 passed | `current-status.md` |
| Static declarations | Core 的 142 个 `@Test` declaration + 16 个 XCTest test method；另有 SwiftUI adapter 契约测试；参数化 `@Test(arguments:)` 会展开为额外 execution case | 测试源码统计 |
| Coverage gate | 无强制 coverage 阈值文件 | scan / 仓库根 |

### 2) Test File Map

| File | Focus |
|------|--------|
| `InkMarkdownTests.swift` | 固定行高、段落间距、appearance 默认值、混排、流式边界、标题/列表上下文样式 |
| `StreamingPerformanceTests.swift` | 增量与全量输出一致性；增量耗时 ≤ 全量 30% 闸门 |
| `InkMermaid/InkMermaidDiagramTypeRendererTests.swift` | Mermaid 各 diagram type 离线 PNG 渲染；共享 `InkMermaidImageRenderer`（30s timeout）；首 case `flowchart` 在 iPhone 17 Pro 上偶发 `.timedOut`（见已知测试限制） |
| `Snapshots/RenderSnapshot.swift` | 快照模型 + `RenderContractAssertions` 助手 |
| `Snapshots/SnapshotScaffoldTests.swift` | 快照基建冒烟 |
| `../InkMarkdownSwiftUITests/` | 静态 configuration 刷新、session 状态机、headless finish、重置与 configuration snapshot |

### 3) Assertion and Access Patterns

| Pattern | Usage | Evidence |
|---------|--------|----------|
| `#expect` | 主断言 | 全部测试文件 |
| `Issue.record` | 性能失败附加说明 | `StreamingPerformanceTests` |
| `@testable import InkMarkdown` | 访问 internal | 快照 / 多数测试 |
| `@_spi(Performance) @testable import` | 性能基准 SPI | 行高与流式性能测试 |
| 无网络 mock 框架 | 不依赖外部服务 | 纯内存渲染断言 |

### 4) How to Run

```bash
# 推荐：XcodeBuildMCP 发现 destination 后 test
# 回退：
xcodebuild -scheme InkMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  test
```

**错误做法：** 在 macOS host 直接执行 `swift test`，会报 `no such module 'UIKit'`。

### 5) What Is Covered vs Gaps

| Covered (evidence in tests) | Not yet (documented gaps) |
|-----------------------------|---------------------------|
| 固定行高与 baselineOffset | 完整 CommonMark / GFM 语义矩阵 |
| 流式稳定前缀 / 未闭合 fence / 列表续行 | 删除线语义契约测试 |
| 增量与全量输出一致性 + 性能闸门 | opt-in 图片策略契约测试（默认占位 + 开启真图） |
| 快照脚手架可用性 | ExampleApp UI 自动化（库测试未覆盖） |
| appearance 默认数值 | SwiftUI 完整 Markdown 语义、交互与可访问性矩阵 |
| SwiftUI 静态配置刷新、会话状态机、headless finish、重置与配置 snapshot | iOS/iPadOS 14 验证与性能基线 |
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
