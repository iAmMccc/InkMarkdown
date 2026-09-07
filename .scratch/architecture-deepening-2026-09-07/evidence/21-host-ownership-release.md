# 21 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292…`
- Host 实现 waiting/committed/releasing：apply 失败保留 waiting；teardown 最后 wake waiter
- 双 host 测试：等待环境不污染、接管后 dark 生效、旧 A 二次 teardown 无副作用、等待者退出不解绑
- 验证并入 `20260907-1445-ticket-20-26/`
