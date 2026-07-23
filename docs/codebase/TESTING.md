# Testing

## Core Sections (Required)

### 1) Framework and Runner

| Item | Value | Evidence |
|------|-------|----------|
| Framework | **Swift Testing**（非 XCTest） | `import Testing`、`@Test`、`@Suite` |
| Location | `Tests/InkMarkdownTests/` | `Package.swift` testTarget |
| Host requirement | **iOS Simulator**（UIKit） | `docs/current-status.md`、`AGENTS.md` |
| Approx. count | **32** `@Test`（2026-07-13 基线） | `rg '@Test ' Tests`；`current-status.md` |
| Coverage gate | 无强制 coverage 阈值文件 | scan / 仓库根 |

### 2) Test File Map

| File | Focus |
|------|--------|
| `InkMarkdownTests.swift` | 固定行高、段落间距、appearance 默认值、混排、流式边界、标题/列表上下文样式 |
| `StreamingPerformanceTests.swift` | 增量与全量输出一致性；增量耗时 ≤ 全量 30% 闸门 |
| `Snapshots/RenderSnapshot.swift` | 快照模型 + `RenderContractAssertions` 助手 |
| `Snapshots/SnapshotScaffoldTests.swift` | 快照基建冒烟 |

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
| 增量与全量输出一致性 + 性能闸门 | 图片策略契约（仅占位） |
| 快照脚手架可用性 | ExampleApp UI 自动化（库测试未覆盖） |
| appearance 默认数值 | — |
| CI 自动运行 iOS 测试（`.github/workflows/ci.yml`，push/PR 指定 Xcode 26.6 + iOS Simulator 26.5，见 `CONCERNS.md` High-2 Done） | — |

### 6) Performance Testing Notes

- `InkStreamingPerformanceBenchmark.measure()` 通过 `@_spi(Performance)` 暴露。
- 阈值：默认数据集 incremental/full ≈ 0.15–0.19；上限 **0.30** 用于吸收模拟器波动。
- 该测试为**回归闸门**，非微基准性能排行。

### 7) Evidence

- `Tests/InkMarkdownTests/**/*.swift`
- `Sources/InkMarkdown/Rendering/InkStreamRenderer.swift`（`InkStreamingPerformanceBenchmark`）
- `docs/current-status.md`
- `docs/codebase/.codebase-scan.txt`（PERFORMANCE & TESTING 段：无独立 perf 配置文件；CI/CD PIPELINES 段：`.github/workflows/ci.yml` 已核实存在）
- `.github/workflows/ci.yml`（push/PR 自动运行 iOS Simulator 测试）
- `docs/codebase/CONCERNS.md`（Top Risks：~~High~~ Done「无 CI」）
