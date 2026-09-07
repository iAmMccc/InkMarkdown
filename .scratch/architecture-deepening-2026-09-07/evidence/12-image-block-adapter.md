# 12 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 修改：`Sources/InkMarkdown/Rendering/Image/InkImageBlock.swift`（委托 `InkImagePresentationLoad`；删除 `loadToken` / Store subscription 分支）
- 新增：`Tests/InkMarkdownTests/InkImageBlockPresentationAdapterTests.swift`
- Destination：`iPhone 17 Pro` / `id=10F638E2-84FB-42AE-9BAE-0E246F463E8D`
- Scheme：`InkMarkdown-Package`
- 测试：13 passed（Block adapter 3 + API 4 + PresentationLoad 6）；另 MermaidFailureFallback 5 passed（含 imageBlock prepareForReuse/failure）
- log：`…/evidence/20260907-1300-ticket-12/`、`…/20260907-1302-ticket-12-existing/`
- I-01/I-06：缓存 ready 不闪 placeholder 高度
- I-03/I-06：prepareForReuse 后 A 晚到不更新；B 正常完成
- pending/failure/tap/.button：failure 紧凑高度 + tap callback；API 兼容保留
- 责任：Store 观察/晚到抑制 → PresentationLoad；Block 保留尺寸/占位/fallback/tap
- 未验证：ExampleApp 手工；远程 CI；ImageRenderingTests 中部分 free-function imageBlock_* 选择器未命中（Swift Testing 命名），由 adapter suite 与 Mermaid 覆盖等价场景
