# 十三、布局测量契约（Host-Width Intrinsic Growth）

> **适用版本：v0.0.2 及后续版本**
> **相关**：[SwiftUI 排坑指南](09-swiftui-uiviewrepresentable-gotchas.md) | [Block Presentation Continuity](11-block-presentation-continuity.md) | [ADR-008](../decisions/ADR-008-swiftui-adapter-architecture.md)

流式与静态呈现的布局压力**不是**约束 DSL 语法问题，而是「宽度已知 → 测量 → 节流失效 → 宿主抬高」契约。本文是该契约的 SSOT；实现以 `InkMarkdownContainerView` / `InkStreamRenderer` 为准。

## 1. 四层模型

| 层 | 职责 | 关键实现 |
| --- | --- | --- |
| 测量 | 唯一入口 `measureContent`；外层 Frame 容器；表格等复杂岛内部 Auto Layout + `systemLayoutSizeFitting` | `InkMarkdownContainerView` |
| 失效 | 内容真变才 `invalidateIntrinsicContentSize` / 高度回调；禁止在 `layoutSubviews` 内 invalidate | Container、Image/Thought reserved-height |
| 宿主宽度 | 首轮 layout 前可提供 `preferredMeasurementWidth`，避免「先矮后高」 | `preferredMeasurementWidth` / `.preferredMeasurementWidth(_:)` |
| 列表宿主 | Chat cell / `UICollectionView` 自管理高度门闩；流式期慎用自动 AL self-sizing | ExampleApp SSE cell、宿主文档 |

**不引入** SnapKit / Texture 等布局运行时进库；ExampleApp 也不得暗示库依赖 SnapKit。

## 2. 宽度解析顺序

固有尺寸路径（容器 `intrinsicContentSize`）：

1. 自身已布局宽（`bounds.width > 0`）
2. 宿主 `preferredMeasurementWidth`（`> 0`）
3. 父视图宽（`superview.bounds.width > 0`，估算输入，不等于已确认的宿主内容宽）
4. `window.bounds.width`
5. iOS 15 且未入窗时：前台 `UIWindowScene.screen` 宽

容器 `sizeThatFits(_:)` 若 proposal 宽 `> 0`，直接用 proposal，不走上述 fallback。父视图宽只用于固有尺寸估算，不覆盖正宽度 proposal，也不覆盖宿主提供的 `preferredMeasurementWidth`。

块级 `sizeThatFits`（Code / Table / Thematic / Attributed / Thought）经 `InkDisplayMetrics.resolvedMeasurementWidth`：

1. proposal 宽 `> 0`
2. `bounds.width` `> 0`
3. 否则返回 `UIView.noIntrinsicMetric`（**禁止**硬编码 320）

表格 `InkDisplayMetrics.availableWidth`：bounds → window → Scene；默认 fallback 为 **0**（不再猜 320）。window / Scene 宽只是估算输入，不能当作已确认的宿主列宽。内容接纳与列布局分离：未知宽（`contentWidth == 0`）只保存表头和行，不生成临时列宽或等分比例；真实宽到达后再计算列布局，结果与直接按该宽初始化一致。未知宽阶段流式表格不触发 `onHeightChange`。

公开 API：

```swift
InkStreamMarkdownView(session: session)
  .preferredMeasurementWidth(bubbleContentWidth)

// 或 init 参数
InkMarkdownView(markdown, preferredMeasurementWidth: bubbleContentWidth)
```

环境键：`EnvironmentValues.inkPreferredMeasurementWidth`（修饰符写入）。

## 3. 高度与缓存门闩

| 场景 | 阈值 / 规则 |
| --- | --- |
| Continuity 宽度协商 | `\|Δw\| > 0.1` 才换规范宽并清空测量缓存 |
| 流式 `InkStreamRenderer.onDisplayUpdate` | 高度相对 `lastContentHeight` 变化 `> 1` pt 才通知；`textContainer.size` 为 0 时回退 `bounds.width`；两者均为 0 时置 `needsDeferredHeightMeasurement`，宽度就绪后由空闲帧（`totalLength <= displayIndex`）或 `bindTextView` 补测一次并消费标记（无论是否跨过门闩） |
| Image / Thought reserved height | 异步抬高只更新对应 lineage 的 measurement slot，再 ICS + `onContinuityHeightChanged` |
| Measurement key | `(lineageID, slotRevision, constrainedWidth, environmentSignature)`，见 [11 §11.2](11-block-presentation-continuity.md) |

## 4. 硬性禁令

1. **禁止**在 `layoutSubviews` 内调用 `invalidateIntrinsicContentSize()`。
2. **禁止**用 `GeometryReader` 把宽度写回 `@State` 再驱动 Representable（见 [09 §2](09-swiftui-uiviewrepresentable-gotchas.md)）。
3. **禁止**每 chunk 改 `@Published` / 重建整棵 `InkStreamMarkdownView`；高度走 DisplayLink / `onDisplayUpdate`。
4. 流式气泡列表：**慎用** `UICollectionView.SelfSizingInvalidation.enabledIncludingConstraints`（cell 内任意 AL 变化都会自动 ICS，易 thrash）。优先 `.enabled` + 库高度回调，或显式 item size。

## 5. 宿主清单（Chat / Table）

1. 用约束或布局给出**有限列宽**（不要让空流式视图把气泡压成最小宽）。
2. 在已知终态内容宽时设置 `preferredMeasurementWidth`（列宽减去 bubble inset）。
3. 订阅 `session.onDisplayUpdate` / continuity 高度回调 → `invalidateIntrinsicContentSize` / `beginUpdates`/`endUpdates` 或 collection invalidation。
4. 自定义 block 必须实现确定性 `sizeThatFits` / `intrinsicContentSize`（见 [FAQ §18](06-faq.md)）。

## 6. 与 Apple / 同赛道实践的对齐

- Apple：`invalidateIntrinsicContentSize` 仅在固有尺寸因素变化时调用；`systemLayoutSizeFitting` 用于 AL 岛测量；多行文本需宽度边界（`preferredMaxLayoutWidth` 同类问题）。
- MarkdownDisplayView：`preferredMeasurementWidth`、`onHeightChange`、按宽缓存 intrinsic、高度门闩、约束优先级 999 让宿主。
- MarkdownView：流式 `setContent` 帧率合并（本库用 DisplayLink + 高度门闩）。

## 7. 已知后续

- ~~部分 block 在 `bounds.width == 0` 时仍有硬编码 `320` fallback~~：**已收敛**。Code / Table / Thematic / Attributed / Thought 统一经 `InkDisplayMetrics.resolvedMeasurementWidth`；未知宽返回 `noIntrinsicMetric`。`availableWidth` 默认 fallback 为 0。宿主终态宽仍由容器 `preferredMeasurementWidth` / 正宽度 `sizeThatFits` 下传。
- Mermaid 离屏 WKWebView 初始 `320×480` 视口为渲染器内部 viewport，**不是** Markdown 列宽契约，单独演进。
- TextKit 2 迁移是独立演进项，不替代本契约。
