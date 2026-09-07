# 03 验证证据

- 日期：2026-09-07
- Branch / HEAD：`feat/swiftUI` / `f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 工作树范围与相关 diff 摘要：
  - 新增 `Sources/InkMarkdown/Rendering/Components/InkTablePresentation.swift`（`InkTableCellSource` / `InkTablePreparedCell` / 临时 conversion）
  - 修改 `Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift`：新入口消费 `InkTablePreparedCell`；旧平行数组入口转发
  - 新增 `Tests/InkMarkdownTests/InkTablePresentationTests.swift`
  - 既有 audit 测试仍保留（票 02 改动）
- 依赖：local overlay（验证后已恢复 remote pin）
- Toolchain / scheme / destination：Xcode 26.6 / `InkMarkdown-Package` / iPhone 17 Pro (`10F638E2-…`, iOS 26.5)
- 实际命令：

```sh
xcodebuild test \
  -workspace .swiftpm/xcode/package.xcworkspace \
  -scheme InkMarkdown-Package \
  -destination 'platform=iOS Simulator,id=10F638E2-84FB-42AE-9BAE-0E246F463E8D' \
  -only-testing:InkMarkdownTests/InkTablePresentationTests \
  -only-testing:InkMarkdownTests/InkAuditSemanticRegressionTests \
  -resultBundlePath "$PWD/.scratch/architecture-deepening-2026-09-07/evidence/20260907-1152-ticket-03/tests.xcresult" \
  CODE_SIGNING_ALLOWED=NO
```

- 自动测试：通过 14 / 失败 0 / 跳过 0（2 suites：InkTablePresentation 5 + audit 9）
- log / xcresult：`…/evidence/20260907-1152-ticket-03/`
- 公共 interface：无新增 public 类型；`InkTableCellSource` 等为 internal
- 验收映射：
  - **T-01**：顶层 renderer 测试 filter 始终 1
  - **T-02**：raw 接纳一次后 measure/makeRow 不增；新 replace 再接纳
  - **T-03**：流式 6 cell 精确计数，resize 不增
  - **T-11（本票范围）**：cell 值绑定 original+prepared，无法表达平行数组错位；helper 新入口已消费完整 cell。视图内平行字段与旧 helper 签名留待 05–08 删除
- 过渡代码归属：
  - `InkTableCellSourceConversion.prepareCells/prepareRows` 与 helper 旧参数入口 → tickets 05–08
  - `InkTableBlock` / `InkTableBlockView` / `InkStreamTableView` 平行 prepared 数组 → 05–08
- 未验证：远程 resolve、交互、ExampleApp
