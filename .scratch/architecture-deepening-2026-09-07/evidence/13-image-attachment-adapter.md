# 13 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 修改：`Sources/InkMarkdown/Rendering/Image/InkImageAttachment.swift`（惰性 PresentationLoad；保留 MaterializationIdentity / materializationGeneration）
- 新增：`Tests/InkMarkdownTests/InkImageAttachmentPresentationAdapterTests.swift`
- 测试：含于 `20260907-1335-ticket-13-17`（53 passed 组内）
- I-07：同 identity 不重启；display 变化重启；晚到 A 不覆盖 B
- I-08：纯构造/测量不启动 loader，未加载高度紧凑
- 保留：MaterializationIdentity、段落抬升、notification、renderedImage
