# 14 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 修改：`Sources/InkMarkdown/Rendering/Image/InkImagePresentationLoad.swift`（新增 `InkImagePresentationLoadAsync`）
- 测试：`InkImagePresentationLoadAsyncTests`（含于 53 passed 组）
- I-09：pre-cancel 不启动 loader；安装后 cancel 一次 resume；sync ready；failure→decodeFailed
- 未改 Preview（接线在票 15）
