# 25 验证证据

- 日期：2026-09-07
- HEAD：`f71cc292…`
- Coordinator 已删除流式 token/observer/bind 私有字段与 reconcileStreaming 平行实现
- Session 兼容转发 API 仍保留供迁移/测试；grant API 为生产路径
- 源码检索：Bridge 内无第二套 streaming resolve 接线
