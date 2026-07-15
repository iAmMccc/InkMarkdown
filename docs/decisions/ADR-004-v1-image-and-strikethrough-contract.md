# ADR-004: v1 图片与删除线行为契约

## Status

Accepted

## Date

2026-07-15

## Context

- 图片：当前 `renderImage` 输出文本占位（如带 🖼 的方括号串），不下载、不缓存、不做附件布局。
- 删除线：GFM `Strikethrough` 未在行内 switch 中单独施加删除线样式；内容可通过 default 子树保留。富文本通道里 `strikethroughStyle` 仅用于 thematic break 占位绘制，不是 GFM 删除线语义。
- 完整图片管线与删除线样式会扩大 v1 范围与测试面。

## Decision

1. **v1 图片**：仅文本占位；**不**提供下载/缓存/异步附件 API。宿主若需要真图，在块扩展或应用层处理。
2. **v1 删除线**：不承诺 GFM 删除线视觉样式；规范与状态文档写清「内容可保留、样式未保证」。
3. 二者**不阻塞 v1.0**；若日后实现，需补 `spec/` + 语义测试并写 superseding ADR。

## Alternatives Considered

### v1 必须实现删除线样式与图片回调

- Pros: 功能更完整  
- Cons: 拉高发布门槛；图片牵涉线程与缓存策略  
- Rejected: 作为 v1 必选项

### 静默「半支持」不写契约

- Pros: 少写文档  
- Cons: 宿主误判能力  
- Rejected

## Consequences

- `current-status.md` 已知限制表保持有效，作为对外契约摘要。
- 测试矩阵优先 CommonMark 已支持元素，不为未承诺能力写假绿测。
