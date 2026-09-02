# ADR-006: opt-in 图片真图渲染（默认保持 v1 占位契约）

## Status

Accepted

## Date

2026-07-28

Last updated: 2026-09-02

## Context

- [ADR-004](ADR-004-v1-image-and-strikethrough-contract.md) 将 v1 **默认**图片行为定为文本占位（`[🖼 …]`），不内置下载、缓存或附件布局；宿主可在块扩展或应用层自行处理。
- AI 流式对话等场景对 Markdown 图片展示有 **P1** 需求：宿主希望库内提供可组合的加载、缓存、业务策略与资源安全边界，而非每处重复实现 `NSTextAttachment` 与 URL 会话。
- `Image` 为 **行内** Markup 节点，纯块路由无法拦截；独占段「大图」需块级提升才能避免固定行高与附件布局冲突。
- 实现已落地（`Sources/InkMarkdown/Rendering/Image/`），本轮审查涉及的稳定性修复已完成；最低版本、完整人工交互和真机性能仍由 `current-status.md` 跟踪。本文记录架构决策，与 ADR-004 **默认契约向后兼容**。

## Decision

1. **默认行为不变**：`InkImageRendering.isEnabled` 默认为 `false`；关闭时 `renderImage` 仍输出 ADR-004 规定的文本占位，不发起网络或磁盘加载。
2. **opt-in 真图渲染**：宿主将 `isEnabled` 设为 `true` 后启用完整图片子系统，包括：
   - **行内通道**：`InkImageAttachment`（`NSTextAttachment` + 异步刷新布局）；
   - **块级通道**：独占图片段经 `InkImageBlockHandler` 提升为 `InkImageBlock`（`promotesToBlock` 默认 `true`）。
3. **加载与缓存**：通过 `InkImageLoading` 协议注入加载器；默认 `DefaultURLSessionImageLoader` 支持 http/https/file/data/asset/bundle 分流与 ImageIO 降采样。`InkImageStore` 只提供 URL 级内存缓存与 inflight 请求合并，不提供磁盘缓存；缓存语义包含 loader identity，最后一个订阅取消时须把取消传递到底层加载任务。
4. **业务策略默认开放**：图片真图渲染开启后，空 host allowlist 默认允许所有 host。域名 allowlist 与业务 URL 规则由宿主按需注入，库不把业务来源限制设为使用图片能力的前置条件。
5. **资源安全边界始终生效**：库仍校验支持的 scheme、HTTP 2xx、有效图片数据、重定向和响应大小。网络响应默认上限为可配置的 20 MiB；默认最多跟随 3 次重定向，宿主配置 host 策略时每次重定向都重新校验。`stripsQuery` 默认关闭以兼容签名或参数化 URL，`stripsFragment` 默认开启。
6. **失败与重试**：单次加载失败使用既有 fallback，不写入成功缓存，也不执行隐藏自动重试。宿主可通过重新渲染、重置或自定义 loader 发起重试。
7. **相对 URL**：宿主提供 `baseURL` 时解析相对图片 URL；未提供时返回明确的 unsupported/no-base-URL 结果，不猜测地址。
8. **交互**：`InkImagePreviewController` 供全屏预览；ExampleApp `ImageDemoViewController` 覆盖主要场景。
9. **与 ADR-004 的关系**：ADR-004 描述的是 **v1 默认对外契约**；本 ADR **Amend** 其「不提供下载、缓存及异步附件 API」在默认关闭时仍成立，开启 opt-in 后由库内子系统承担，宿主无需自行拼装底层附件管线。

## Alternatives Considered

### 保持 ADR-004 纯占位，真图永远由宿主实现

- Pros: v1 范围最小、测试面不变  
- Cons: 流式 AI 场景重复劳动；无法统一安全与缓存策略  
- Rejected: 与产品优先级与已实现代码方向不符

### 默认开启真图渲染

- Pros: 开箱即用  
- Cons: 破坏 ADR-004 默认契约；未配置 allowlist 时安全风险高  
- Rejected: 默认须保持占位

### 空 host allowlist 默认拒绝全部网络图片

- Pros: 未配置业务策略时保持 fail-closed
- Cons: 将宿主域名规则变成库能力的必填前置条件；普通 Markdown 图片即使是有效 HTTP(S) 资源也无法开箱渲染
- Rejected: 库负责资源安全边界，宿主负责业务来源限制

### 仅行内附件、不做块级提升

- Pros: 实现更简单  
- Cons: 独占大图在固定行高 TextKit 1 路径下布局与可读性差  
- Rejected: `promotesToBlock` 为推荐默认

## Consequences

- `current-status.md`、`spec/common-syntax.md`、FAQ 与 codebase 证据层须区分 **默认占位** 与 **opt-in 真图**，并链接本 ADR。
- ADR-004 状态标记为 **Amended**；历史正文保留，不 rewrite。
- 测试矩阵须补充 opt-in 图片契约（占位默认、开启后附件/块行为）；已完成的实现修复不回写为新的架构决策，剩余发布证据继续由 `current-status.md` 跟踪。
- 宿主文档须说明：未开启 `isEnabled` 时行为与 ADR-004 一致；开启后默认可加载满足资源安全边界的 HTTP(S) 图片。域名 allowlist 与自定义 loader 属于可选业务配置。
