# 通用语法（CommonMark）

写法：语法 → 节点 → 渲染结果。数值以 `InkAppearance` 为准。

## 全局：固定行高

块内统一 `minimumLineHeight == maximumLineHeight`，混排字号不撑乱行盒；run 级 `baselineOffset` 做垂直居中。见 principles §3.1。

---

## 标题 `Heading`

- 语法：`#` … `######`
- 节点：`level` 1…6
- 渲染：加粗标题色；**字号两档——H1 与 H2–H6**（`Heading.fontSize(forLevel:)`），不是逐级六档
- 不自动编号、不生成目录

## 段落 `Paragraph`

- 正文样式；段间距由 appearance 控制

## 强调 `Emphasis` / `Strong`

- `*em*` / `_em_` → italic（无变体时 `obliqueness` 伪斜体）
- `**strong**` / `__strong__` → bold
- 可嵌套，traits 合并

## 行内代码 `InlineCode`

- 等宽 + regular；字号随环境；默认环境前景色；圆角背景（LayoutManager）
- 不做语法高亮

## 链接 `Link`

- 展示文本用链接色；点击走 `linkTapHandler`，返回 `true` 则不再默认处理
- `destination == nil` 仍可有链接样式，但没有有效目标

## 图片 `Image`（占位）

- **不下载**。占位：`[🖼 plainText]`；alt 空则用 `source`；再空则用 `image`
- `Image` 是行内节点；真图扩展走行内路径或 `sourceFilter`，不是块 handler

## 列表 `OrderedList` / `UnorderedList` + `ListItem`

- 缩进；`•` / `1. 2. 3.`；嵌套再缩
- 任务列表见 [extended-syntax](extended-syntax.md)

## 引用 `BlockQuote`

- 左缩进 + 左侧竖线（`.inkBlockquoteBar`）
- 可嵌套

## 代码块 `CodeBlock`

| 通道 | 行为 |
| --- | --- |
| 富文本 | 等宽段落 + 背景（fallback） |
| 块路由 | `InkCodeBlock` UIView |

`language` 留给业务做高亮扩展。

## 分割线 `ThematicBreak`

- 语法：独立行 `---` / `***` / `___`
- 1pt 横线 + 上下留白（UIView 块更可控；富文本有占位 fallback）

## 换行

| 节点 | CommonMark 语义 | 本库 |
| --- | --- | --- |
| `SoftBreak` | 软换行 | 空格 |
| `LineBreak` | 硬换行（行尾 `\` 或两空格 + 换行） | `\n` |

## HTML

| 节点 | 渲染 |
| --- | --- |
| `HTMLBlock` | 忽略 |
| `InlineHTML` | `<br>` → 换行；形如 `<tag …/>` 的自定义空标签丢弃；其余空串 |
