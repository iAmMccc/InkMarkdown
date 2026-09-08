# InkMarkdown 布局测量契约审查

- 审查日期：2026-09-08
- Verdict：**Request changes → Fixed**。F1–F3 已按建议落地（代码 + 契约测试）；Simulator 交互与远程 CI 仍待宿主验收。
- 问题数量：2 项 Major，1 项 Minor
- 审查方式：基于本地 diff、相关文件内容、调用链与测试断言进行静态审查。
- 状态：已按审查建议修复（代码+契约测试）；Simulator 交互/远程 CI 仍待宿主验收。

## 1. 范围与验收依据

本次审查覆盖 Host-Width Intrinsic Growth Contract 相关改动：容器 preferred 路径、SwiftUI 入口与环境注入、`InkDisplayMetrics`、块级测量、表格零宽行为、`InkStreamRenderer` 高度门闩、ExampleApp SnapKit 清理，以及[布局测量契约](../contributor-guide/13-layout-measurement-contract.md) §2/§7。

验收依据如下：

1. 宿主能够在首轮 layout 前提供 `preferredMeasurementWidth`，避免 chat cell 首测偏矮后再次抬高。
2. 容器保持唯一测量入口，不在 `layoutSubviews` 调用栈内触发 `invalidateIntrinsicContentSize`。
3. 块级 `sizeThatFits` 在宽度未知时返回 `UIView.noIntrinsicMetric`，不以硬编码 320 代替宿主列宽。
4. 流式高度通知保留门闩，`textContainer` 零宽时不静默丢失待通知更新。
5. ExampleApp 移除未使用的 SnapKit，文档与实现一致。
6. `preferredMeasurementWidth` 仅停留在容器和 SwiftUI 入口，不扩展为每个 block 的公共属性。

本次不审查无关 image backend / Kingfisher 改动，不建议引入 SnapKit 或 Texture。下文行号为审查时工作树位置；文件后续变化时应以符号为准。

## 2. Findings

### F1 — Major：父视图宽度抢先覆盖 preferred，首测仍可能偏矮

**位置**：[InkMarkdownContainerView.swift](../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift)，`intrinsicMeasurementWidth`（约第 389 行）、`resolvedWidth`、`effectiveMeasureWidth`。

**触发条件**：容器自身 `bounds.width == 0`，父视图宽度为 390pt，宿主已经明确提供 `preferredMeasurementWidth == 280`。

**问题与证据**：`resolvedWidth` 在自身 bounds 为零时直接使用 `superview.bounds.width`。随后 `intrinsicMeasurementWidth` 将该值作为 `contentWidth` 传入 resolver，而 resolver 的 `contentWidth` 优先级高于 preferred。因此上述输入会按 390pt 测量，而不是宿主提供的 280pt。

**为何重要**：父视图宽度不一定等于扣除 inset 后的 Markdown 内容宽度。对于会换行的长文本，按较宽输入得到的首测高度可能偏低，实际布局到 280pt 后仍需再次抬高，削弱验收目标 1。文档 §2 与实现顺序一致，但将父视图宽度等同于“已布局内容宽”的规则本身存在问题。

**建议修法**：区分自身已布局宽度和父级估算宽度。固有尺寸路径建议依次采用自身正 bounds、正 preferred、父视图宽、window、适用版本的 Scene fallback；同步 `effectiveMeasureWidth` 与文档。正宽度 `sizeThatFits` proposal 仍保持优先，不向 block 增加 preferred 属性。

**回归用例**：将零 bounds 容器挂到 390pt 父视图，提供 preferred 280，并渲染足够长的正文。断言首轮 intrinsic 高度与显式 280pt proposal 测量一致；再验证自身实际 bounds 就绪后正确接管宽度。

**修复状态**：已修复。`intrinsicMeasurementWidth` 将 `laidOutContentWidth` 与 `parentEstimatedWidth` 分开，经 `InkIntrinsicMeasurementWidthResolver.resolve` 使 preferred 优先于父级估算；`effectiveMeasureWidth` 同步为自身正 bounds → preferred → 父级估算。新增 `preferredMeasurementWidth_outranksParentEstimateWhenBoundsZero`。

