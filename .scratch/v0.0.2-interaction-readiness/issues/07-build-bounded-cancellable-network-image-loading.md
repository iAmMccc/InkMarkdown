# 07: 建立有界、可取消的网络图片加载

**What to build:** 让默认网络图片 loader 在真实使用中具备可配置资源预算、正确重定向、订阅取消、缓存隔离和明确失败行为。有效图片正常渲染；异常响应不会无限占用内存、绕过策略、污染缓存或在所有订阅消失后继续浪费资源。

**Blocked by:** 06 / 开放图片业务策略并闭环相对 URL。

**Status:** ready-for-agent

- [ ] 新增可配置网络响应大小上限，默认 20 MiB；超限响应在完整载入和解码前安全失败。
- [ ] HTTP(S) 只接受 2xx 与有效图片数据；非 2xx、非图片和解码失败使用既有 fallback。
- [ ] 默认最多跟随 3 次重定向；配置 host 业务策略时，每次重定向重新校验。
- [ ] 最后一个订阅取消时，取消传播到底层网络任务；仍有订阅时共享 inflight 请求继续运行。
- [ ] 取消或陈旧请求结果不能覆盖新 source，也不能回调已取消订阅者。
- [ ] cache identity 包含 source、display parameters 与 loader semantic identity；更换 loader 后不得复用旧结果。
- [ ] 失败结果不写入成功缓存；库不执行隐藏自动重试。
- [ ] 保持内存 cache、inflight 合并、并发与等待队列能力；不新增磁盘缓存。
- [ ] 自动化只覆盖响应预算、2xx/图片校验、redirect、最后订阅取消、inflight 合并、loader identity、失败与不缓存失败关键路径；禁止真实网络单元测试排列和 UI 测试。

