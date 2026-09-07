# 18 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 修改：`Tests/InkMarkdownSwiftUITests/InkBlockPresentationContinuityTests.swift`、`InkMarkdownRenderSessionTests.swift`
- 未改生产 Coordinator 生命周期
- Destination：`iPhone 17 Pro` / `id=10F638E2-84FB-42AE-9BAE-0E246F463E8D`
- 测试：21 passed（Continuity + Session）
- log：`…/evidence/20260907-1400-ticket-18/`
- S-05：旧 A 二次 teardown 后 B 继续正文
- S-07：环境补充 reconcile 排队遇 cancel 不复活
- S-02/S-03/S-04：既有 handoff 段保留
- S-12：deferred publish 前 cancel/reset 作废 @Published
- local overlay 后已恢复 remote pin
