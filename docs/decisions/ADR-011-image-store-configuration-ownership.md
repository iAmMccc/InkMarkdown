# 图片 Store 配置由资源所有者决定

Status: Superseded by [ADR-012](ADR-012-pluggable-image-management.md)（2026-09-07）。下文保留历史决策，不再描述当前后端接口。

图片缓存、并发和排队预算属于 Store 的资源生命周期。显式注入 Store 时，以其所有者配置为准；默认渲染路径按完整 `storeConfiguration` 选择并持有对应 Store。Block、行内 attachment 和预览不能在每次渲染时暗中重配共享 Store，也不能以“值是否等于默认值”推断调用方意图。

默认 Store 注册表只保留弱引用，实际渲染宿主持有 Store；释放宿主后不会因历史配置键永久保留缓存。若所有者显式修改默认实例的预算，后续按旧配置查找必须重新创建匹配实例。图片预览的 `bypassStore=false` 使用注入的 Store，未注入时由预览控制器持有默认 Store。

维护者可显式调用 `updateConfiguration` 更新已有 Store。提高并发上限立即协调排队请求；降低并发不取消已运行任务。缩小排队上限保留已接受请求并继续 FIFO 调度，新请求超过新上限时拒绝，不静默丢失已接受请求。

该决策补充 ADR-006 的内存缓存与请求合并规则。默认图片仍关闭，显式开启后的业务来源策略及资源安全边界不变。公开 API 保持源兼容，但混用注入 Store 配置与 `rendering.storeConfiguration` 的宿主必须将预算写到注入 Store；不再依赖 block 的调用顺序覆盖全局预算。否决逐字段比较默认值的合并方式，因为它无法表达恢复默认值，也无法隔离多个宿主。
