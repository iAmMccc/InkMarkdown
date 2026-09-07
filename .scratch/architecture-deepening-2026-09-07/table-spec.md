# 表格呈现 module 详细规格

Status: ready-for-agent

Parent spec: [三方向规格](spec.md)。本文件是实现设计，不是实施授权。

## 1. 当前调用链与具体摩擦

1. `InkTableBlock.from` 从已解析 Markup 同时导出 raw 展示文本和 `InkPreparedMarkdownSource`；`makeView/updateExistingView` 把它们并行传给 `InkTableBlockView`。
2. `InkStreamTableView` 保存 headers/rows/referenceRows 和三组 prepared 数组；setHeaders、appendRow、layoutSubviews、rebuildAllRows 必须始终配对。
3. `InkTableRenderHelper.measureColumnContentWidths` 测量全表；流式 `widthsNeedExpand` 又实现一遍字体、inline render、boundingRect、padding、上限和容差。
4. 已修复的宿主 resize 与 filter 问题不应被当成仍存在的 bug；机会在于把修复所依赖的规则收进一个更深的 module。

### 源码入口

- [InkTableBlock.swift](../../Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift)：raw 初始化器、from、makeView、updateExistingView。
- [InkTableBlockView.swift](../../Sources/InkMarkdown/Rendering/Components/InkTableBlockView.swift)：apply、layoutSubviews、sizeThatFits、populateStack。
- [InkStreamTableView.swift](../../Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift)：setHeaders、appendRow、widthsNeedExpand、rebuildAllRows。
- [InkTableRenderHelper.swift](../../Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift)：makeRow、makeCellView、measureColumnContentWidths。
- [InkPreparedMarkdownSource.swift](../../Sources/InkMarkdown/Parser/InkPreparedMarkdownSource.swift)、[配置](../../Sources/InkMarkdown/Configuration/InkConfiguration.swift)。

## 2. 职责与内部形状

新增文件名称为本规格建议，尚不存在：

| 内部类型 | 所有者/内容 | 明确不拥有 |
| --- | --- | --- |
| `InkTableCellSource` | 一个单元格的原文与来源：raw 或 prepared；两个值绑定在一个值类型内 | UIView、全局配置 |
| `InkTablePresentation` | 已接纳的表头、实际行、测量参考行；来源预处理；当前列宽及失效规则 | 滚动手势、复制反馈、外部业务状态 |
| `InkTableLayoutSnapshot` | 一次一致的列宽模式、可呈现行、是否要求重建 | 可供调用方任意修改的缓存数组 |

建议放在 `Rendering/Components/InkTablePresentation.swift`，避免为三个小值类型各建一个文件。内部行内测量可以留在 implementation 内。`InkTableRenderHelper` 保留 UIKit 建行/约束/反馈代码；它消费完整 cell 值和布局结果，不再接收 optional prepared 平行数组。

概念形状（不是可直接粘贴的完整 Swift 声明）：

```swift
enum InkTableCellSource {
  case raw(String)
  case prepared(original: String, source: InkPreparedMarkdownSource)
}
// @MainActor；来源与宽度规则被 presentation 隐藏。
// 静态：replace 输入内容；流式：接纳一次表头、逐行 append。
// 两者均经 layout(contentWidth: ...) 获得一致的布局结果。
```

不得让 static/stream 调用方分别执行 prepare、measure、updateCache、convertRatios。其区别由输入形式表达，计算规则只有一份。

## 3. 来源与配置规则

| 输入 | 预处理时机 | resize/rebuild | 新内容或配置重接纳 |
| --- | --- | --- | --- |
| renderer/from 提供的 prepared cell | 不再运行 sourceFilter；Markup 是已准备输入 | 复用来源值 | prepared 仍不重过滤 |
| 公开 raw static cell | 一次 replace 接纳时，每个输入 cell 运行一次 sourceFilter | 不再重过滤 | 新 replace 是新的接纳，按其 configuration 处理一次 |
| 流式 raw header / reference cell | 首次 setHeaders 接纳时，每个输入 cell 一次 | 参考行持续参与测量，不显示 | 第二次 setHeaders 仍按现有契约忽略 |
| 流式 raw body cell | 每次有效 append 接纳时一次 | 复用该 cell 的 prepared 值 | 相同文本再次 append 是另一输入，不按文本去重 |

“每个输入 cell 一次”不等于全表只执行一次。相同内容同时作为 referenceRows 和实际 append 输入时，是两个不同的接纳事件。整个 Markdown 经顶层 renderer 输入则依旧只有一次顶层 filter，表格派生 cell 为零次。

raw static 当前可能在测量/建行中重复调用 filter；本规格把“内部重建不得重新消费原始输入”固定为目标契约，属于来源一致性深化。要用非幂等 filter 固化目标，不能只保护当前意外调用次数。显式重复 `updateExistingView` 可以重新接纳 raw static 输入；不保证跨公开重呈现调用的副作用次数去重。

