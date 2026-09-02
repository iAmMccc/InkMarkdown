# 02: 修正 loose list 与混合嵌套语义

**What to build:** 让 loose list 续段、混合有序/无序嵌套和列表内引用在 UIKit rendering engine 中保持正确归属与样式，并通过共享语义矩阵证明 attributed、block fallback、streaming finish 与 SwiftUI adapter 得到一致结果。

**Blocked by:** 01 / 建立 canonical corpus，并打通 reference link tracer。

**Status:** done (2026-09-02, 本地候选：`renderList` 续段落落几何 + 列表内引用缩进修复；InkCorpusListTracerTests 全绿)

- [x] 同一列表项的续段继承累计列表缩进、悬挂缩进和固定行高。
- [x] 有序列表、无序列表与更深层子列表按层级累计缩进，marker 与节点归属正确。
- [x] 列表项内引用保持属于对应列表项，不被错误提升到根级。
- [x] 既有任务列表、起始序号与简单嵌套行为不回退。
- [x] canonical corpus 只加入 loose-list 续段、混合嵌套和列表内引用关键 fixture，不扩张为层级与 marker 的排列矩阵。
- [x] 自动化断言 paragraph style、累计 indent、文本与结构归属；禁止 UI 测试、视觉 frame 断言和内部递归实现断言。
- [x] 聚焦测试通过，且 finish 语义投影与静态结果一致。
