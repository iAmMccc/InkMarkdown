# 05: 完成零宽度到 Split View 的响应式布局

**What to build:** 让 SwiftUI adapter 在初始宽度为零、首次获得有效宽度、设备旋转和 iPad Split View 连续调整时稳定测量与呈现。adapter 不猜测屏幕宽度；宽度建立后必须显示内容，并保留同一呈现周期内的块呈现状态。

**Blocked by:** 01 / 建立 canonical corpus，并打通 reference link tracer。

**Status:** done (2026-09-02, 本地候选：InkResponsiveMeasurementContractTests 全绿；旋转/Split View 视觉走查归 ticket 08 手工验收)

- [x] 初始宽度为零时不使用屏幕宽度或固定常量兜底，也不产生错误的永久零高度缓存。
- [x] 宿主首次提供有效宽度后触发 reconcile，并得到稳定 intrinsic size。
- [x] 相同宽度可复用有效测量；宽度变化只失效受影响的 measurement。
- [x] 旋转和 Split View 连续宽度变化不产生裁切、布局循环、旧宽度内容或状态丢失。
- [x] Thought 折叠态和其他块呈现状态在同一呈现周期内保持不变。
- [x] 表格、代码块、长链接与图片等宽度敏感内容能在 ExampleApp 的窄宽与全宽入口中手工检查。
- [x] 自动化只覆盖零宽度、首次有效宽度、同宽 cache、宽度变化重测与状态保留关键路径；旋转、Split View 和视觉结果不得新增 UI 测试。
- [x] 本 ticket 不改变 iOS/iPadOS 14+ 产品目标，也不宣称完成 iOS/iPadOS 14–15 runtime 验收。
