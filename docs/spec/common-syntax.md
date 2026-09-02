# 通用语法（CommonMark）

映射规则：语法形态 → AST 节点 → 渲染结果。数值配置以 `InkAppearance` 为准。

## 全局规则：固定行高

文本块统一指定 `minimumLineHeight == maximumLineHeight`，避免不同字号混排拉伸行高；Run 级应用 `baselineOffset` 实现垂直居中。详情参考 [principles §3.1](../contributor-guide/03-principles.md)。

---

## 标题 `Heading`

- **语法**：`#` … `######`
- **节点**：`Heading`（`level` 1…6）
- **渲染**：加粗并应用标题颜色。字号分为 H1 与 H2–H6 两档（`Heading.fontSize(forLevel:)`），而非逐级递减。
- **说明**：无自动编号与目录生成。

## 段落 `Paragraph`

- **渲染**：正文样式，段间距由 Appearance 统一控制。

## 强调 `Emphasis` / `Strong`

- `*em*` / `_em_` → 渲染为斜体（无斜体字形时应用 `obliqueness` 伪斜体）。
- `**strong**` / `__strong__` → 渲染为加粗。
- **嵌套**：支持组合嵌套，如 `***bold italic***` 合并加粗与斜体。

## 行内代码 `InlineCode`

- **渲染**：等宽 Regular 字体，字号跟随环境，默认应用环境前景色。圆角背景由 LayoutManager 绘制。
- **说明**：未包含内置语法高亮。

## 链接 `Link`

- **渲染**：展示文本应用链接主题色；点击触发 `linkTapHandler`，代理返回 `true` 时拦截默认行为。
- **说明**：`destination == nil` 时保留链接样式，无点击目标。

## 图片 `Image`

- **默认渲染**（`InkImageRendering.isEnabled == false`，与 [ADR-004](../decisions/ADR-004-v1-image-and-strikethrough-contract.md) 一致）：不加载图片，输出占位文本 `[🖼 plainText]`（优先 alt，否则 `source`，再否则 `"image"`）。
- **opt-in 真图**（`isEnabled == true`，见 [ADR-006](../decisions/ADR-006-opt-in-image-rendering.md)）：
  - **业务策略**：空 host allowlist 默认允许有效 HTTP(S) host；宿主可注入 `allowedHosts` 做可选来源限制。
  - **资源安全边界**（始终生效）：scheme、HTTP 2xx、有效图片数据、默认最多 3 次重定向（配置白名单时每次重校验）、默认可配置的 20 MiB 响应上限、最后订阅取消传播到底层任务；缓存身份含 loader semantic identity。
  - **呈现**：行内经 `InkImageAttachment`；独占段可经 `InkImageBlockHandler` 提升为 `InkImageBlock`（`promotesToBlock` 默认开启）。
  - **相对 URL**：宿主提供 `InkImageRendering.baseURL` 时解析；未提供则明确失败并走占位，不猜测来源。
- **说明**：`Image` 属于行内 Markup；块路由 alone 无法拦截行内节点，库内块级提升由 `InkImageBlockHandler` 实现。宿主亦可通过 `InkInlineSyntax` 或 `sourceFilter` 自定义。

## 列表 `OrderedList` / `UnorderedList` + `ListItem`

- **渲染**：缩进展示，符号为 `•` 或数字序号 `1. 2. 3.`，多级列表递进缩进。
- **说明**：任务列表参考 [extended-syntax.md](extended-syntax.md)。

## 引用 `BlockQuote`

- **渲染**：应用左侧缩进与自定义竖线（`.inkBlockquoteBar`）。支持多级嵌套。

## 代码块 `CodeBlock`

| 通道 | 渲染行为 |
| --- | --- |
| 富文本 | 等宽段落 + 背景色（Fallback 模式） |
| 块路由 | 实例化 `InkCodeBlock` UIView 控件 |

`language` 属性透传至业务层，用于语法高亮扩展。

## 分割线 `ThematicBreak`

- **语法**：独立行 `---` / `***` / `___`
- **渲染**：1pt 宽度横线与上下留白（块路由生成 UIView 视图；富文本模式下使用字符占位）。

## 换行规则

| AST 节点 | CommonMark 语义 | InkMarkdown 渲染结果 |
| --- | --- | --- |
| `SoftBreak` | 软换行 | 转换为单个空格 |
| `LineBreak` | 硬换行（行尾 `\` 或包含双空格） | 转换为 `\n` |

## 深度思考过程 `Thought`

| 通道 | 语法形态 | 渲染行为 |
| --- | --- | --- |
| 块路由（默认） | `<think>...</think>` / `<thought>...</thought>` | 实例化为原生可交互的 `InkThoughtBlockView` 卡片（支持点击展开/折叠、VoiceOver 适配、TextKit 统一排版与链接拦截）。**折叠态 SSOT** 为 `InkThoughtBlock.isCollapsed`；`makeView()` / `apply()` 读取该字段，视图 toggle 回写模型。流式 PREFIX 在 promotion 前即挂载卡片；finish / promotion 必须保留折叠态（不得仅靠 re-parse Markdown 字符串恢复 UI 状态）。 |
| 富文本 Fallback | `<think>...</think>` / `<thought>...</thought>` | **仅限** `InkAttributedRenderer` 及不使用 session 块通道的宿主：渲染为包含 `💭 已深度思考`（流式中途为 `💭 思考过程`）的富文本段落，并应用 `backgroundColor`。 |

- **解析边界**：通过 `InkThoughtScanner` 唯一所有者精确匹配 `<think>` / `<thought>` 开标签与 `</think>` / `</thought>` 闭标签；严格排除 `<thinker>`、`<thinking>`、`<think class="x">` 等非法前缀。
- **未闭合容错**：流式未闭合状态被识别为中途态（`isComplete = false`），正常呈现思考正文并显示进行中文案（`思考过程`）。
- **尾随正文保全（Suffix Preservation）**：当 `</think>\n正式回答` 处于同一 AST 节点时，严格保全闭标签后的 `suffixContent`，并无缝返还下游 Markdown 渲染管线，保证正式回答首段不丢失。
- **流式 PREFIX 约束**：流式早期卡片**仅**对文档 PREFIX 思考标签生效；文档中部出现的 `<think>` 仍等待 promotion 后由块路由处理，不在流式阶段提前挂载卡片。
- **流式 append 折叠保留**：`InkMarkdownRenderSession.updateStreamingThought` 重建 PREFIX 快照时必须拷贝上一帧 `streamingThought.isCollapsed`（用户 override 优先于 `isInitiallyCollapsed`）。
- **Chat 终态会话**：ExampleApp 将 promotion 完成的 `InkMarkdownRenderSession` 挂到 `messages[].renderSession`，UI 仍用 `InkStreamMarkdownView`；不得 value-copy `[InkRenderableBlock]` 作为唯一真相。

## HTML 元素

| AST 节点 | 渲染行为 |
| --- | --- |
| `HTMLBlock` | 优先经 `InkThoughtScanner` 匹配深度思考块；其他通用 HTML 标签按 CommonMark 忽略不处理 |
| `InlineHTML` | `<br>` 转换为换行符；`<think>` / `</think>` 标签剥离；`<tag .../>` 自定义自闭合标签剥离抛弃；其他按空字符串处理 |
