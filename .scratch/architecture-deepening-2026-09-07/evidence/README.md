# 验证证据目录

当前只有规格检查证据；尚未执行任何实现 ticket 的测试或 App 验收。

实施后每票按其 Verification 指定文件名写记录。日志与 xcresult 可存独立本地目录，并在记录中给可访问路径；不要提交凭证或大体积构建缓存。

先看 [执行指南的证据模板](../execution-guide.md)。文件存在不等于 ticket 已完成；必须同时核对 Acceptance、候选 SHA+diff 和实际输出。
