# 验证证据目录

已开始实施验证。当前进度见 [cursor-progress.md](./cursor-progress.md)。

| 票 | 证据 |
| --- | --- |
| 01 | [01-capture-current-baseline.md](./01-capture-current-baseline.md)（运行产物目录 `20260907-1135-ticket-01/`） |
| 02 | [02-table-source-regression.md](./02-table-source-regression.md)（`20260907-1145-ticket-02/`） |
| 03 | [03-table-cell-source.md](./03-table-cell-source.md)（`20260907-1152-ticket-03/`） |
| 04 | [04-table-layout-state.md](./04-table-layout-state.md)（`20260907-1200-ticket-04/`） |
| 05 | [05-table-static-adapter.md](./05-table-static-adapter.md)（`20260907-1205-ticket-05/`） |
| 06 | [06-table-stream-input.md](./06-table-stream-input.md)（与 07 同跑 `20260907-1210-ticket-06-07/`） |
| 07 | [07-table-stream-layout.md](./07-table-stream-layout.md) |
| 08 | [08-table-contract-old-plumbing.md](./08-table-contract-old-plumbing.md)（`20260907-1220-ticket-08/`） |
| 09 | [09-table-acceptance.md](./09-table-acceptance.md)（`20260907-1225-ticket-09/`） |

实施后每票按其 Verification 指定文件名写记录。日志与 xcresult 可存独立本地目录，并在记录中给可访问路径；不要提交凭证或大体积构建缓存。

先看 [执行指南的证据模板](../execution-guide.md)。文件存在不等于 ticket 已完成；必须同时核对 Acceptance、候选 SHA+diff 和实际输出。
