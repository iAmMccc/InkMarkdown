# 03: 收口复杂表格单元格与复制契约

**What to build:** 让复杂 GFM 表格单元格按 parser 产生的结构稳定呈现，并提供可验证的横向滚动和复制入口。用户应能看到正确的表头、行、对齐、rich inline 与 escaped pipe；空单元格或不齐行不得崩溃、越界或静默错位。

**Blocked by:** 01 / 建立 canonical corpus，并打通 reference link tracer。

**Status:** done (2026-09-02, 本地候选：InkCorpusTableTracerTests 全绿；escaped pipe 记录为 format() 不再转义的实际契约；ExampleApp 表格样例含 rich cell/链接/不齐行)

- [x] 表头、数据行与 alignments 按 parser 结构稳定传递到真实表格 Block。
- [x] 单元格中的强调、粗体、行内代码与链接组合保留各自 inline 语义。
- [x] escaped pipe 保持为单元格内容，不被误拆为新列。
- [x] 空单元格与不齐行遵守已记录的表格契约，不崩溃、不越界、不产生错误列宽。
- [x] 窄宽表格保留既有横向滚动与 wrap/scroll 配置行为。
- [x] ExampleApp 当前主导航提供复杂表格和长按复制入口，不恢复旧顶层组件 Pager。
- [x] 自动化只覆盖 parser 结构、inline semantics、alignment、核心列宽输入和复制数据关键路径；UI、横滑、长按和视觉结果只做 ExampleApp 手工验收。
- [x] 不新增 streaming 增量网格引擎；未完成阶段保持 pipe 文本，finish 后仍可 promotion 为真实表格。
