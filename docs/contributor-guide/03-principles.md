# 三、核心原理

本页记录渲染核心必须保持的约束。修改行高、样式组合、块路由、TextKit 绘制或流式状态前，先核对对应小节。

改核心渲染前先读这一页。红线测试在 `Tests/InkMarkdownTests/`。

## 3.1 固定行高

混排不同字号时，行盒高度必须一致：

```swift
para.minimumLineHeight = lineHeight
para.maximumLineHeight = lineHeight
para.lineSpacing = 0
```

只锁行高不够：小字默认底对齐。对每个 run：

```swift
baselineOffset = max(0, (fixedLineHeight - font.lineHeight) / 2)
```

后处理**只**做两件事：统一 `paragraphStyle`，按 run 的 font 算 `baselineOffset`。**不改** font / color / trait。

相关测试：`fixedLineHeight_*`、`baselineOffset_neverNegative`。

## 3.2 Context 下传（禁止事后回写）

事后 `enumerate` 改字体容易踩坑：

- 标题里的行内代码被标题 bold 抹成非等宽
- 引用里的链接被引用色盖掉

正确做法：父节点派生新的 `InkTextContext` 给子节点，叶子节点一次性挂上 font / color / link。

`InkTextContext` 是纯值；派生方法返回新实例。

| 方法 | 语义 |
| --- | --- |
| `addingTrait(.traitBold/.traitItalic)` | **叠加** trait，保留字号 / family |
| `monospaced()` | **重置**为等宽 + regular，只保留 pointSize |
| `coloring` / `linking` / `withFont` | 改色 / 挂 URL / 换字体 |
| `striking()` | 置删除线标志（叶子读 `isStrikethrough` 挂 `.strikethroughStyle`） |

`monospaced()` 和 trait 叠加语义相反，顺序无关：strong 里的 inline code 始终是 regular 等宽。

颜色不进 `monospaced()`：要不要回落环境色，由 `renderInlineCode` + `appearance.inlineCode` 决定。

相关测试：`headingInlineCode_*`、`blockquoteLink_*`、`strongInlineCode_*`、`strikethrough_*`。

### 范式 A 的缺点：叶子必须逐个读 context

当前 context 下传是**范式 A**（accumulator 下传 + 叶子收集挂属性）：每个叶子（`renderText` / `renderInlineCode` / `renderImage`）都要显式读取 context 里每个相关标志，一次性挂载 attributes。

带来的维护开销：**每新增一个样式标志，就必须在每个叶子补一段读取**。漏掉一个叶子，该叶子覆盖的子树就会丢样式。历史案例：删除线初版只补了 `renderText`，导致 `~~`code`~~` 的代码部分没有删除线（后改用 `.underlineStyle` 又错改成了下划线）——这是范式 A 的典型遗漏，并非逻辑错误。

### 什么时候可以用「后置 range 装饰」（范式 B）

范式 B 指先递归子树拿到结果，再对整段 `addAttribute` 一次性叠加。本仓库已有先例：`renderBlockQuote` 末尾对整段挂 `.inkBlockquoteBar`。

不是所有属性都能走 B。判据：

> 属性 X 可以后置，当且仅当**没有子节点会根据 X 决策自己的渲染外观**，且叠加 X 不会覆盖子节点已设的同 key 值。

| 属性 | 可否后置 | 理由 |
| --- | --- | --- |
| `.strikethroughStyle` | ✅ | 子节点从不读、从不据其决策 |
| `.link`（URL） | ✅ | 子节点只平移、不据其决策（但链接**颜色**不行，inlineCode 要据其回落） |
| `.inkBlockquoteBar` | ✅ | 已是后置先例 |
| `.foregroundColor` / `.font` / `obliqueness` | ❌ | 叶子深度依赖，后置会覆盖叶子自己的决策 |

删除线走 B 能根治「叶子遗漏」，但会让「所有行内样式用同一种机制」的一致性出现破例。**当前采用范式 A，与 MarkdownUI 和苹果 Foundation 的做法一致**（见下），不轻率切 B。

### 参考：主流库实现

- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)：删除线是实现 `TextStyle` 协议的 `StrikethroughStyle`，递归时 `merge` 进下传的累加 `AttributeContainer`，叶子读取后一次性挂上。
- 苹果 Foundation `AttributedString(markdown:)`：cmark-gfm 的 strikethrough 扩展解析出 span 后，直接映射到对应 run 的 `strikethroughStyle` attribute。

两者都用「累加 style 下传 + 叶子收集」，没有采用「先出结果再对 range 叠加」。原因：复合样式（如 `~~**bold**~~`）在叶子收集时保证落在同一 run，run 边界对齐更安全；且所有行内样式共用一套机制，扩展性来自协议抽象。

