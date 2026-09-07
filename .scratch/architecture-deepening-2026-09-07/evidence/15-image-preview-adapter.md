# 15 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 修改：`Sources/InkMarkdown/Rendering/Image/InkImagePreviewController.swift`（`loadFromStore`→PresentationLoadAsync；删除 `InkPreviewStoreLoadBridge`）
- 新增：`Tests/InkMarkdownTests/InkImagePreviewLoadTests.swift`
- I-10：bypassStore true/false；dismiss 后晚到不崩溃
- 保留：highResTask / highResGeneration、maxPreviewPixel、失败保底降采样图
