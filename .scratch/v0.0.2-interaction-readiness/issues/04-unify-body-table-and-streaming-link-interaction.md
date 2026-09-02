# 04: 统一正文、表格与流式链接交互

**What to build:** 让正文、表格单元格、SwiftUI streaming text 与 finish/promotion 后 Block 使用同一个 `linkTapHandler` 契约。用户在消息生成中和完成后点击同一链接时，应得到一致的宿主回调或系统默认行为。

**Blocked by:** 01 / 建立 canonical corpus，并打通 reference link tracer；03 / 收口复杂表格单元格与复制契约。

**Status:** done (2026-09-02, 本地候选：`InkStreamingTextView` + Coordinator reconcile 接线；InkLinkInteractionContractTests 全绿；流式 mock 分片含正文/引用链接)

- [x] handler 返回 `true` 时由宿主处理并阻止系统默认行为。
- [x] handler 未配置或返回 `false` 时保留系统默认行为。
- [x] 正文与表格单元格使用相同回调契约。
- [x] SwiftUI streaming 未 finish 阶段立即连接当前 configuration 的 handler。
- [x] finish 与 promotion 后保持同一 handler 语义，不保留陈旧 callback。
- [x] configuration 更新后的新 handler 生效，旧 handler 不再收到点击。
- [x] ExampleApp 当前主导航包含正文、表格与 streaming 链接手工入口。
- [x] 自动化只覆盖 destination、handler true/false、configuration 更新与 promotion 关键链路；禁止 UIApplication/Safari UI 测试、UI automation 和重复入口测试。