### 演进方向（v2，见 [roadmap](../roadmap.md) Phase B）

根治「叶子遗漏」的方向**不是切范式 B**，而是把 context 里的离散标志（`isStrikethrough`、`linkURL`、`obliqueness`…）收敛成一个**可收集的 TextStyle 容器**——类似 MarkdownUI 的 `_collectAttributes(inout:)`：叶子不再手写判断，而是接收已收集好所有样式的容器直接应用。这是范式 A 的成熟形态。v1 维持现状并补齐叶子即可。

## 3.3 双通道 + 块路由

`NSAttributedString` 无法承载表格网格、代码块容器、可控分割线。抽象：

```swift
public protocol InkBlockHandler {
  func canHandle(_ markup: Markup) -> Bool
  func makeBlock(from:configuration:) -> InkRenderableBlock?
}
```

返回 `nil` = 回落富文本。`defaultBlockHandlers`：代码块、表格、分割线。

## 3.4 行内代码

| 维度 | 规则 |
| --- | --- |
| 字体 | `monospacedSystemFont` + regular（不继承 bold/italic） |
| 字号 | 跟随环境（标题内 = 标题字号） |
| 颜色 | 默认环境前景色；可配 `inlineCode.textColor` |
| 背景 | attribute `.inkInlineCodeBackground`，`InkMarkdownLayoutManager` 画圆角；高度小于行高 |

## 3.5 样式生命周期

| 类型 | 范围 |
| --- | --- |
| `InkAppearance` | 视觉参数；`shared` 全局，或每次渲染单独实例 |
| `InkConfiguration` | 单次渲染的全部可插拔要素（appearance + 自定义扩展点） |

`Text.blockInsets` 默认 `.zero`：库不占水平边距。垂直间距靠元素下间距 + 尾部哨兵字符。

默认值由 `appearance_defaultValues` 锁住。改默认必须改测试。

> 标题字号：`Heading.fontSize(forLevel:)` 当前是 **H1 一套、H2–H6 共用另一套**，不是逐级递减。

## 3.6 LayoutManager 兜底绘制（TextKit 1）

| 效果 | attribute | 绘制点 |
| --- | --- | --- |
| 行内代码背景 | `.inkInlineCodeBackground` | `fillBackgroundRectArray` |
| 引用左侧竖线 | `.inkBlockquoteBar` | `drawBackground` → `drawBlockquoteBars` |

`InkAttributedTextBlock` 与 `InkTableCellTextView` 共用，单元格和正文一致。

这是 **TextKit 1** 路径（`NSLayoutManager` 子类）。v1–v2 **默认 TK1**，不为聊天气泡强上 TextKit 2。

宿主若把 `NSAttributedString` 塞进系统默认 `UITextView`（iOS 16+ 可能是 TK2），段落样式 / 链接等还在；圆角代码底、引用竖线依赖库提供的 text view / block。详见 [roadmap 文本引擎](../roadmap.md)。

## 3.7 流式：解析 / 显示双缓冲

```text
SSE chunk
  → 后台串行队列
  → preloadContent（parseVersion / renderGeneration）
  → CADisplayLink 30–60fps
  → textStorage 增量 append
```

要点：

- **解耦**：解析慢不影响吐字帧率；显示侧每帧截取近似 O(1)
- **稳定边界**（`InkIncrementalMarkdownRenderer`）：已闭合前缀缓存；只重渲活跃后缀。未闭合代码围栏整段留在活跃区
- **防过期**：`renderGeneration` / `parseVersion` 丢弃迟到的后台结果
- **上限**：`maxParseLength = 50_000`（硬编码）
- **暂停**：`isDisplayPaused`；恢复时 `_flushDisplay`

流式复用 `InkAttributedRenderer`，不是第二套渲染。

## 3.8 表格列宽

| 模式 | 列宽 | 行为 |
| --- | --- | --- |
| `.wrap` | 比例 `ratio` | 换行铺满 |
| `.scroll` | 固定像素 | 横向滚动、单行 |

宽度用渲染后 attributed string 的 `boundingRect` 量，受 `columnMaxWidthRatio`（默认 0.5）限制。流式表 `widthsNeedExpand` 为 O(列数)；需要时 `rebuildAllRows`。

单元格走 `cellMarkdownText` → 子节点 `format()` 再 `renderInline`，保留 `**` 等内联标记。

## 改核心检查表

1. 行高 → `fixedLineHeight_*`
2. 样式 → context 派生，禁止 enumerate 回写
3. 新块 → `InkBlockHandler`，别塞进 attributed 主路径
4. 默认视觉 → `InkAppearance` + 对应测试
5. 流式 → 稳定边界 + generation/version
