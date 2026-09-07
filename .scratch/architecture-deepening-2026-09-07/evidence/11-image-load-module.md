# 11 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 新增：`Sources/InkMarkdown/Rendering/Image/InkImagePresentationLoad.swift`
- 新增：`Tests/InkMarkdownTests/InkImagePresentationLoadTests.swift`
- Destination：`iPhone 17 Pro` / `id=10F638E2-84FB-42AE-9BAE-0E246F463E8D`
- Scheme：`InkMarkdown-Package`
- 测试：27 passed（PresentationLoad 9 + ControlledLoader fixture 4 + InkImageStoreTests）；local overlay 后已恢复 remote pin
- log / xcresult：`…/evidence/20260907-1245-ticket-11/`
- I-01：ready 无 pending、无二次 loader
- I-02：loading/queued 订阅一次、完成一次
- I-03：A→B 晚到抑制
- I-04：共享取消差异（fixture + Store）
- I-05：pending/completion 重入不写回旧句柄
- 未验证：ExampleApp 手工；远程 CI；iOS 15/18.5