### F2 — Major：双零宽更新仍被跳过，没有延迟补通知

**位置**：[InkStreamRenderer.swift](../../Sources/InkMarkdown/Rendering/InkStreamRenderer.swift)，`notifyHeightChangeIfNeeded`（约第 735 行）、`onDisplayFrame`（约第 667 行的提前返回分支）。

**触发条件**：显示内容发生更新时，`textContainer.size.width` 和 `textView.bounds.width` 均为零；之后宿主提供真实宽度，但没有新的字符需要显示。

**问题与证据**：本轮增加 bounds fallback，覆盖了 textContainer 为零而 bounds 已有正宽度的情况。两者均为零时，`notifyHeightChangeIfNeeded` 仍直接返回，没有记录待测高度状态。与此同时，`onDisplayFrame` 已推进显示游标。后续显示追上内容的空闲帧在 `totalLength > displayIndex` 检查处返回，不会因为宽度就绪而重新尝试高度通知。

**为何重要**：仅依赖 `onDisplayUpdate` 更新高度的宿主可能持续持有旧高度。此项属于本轮零宽修复尚未覆盖的验收缺口，不应描述为新增回归；是否在具体宿主中表现为可见问题，仍需运行时验证。

**建议修法**：宽度未知时保留待测高度标记，在宽度就绪后补测并消费一次。补测入口应覆盖没有新字符的情况，并继续保留 `> 1pt` 高度门闩；成功消费后不应在空闲帧持续重测。

**回归用例**：双零宽时驱动内容显示至当前末尾，在不 append 新 chunk 的情况下提供真实宽度。断言补发一次高度通知，后续同宽空闲帧不重复通知。另测 textContainer 零宽、bounds 正宽的新增 fallback，以及高度差阈值两侧的行为。

**修复状态**：已修复。双零宽时 `notifyHeightChangeIfNeeded` 置 `needsDeferredHeightMeasurement`，宽度就绪后由 `consumeDeferredHeightMeasurementIfNeeded` 补测一次并消费标记。新增 `notifyHeight_deferredUntilWidthReady_notifiesOnce`、`notifyHeight_textContainerZero_fallsBackToBounds`、`notifyHeight_gateIgnoresSubPointChange`、`notifyHeight_bindTextViewConsumesDeferred`。

### F3 — Minor：未知宽保护没有覆盖表格初始化与 setHeaders

**位置**：

- [InkTableRenderHelper.swift](../../Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift)，`contentWidth`（约第 35 行）、`measureColumnContentWidths`。
- [InkStreamTableView.swift](../../Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift)，`setHeaders`（约第 71 行）、`layoutSubviews`。
- [InkTableBlockView.swift](../../Sources/InkMarkdown/Rendering/Components/InkTableBlockView.swift)，`accept`、`setup`。
- [InkTablePresentation.swift](../../Sources/InkMarkdown/Rendering/Components/InkTablePresentation.swift)，`recomputeLayout`、`makeSnapshot`。

**触发条件**：bounds、window 和前台 Scene 均不可用，表格在此阶段接纳内容或调用 `setHeaders`。

**问题与证据**：helper 此时返回 0，但 `setHeaders` 及静态表格 `accept/setup` 仍调用 presentation 计算列宽并创建行。`measureColumnContentWidths` 将列宽上限夹到 1，wrap 随后得到临时等分比例；流式表格还会立即触发 `onHeightChange`。本轮新增的 `contentWidth > 0` guard 位于 `layoutSubviews`，其前面已有 `bounds.width > 0` 检查，因此没有保护上述初始化路径。

**为何重要**：代码仍在未知宽度下生成临时列布局，与文档 §2“未知宽时不重建 wrap 列布局”的描述不符，也可能向宿主提供不代表真实列布局的高度信号。后续正宽布局具有恢复路径，现有证据不足以认定永久坏布局。

**建议修法**：将内容接纳与列布局生成分离。未知宽时保存表头和行数据，在真实宽度到达后计算列布局；保持 `setHeaders` 单次接纳语义，不能简单提前返回而丢失内容。文档应明确 window/Scene fallback 仍是估算输入，不能当作已确认的宿主列宽。

