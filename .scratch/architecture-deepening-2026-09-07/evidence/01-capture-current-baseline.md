# 01 验证证据（Outcome 别名：01-baseline）

- 日期：2026-09-07
- Branch / HEAD：`feat/swiftUI` / `f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 规划定位基线：`ee049f0`（仅供定位；本次未退回该提交）
- 工作树范围与相关 diff 摘要：
  - 开工时 `git status` 干净（相对 HEAD）。
  - 本票仅新增本 evidence 目录下的记录与一次本地运行产物；未改生产源码。
  - 验证期间曾临时改写 `Package.swift` 与 `Packages/Caches/swift-markdown/Package.swift` 为 path overlay；结束后已逐字节恢复远程 pin。`Package.resolved` 曾被 SPM 删除，已 `git checkout -- Package.resolved` 恢复。
  - 结束后工作树仅剩未跟踪 evidence 文件，发布 manifest / resolved 无残留 diff。
- 依赖：local overlay（仅本机验证）
  - 原因：`https://github.com` 不可达（curl/xcodebuild 远程 resolve 超时/失败）。
  - 覆盖：`Packages/Caches/swift-markdown@07ebc9c0…`、`Packages/Caches/iosMath`、`Packages/Caches/swift-cmark@0101bf2c…`。
  - 不代表远程依赖可解析或 CI 已通过；发布 manifest 保持 revision/`exact` pin。
- Toolchain / scheme / destination：
  - Xcode 26.6 (Build 17F113)
  - workspace：`.swiftpm/xcode/package.xcworkspace`
  - scheme：`InkMarkdown-Package`
  - destination：`platform=iOS Simulator,id=10F638E2-84FB-42AE-9BAE-0E246F463E8D`（iPhone 17 Pro，iOS 26.5，当时已 Booted）
  - 另有 iOS 18.5 设备可用，本票未另跑；记为未验证样本。
- 实际命令：

```sh
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -list
xcodebuild test \
  -workspace .swiftpm/xcode/package.xcworkspace \
  -scheme InkMarkdown-Package \
  -destination 'platform=iOS Simulator,id=10F638E2-84FB-42AE-9BAE-0E246F463E8D' \
  -only-testing:InkMarkdownTests/InkAuditSemanticRegressionTests \
  -only-testing:InkMarkdownTests/InkCorpusTableTracerTests \
  -only-testing:InkMarkdownTests/InkImageStoreTests \
  -only-testing:InkMarkdownSwiftUITests/InkMarkdownRenderSessionTests \
  -only-testing:InkMarkdownSwiftUITests/InkBlockPresentationContinuityTests \
  -only-testing:InkMarkdownSwiftUITests/InkMarkdownAdapterWorkloadTests \
  -resultBundlePath "$PWD/.scratch/architecture-deepening-2026-09-07/evidence/20260907-1135-ticket-01/tests.xcresult" \
  CODE_SIGNING_ALLOWED=NO
```

- 自动测试：通过 51 / 失败 0 / 跳过 0 / 未执行 0（按两次 `Test run with N tests in 3 suites` 汇总：22 + 29）
  - SwiftUI：`InkMarkdownAdapterWorkloadTests`、`InkBlockPresentationContinuityTests`、`InkMarkdownRenderSessionTests` → 22 tests，3 suites，passed
  - UIKit/Store：`InkAuditSemanticRegressionTests`、`InkCorpusTableTracerTests`、`InkImageStoreTests` → 29 tests，3 suites，passed
  - 日志另见 XCTest host 对 `InkMarkdownTests.xctest` 报告 “Executed 0 tests”（Swift Testing 宿主噪音）；不以该行计通过。
- log / xcresult：
  - `/Users/shizihan/DailyUse/Github/InkMarkdown/.scratch/architecture-deepening-2026-09-07/evidence/20260907-1135-ticket-01/test.log`
  - `/Users/shizihan/DailyUse/Github/InkMarkdown/.scratch/architecture-deepening-2026-09-07/evidence/20260907-1135-ticket-01/tests.xcresult`
  - scheme 列表：同目录 `scheme-list.log`
- App build：未执行（本票不要求）
- 安装启动：未执行
- 交互场景与观察：未执行
- 公共 interface / ADR 核对：
  - 快照：`20260907-1135-ticket-01/public-declarations-snapshot.txt`（114 行 `public`/`@_spi`/`@available` 命中，供后续 G-02 对照）
  - 相关入口文件（未改）：`Package.swift`、`.github/workflows/ci.yml`、`docs/current-status.md`、`Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift`、`Tests/InkMarkdownTests/ImageRenderingTests.swift`（含 `InkImageStoreTests`）、`Tests/InkMarkdownTests/SemanticCorpus/InkCorpusTableTracerTests.swift`、`Tests/InkMarkdownSwiftUITests/InkMarkdownRenderSessionTests.swift`、`Tests/InkMarkdownSwiftUITests/InkBlockPresentationContinuityTests.swift`、`Tests/InkMarkdownSwiftUITests/InkMarkdownAdapterWorkloadTests.swift`
  - ADR-001：验证后发布 manifest 仍为远程 pin；path overlay 未提交。
- 验收编号到上述证据的映射：
  - G-07：未切分支/worktree/reset/stash；未 commit/push/PR；无关改动无（开工干净）；临时 overlay 已恢复 → 满足
  - G-08：本文件记录 SHA、diff 范围、真实命令、scheme、destination、通过/失败/跳过数与 log/xcresult 路径 → 满足
- 未验证项、失败归因、阻塞的后续票：
  - 远程依赖解析 / CI：因本机无法访问 GitHub，未验证。
  - iOS 18.5 runtime 样本：未跑。
  - ExampleApp / consumer smoke / 交互：本票范围外。
  - 无产品失败；不阻塞 02/10/18。
- 仍需后续删除的过渡代码：无（本票无迁移代码）。

## Skills 使用说明

- 已读 `tdd`、`codebase-design`：本票为基线证据票，不新造测试、不改模块边界。
- 未发现独立的 “ticket 实施” Matt skill；按本地 Markdown tracker（`docs/agents/issue-tracker.md` / `triage-labels.md`）与本规划票执行。
- 未安装新 skill。