`InkTableBlock.config` 和 `configuration` 均为现有可修改属性，不能擅自删除其中之一或强制同步。表格样式继续取 config，行内扩展/链接/渲染环境取 configuration；维持当前角色分工。prepared 原文的复制表示不被 filter 重新写入。

## 4. 列宽规则与状态迁移

- 所有宽度使用宿主可用宽度扣除 horizontalInset 后的内容宽；保留当前 `InkDisplayMetrics` 零宽兜底，不引入 UIScreen.main。
- 每列自然宽度来自 header、referenceRows 和已显示 rows 的已渲染富文本宽度；遵守原来的字体、padding、columnMaxWidthRatio 与列数量约束。
- wrap：按当前内容宽限制列宽，再转换比例；内容宽变化超过既有 0.5pt 容差时重新求值，能够宽→窄→宽恢复。
- scroll：列使用自然宽度；宿主宽变化只改 viewport，不把自然内容宽强行收缩。
- 追加行至少保留当前 O(cols) 的快速判定，不可无条件重渲染整个历史表。只有列宽需扩大或宿主宽变化才触发全量重建；不要求新增通用 attributed-string 缓存。
- referenceRows 在整个表格呈现期间参与每次列宽重算，永不加入可见行数、复制内容或 body 行列表。
- 保持 ragged rows、空 cell、对齐和 Markdown 分隔行过滤的现有行为；不在本轮定义 append-before-header 新能力。
- `onHeightChange`：接纳表头/有效追加行按现状通知；`layoutSubviews` 内的宽度重建不递归触发这个回调。保持静态 sizeThatFits 的宽度协商。

| 事件 | 内容状态 | 列宽状态 | 外部观察 |
| --- | --- | --- | --- |
| 首次 headers | 接纳 headers 和 reference | 计算 | header 显示，rowCount=0 |
| append 普通行 | 只追加一次 | 快速判定，必要时重建 | rowCount+1，复制包含该行 |
| append 分隔行 | 不变 | 不变 | 无新增行 |
| wrap resize | 来源不变 | 重算全部样本 | 窄时收缩，恢复时展开 |
| scroll resize | 来源不变 | 自然宽不变 | viewport 改变 |
| static apply | 用新输入替换 | 原布局失效 | 原手势不重复安装 |

## 5. 验收场景

| ID | 场景与可观察断言 |
| --- | --- |
| T-01 | 顶层非幂等 filter 将 `@@@user` 转为 `@@user`；makeView、复用、resize 后仍为 `@@user`，顶层计数始终 1。 |
| T-02 | 直接 raw static 输入每个 cell 在一次 replace 中仅处理一次；测量和建行不增加计数，后续显式 replace 可重新接纳。 |
| T-03 | headers=2 cells、reference=2 cells、append=2 cells 时计数为 6；resize、扩列重建不增加；第二次 setHeaders 不增加。 |
| T-04 | 仅 referenceRows 首列很长、实际 body 很短；reference 从未 append，仍在宽→窄→宽后影响首列宽。 |
| T-05 | 同一输入分别静态与逐行呈现，在相同配置/宽度下列宽与富文本语义一致；不要要求 UIView 对象 identity 相同。 |
| T-06 | wrap 的 744→375→744（或等价宽度）得到收缩与恢复；scroll 自然宽稳定、viewport 改变。 |
| T-07 | 追加短行仅新增该行；追加更长行触发必要重建；测量规则不在 stream view 再实现。 |
| T-08 | 不等长行、空 cell、对齐、富文本链接与已有 corpus 断言继续通过。 |
| T-09 | referenceRows 不显示、不计入 rowCount、不进入复制结果；复制仍为 header/body tab/newline 格式。 |
| T-10 | repeated layout 不重复过滤、不增加高度回调、不形成尺寸递归；静态复用不重复手势。 |
| T-11 | 生产 helper/视图内部没有 raw/prepared 平行数组协议；公开 String 用法保持。 |
| T-12 | SwiftUI 表格终态与 UIKit 两条表格路径通过方向验收；不新增公共类型/target。 |

## 6. 测试与迁移

沿用 [InkAuditSemanticRegressionTests](../../Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift)、[表格 corpus](../../Tests/InkMarkdownTests/SemanticCorpus/InkCorpusTableTracerTests.swift)、[Dynamic Type](../../Tests/InkMarkdownTests/AccessibilityAndDynamicTypeTests.swift)。新增 `InkTablePresentationTests.swift` 只覆盖真正集中后的输入/状态/输出；不能断言私有缓存容器。

依次执行 tickets 02–09。迁移期 helper 允许转发旧参数，但 ticket 08 必须删干净。03/04 的内部扩展必须被后续两个生产 adapter 使用；如果不能减少调用方知识，回到本规格修正，不能保留永久平行实现。

## 7. 明确不做

不统一 UIKit/SwiftUI 为第二渲染引擎；不新增表格编辑、排序、分页或自动重试；不改变最后一列 trailing 约束策略；不改 copy 的产品语义。新的内部 cell 类型不加入 CONTEXT.md，因为它是实现术语，不是新的领域概念。
