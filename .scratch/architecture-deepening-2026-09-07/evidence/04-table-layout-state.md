# 04 验证证据

- 日期：2026-09-07
- Branch / HEAD：`feat/swiftUI` / `f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 工作树范围：
  - 扩展 `InkTablePresentation.swift`：`InkTablePresentation` / `InkTableLayoutSnapshot`
  - 扩展 `InkTablePresentationTests.swift`：布局 suite（3 tests）
- 依赖：local overlay（已恢复 remote pin）
- Toolchain / scheme / destination：Xcode 26.6 / `InkMarkdown-Package` / iPhone 17 Pro iOS 26.5
- 命令：`-only-testing:InkMarkdownTests/InkTablePresentationTests` + `InkTablePresentationLayoutTests`
- 自动测试：通过 8 / 失败 0（来源 5 + 布局 3）
- log/xcresult：`…/evidence/20260907-1200-ticket-04/`
- 验收：
  - **T-04**：wrap 恢复 reference 首列影响；对照短 reference 更窄
  - **T-05**：静态 replace 与流式 setHeaders+append 列宽差 < 0.5
  - **T-06**：wrap 宽窄恢复；scroll 自然列宽在 viewport 变化下稳定
  - **T-07**：短 append → `.appendRow`；长 append → `.fullRebuild`
- 后续消费者：05（静态视图）、06/07（流式）；生产视图尚未切换
- 过渡：stream 内 `widthsNeedExpand` 仍重复规则，07 删除
