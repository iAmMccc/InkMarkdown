# 06: 开放图片业务策略并闭环相对 URL

**What to build:** 保持图片真图渲染 opt-in，同时让开启后的有效 HTTP(S) 图片无需配置 host allowlist 即可加载。宿主仍可注入图片业务策略；提供 `baseURL` 时相对图片地址可确定解析，未提供时明确失败。

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] `InkImageRendering.isEnabled` 继续默认关闭，关闭时保持文本占位且不加载资源。
- [ ] 开启图片后，空 host allowlist 默认允许所有有效 HTTP(S) host。
- [ ] 宿主显式配置 allowlist 时，非允许 host 继续被拒绝。
- [ ] query 默认保留，fragment 默认剥离；请求 URL 与 canonical cache identity 使用一致规则。
- [ ] 提供 `baseURL` 时，相对图片 source 解析为确定请求 URL。
- [ ] 未提供 `baseURL` 时，相对图片 source 返回明确的 unsupported/no-base-URL 结果，不猜测来源。
- [ ] 公开默认值、失败语义和业务策略边界具有完整中文文档注释，并符合 ADR-006。
- [ ] 自动化只覆盖默认 host 开放、可选 allowlist、query/fragment 与 relative URL 关键路径；禁止 UI 测试和 host/URL 非核心排列矩阵。

