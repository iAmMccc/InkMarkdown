# 02 验证证据

- 日期：2026-09-07
- Branch / HEAD：`feat/swiftUI` / `f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 工作树范围与相关 diff 摘要：
  - 仅改 `Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift`（+85/−5）
  - 无生产源码改动；发布 manifest 验证后已恢复 remote pin
- 依赖：local overlay（同 01；GitHub 不可达）
- Toolchain / scheme / destination：
  - Xcode 26.6 / `InkMarkdown-Package`
  - `platform=iOS Simulator,id=10F638E2-84FB-42AE-9BAE-0E246F463E8D`（iPhone 17 Pro, iOS 26.5）
- 实际命令：

```sh
xcodebuild test \
  -workspace .swiftpm/xcode/package.xcworkspace \
  -scheme InkMarkdown-Package \
  -destination 'platform=iOS Simulator,id=10F638E2-84FB-42AE-9BAE-0E246F463E8D' \
  -only-testing:InkMarkdownTests/InkAuditSemanticRegressionTests \
  -resultBundlePath "$PWD/.scratch/architecture-deepening-2026-09-07/evidence/20260907-1145-ticket-02/tests.xcresult" \
  CODE_SIGNING_ALLOWED=NO
```

- 自动测试：通过 9 / 失败 0 / 跳过 0（suite「项目审核 F04-F09 关键路径回归」）
- log / xcresult：
  - `/Users/shizihan/DailyUse/Github/InkMarkdown/.scratch/architecture-deepening-2026-09-07/evidence/20260907-1145-ticket-02/test.log`
  - `/Users/shizihan/DailyUse/Github/InkMarkdown/.scratch/architecture-deepening-2026-09-07/evidence/20260907-1145-ticket-02/tests.xcresult`
- App build / 安装启动 / 交互：未执行（本票不要求）
- 公共 interface / ADR 核对：无公开声明变更
- 验收编号到上述证据的映射：
  - **T-01**：顶层 prepared 测试追加 resize 后仍 `filterCallCount == 1` 且文本为 `@@user`
  - **T-03**：流式 2+2+2 cell 精确计数 6；resize 与第二次 `setHeaders` 不增加
  - **T-04**：长内容仅在 referenceRows；`rowCount==1` 且不可见；宽→窄→宽后首列宽仍大于无长 reference 对照
- 判别点（故意遗漏 reference 应失败，未提交破坏版）：
  - 若 `layoutSubviews`/`setHeaders` 测量只用 body `rows` 而丢掉 `referenceRows`，`streamTable_referenceRowsAffectColumnWidthWithoutDisplay` 中 `referenced.wide > control.wide` 与 `referenced.restored > control.restored` 会失败
  - 若重建再次 `sourcePreparedForParsing`，精确计数 6 会在 resize 后失败
- 未验证项：远程依赖解析、iOS 18.5 样本、ExampleApp 交互
- 仍需后续删除的过渡代码：无
- code-review（本票 diff）：无行为缺陷；测试只观察文本/首列几何/`rowCount`，未访问 private prepared 数组
