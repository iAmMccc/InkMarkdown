# 06 验证证据

- 日期：2026-09-07
- 流式 `InkStreamTableView` 删除三组 prepared 平行数组；`setHeaders`/`appendRow`/`rowCount`/copy 经 `InkTablePresentation`
- 测试：与 07 同跑 `20260907-1210-ticket-06-07`，22/22 通过
- 验收 T-03/T-04/T-09：audit+presentation 覆盖

# 07 验证证据

- 日期：2026-09-07
- 删除 stream 内 `widthsNeedExpand`/独立测量；resize 与 append 扩列均走 `presentation.layout`/`appendRow` 的 update
- 同证据目录 22/22
- 验收 T-04/T-05/T-06/T-07/T-10：layout suite + audit 宽度契约