**回归用例**：覆盖无 window/Scene 的零宽表格接纳表头、参考行及后续行，再提供真实宽度。断言内容完整、列比例和高度与直接在该宽度初始化的结果一致，并检查未知宽阶段的布局生成及高度通知行为。

**修复状态**：已修复。`InkTablePresentation.layoutIfWidthKnown` / `makeDeferredSnapshot` 在未知宽时只存数据、不算 wrap 列布局（`hasColumnLayout == false`）；`setHeaders` / `appendRow` 与 `InkTableBlockView` 接纳路径同步。新增 `layout_zeroWidthAccept_recoversConsistentWithDirectInit`、`streamTable_unknownWidthDoesNotNotifyHeight`。

## 3. 本轮未发现新增问题的部分

- Code、Table、Thematic、Attributed 及 Thought 的 `sizeThatFits` 使用统一宽度 resolver；未知宽返回 `noIntrinsicMetric`，与文档 §7 对这些入口的描述一致。
- 正值 init 参数优先于环境值，init 默认 0 时读取环境值；该优先级在公开初始化器注释中有说明。
- preferred 变化超过 0.1pt 时清空容器测量缓存、重置 `lastMeasuredWidth` 并失效 ICS；Representable 对重复宽度写入进行去重。
- 本轮 diff 未显示新增每 chunk 全量重测，也未显示将测量结果写回 SwiftUI 状态的直接反馈循环。此结论不替代运行时布局与性能验收。
- preferred 没有扩展为各个 block 的公共属性。
- ExampleApp 的 SnapKit 工程引用、产品依赖、`Package.resolved` 条目及 `packages.json` 条目已移除；检查范围内未发现核心 Swift 源码或 manifest 引入 SnapKit / Texture。

## 4. Residual risks 与测试缺口

### 4.1 运行时尚未验证

本次没有执行构建、Simulator 交互或测试套件。尚未验证 iOS 15 的 intrinsic 测量路径、iOS 16+ proposal 测量路径、chat cell 首轮高度、旋转或 Split View，以及流式运行时性能。

已执行 staged 与 unstaged 的 `git diff --check`，均通过；该结果仅说明差异格式检查通过。

### 4.2 preferred 测试不能证明首测宽度正确

新增 `preferredMeasurementWidth_firstPassWithoutBounds` 检查高度非零、有效宽度及缓存清空，但没有验证换行后的真实高度。应补充：

- F1 所述非零父视图宽度与 preferred 不同的首测场景。
- preferred 改变后，高度与相同宽度的显式 proposal 测量一致。
- 环境值与 init 参数的优先级，以及 preferred 清除后的 fallback。
- 重复写入或容差内抖动不引发额外测量，真实 bounds 到达后正确接管。

### 4.3 ICS 计数器未覆盖整个 layoutSubviews 调用栈

`InkMarkdownContainerView.layoutSubviews` 在调用 `reportContinuityLayoutEnvironmentIfNeeded()` 之后才设置 `isInsideLayoutSubviews = true`。该回调期间若同步触发 ICS，不会计入 `layoutSubviewsICSInvalidateCount`。因此现有零计数断言不足以证明验收目标 2。

建议让测试观测覆盖完整布局调用栈，并验证宽度变化触发 continuity reconcile 的路径。本项是验证覆盖缺口，不据此单独认定本轮新增了布局循环。

### 4.4 表格与流式补偿缺少关键区分用例

应优先补充 F2、F3 所列用例。零宽返回 sentinel 的测试不能证明真实宽度到达后的恢复正确；高度阈值存在也不能证明被跳过的通知最终得到补偿。

## 5. 修复后复审范围

复审应围绕 F1、F2、F3 的实际修改运行相关契约测试，并补充受影响宿主的首测与流式交互证据。修复方案应保持 UIKit-first、容器单一测量入口、DisplayLink 节流与稳定前缀/活跃后缀路径，不向各个 block 扩展 preferred 公共契约。

构建、测试、安装启动、交互验收与远程 CI 应分别报告。本报告不代表上述关卡已通过。
