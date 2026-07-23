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

## 图片 `Image`（占位）

- **渲染**：默认不加载图片。渲染为占位文本 `[🖼 plainText]`（优先使用 alt 属性，若为空则退化至 `source` 或 `image`）。
- **说明**：`Image` 属于行内节点。图片渲染扩展需走行内路径或 `sourceFilter`，非块路由。

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

## HTML 元素

| AST 节点 | 渲染行为 |
| --- | --- |
| `HTMLBlock` | 忽略不处理 |
| `InlineHTML` | `<br>` 转换为换行符；`<tag .../>` 自定义自闭合标签剥离抛弃；其他按空字符串处理 |
