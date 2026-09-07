# 16 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 新增：`Tests/InkMarkdownTests/InkImagePresentationLifetimeTests.swift`
- 源码检索：Block/Attachment/Preview 不再 `store.resolve` / switch loading|queued；仅 `InkImagePresentationLoad` + Store 自身
- I-11/I-12：owner weak 可归零；共享 peer 保留 load；旧 bridge 已删
- 保留理由：Attachment MaterializationIdentity；Preview highResGeneration
- 测试：含于 `20260907-1335-ticket-13-17`（53 passed）
