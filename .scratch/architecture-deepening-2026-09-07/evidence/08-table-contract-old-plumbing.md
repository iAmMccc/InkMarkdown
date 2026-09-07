# 08 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292…`
- 删除：helper 平行数组重载、`InkTableCellSourceConversion`、stream/static 内 prepared 平行所有权
- `InkTableBlock` 内部改为 `headerSources`/`rowSources`；公开 `headers`/`rows` String 字段保留
- 测试：28 passed / 0 failed（含 AccessibilityAndDynamicTypeTests）
- log：`…/evidence/20260907-1220-ticket-08/`
- 旧符号检索：`preparedHeaders|preparedRows|preparedTexts|InkTableCellSourceConversion|widthsNeedExpand` → Sources/Tests 无命中
- G-02：排序后 public 声明仅 `InkTableBlock` extension 行号漂移；无新增/删除表格相关 public 类型
- G-09：来源接纳归 Presentation；列宽失效归 Presentation；helper 只建行
- `git diff --check`：本票表格文件无 whitespace 错误
