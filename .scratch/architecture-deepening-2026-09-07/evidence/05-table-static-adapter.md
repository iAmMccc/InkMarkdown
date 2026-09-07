# 05 验证证据

- 日期：2026-09-07
- Branch / HEAD：`feat/swiftUI` / `f71cc292…`
- 改动：`InkTableBlockView` 改持有 `InkTablePresentation`；populate/resize 消费 snapshot；新增 raw static filter 测试
- 测试：22 passed / 0 failed（Presentation×2 suites + audit + corpus table）
- log：`…/evidence/20260907-1205-ticket-05/`
- 验收：T-01/T-02/T-05/T-08/T-10 由上述 suite 覆盖；视图类型仍为 `InkTableBlockView`
- 过渡：`InkTableBlock` 仍存 prepared 平行字段供构造；stream 未迁移
