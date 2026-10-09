# ADR-004: v1 图片与删除线行为契约

> 标题中的 “v1” 保留原始决策语境；当前发布计划以 `0.0.1` / `0.0.2` 为准。

## Status

Amended — 默认图片占位契约仍有效；opt-in 真图由 [ADR-006](ADR-006-opt-in-image-rendering.md) 规定；删除线契约于 2026-08-17 按当前 implementation 更新。

## Date

2026-07-15

## Context

原始决策将图片和删除线都视为未承诺能力：图片只输出文本占位，删除线只保留文本而不写入视觉属性。

此后 implementation 已变化：

- 图片默认仍输出占位，但 `InkImageRendering.isEnabled` 可启用真图附件与 `InkImageBlock`；具体资源、缓存和安全边界见 ADR-006。
- `InkAttributedRenderer` 现已为文本与行内代码的 `Strikethrough` context 写入 `.strikethroughStyle`。但自定义 `inlineSyntaxes` 命中时目前不继承删除线属性，且图片叶子节点不承诺删除线视觉效果，均属于已知组合语义限制。

文档必须区分默认行为、opt-in 行为与这一组合限制，不能继续把已实现的删除线样式写成缺失能力。

## Decision

1. **图片默认行为**：保持文本占位；不会因普通 Markdown 图片自动发起网络加载。
2. **图片 opt-in 行为**：由 ADR-006 定义。启用后可生成 `InkImageAttachment` 或 `InkImageBlock`，并遵循其资源与安全契约。
3. **删除线行为**：GFM `Strikethrough` 的文本与行内代码叶子节点生成 `.strikethroughStyle`，是当前 UIKit rendering engine 的语义契约。
4. **删除线组合限制**：自定义 `inlineSyntaxes` 命中时不保证继承删除线；图片叶子节点也不保证删除线视觉效果。两项限制必须在语义规范、测试和公开状态中可见。若未来改变，需补充契约测试。

## Consequences

- README、状态文档与 swift-markdown 参考应将删除线列为已支持的样式，而非“仅保留文本”。
- 默认图片占位与 opt-in 真图必须同时被测试，避免把“默认关闭”误解为“不支持图片”。
- SwiftUI adapter 的完整语义对齐范围包含上述图片与删除线行为及其已知限制。
- 后续新增图片或删除线行为时，更新 [语义规范](../spec/README.md)、当前状态和测试，而不是绕开既有契约。

## Historical alternatives

### 默认加载所有图片

- 优点：最直观的视觉结果。
- 缺点：把网络、缓存和安全责任隐式带入普通 Markdown 渲染。
- 结论：拒绝；默认占位、显式 opt-in。

### 静默保留删除线文本而不记录限制

- 优点：短期实现成本低。
- 缺点：宿主无法判断视觉语义是否完整。
- 结论：拒绝；现已明确支持删除线，并记录 custom inline syntax 的组合限制。
