# 扩展语法（GFM 等）

状态：已渲 · 降级 · 未处理

swift-markdown 底层是 **cmark-gfm**，能解析 GFM 扩展；本库只渲染其中一部分。

## 表格 `Table`（已渲）

```markdown
| 名称 | 数量 |
| --- | ---: |
| A | 1 |
```

- **只有块路由**产出 `InkTableBlock` → `InkTableBlockView`；纯 `InkAttributedRenderer` 会退化成管道符文本（预期行为）
- 表头 / 表体样式区分；对齐跟分隔行 `:--` / `--:` / `:-:`
- 列宽：量 attributed 内容宽 → 比例；`columnMaxWidthRatio` 封顶
- `InkTableLayoutMode`：`.wrap` 折行铺满 · `.scroll` 横向滚
- 单元格：子节点 `format()` 保留内联 Markdown，再 `renderInline`
- 流式：`InkStreamTableView` 逐行追加
- 样式：`InkAppearance.Table`

## 任务列表（已渲）

```markdown
- [ ] 待办
- [x] 已完成
```

- 节点：`ListItem.checkbox` → `.checked` / `.unchecked`
- 展示 ☑ / ☐；**无内置切换交互**（状态归业务）

## 删除线 `Strikethrough`（已渲）

- 语法：`~~text~~`
- `renderInline` 有专门 case，经 `context.striking()` 把删除线标志随 context 下传；叶子（`renderText` / `renderInlineCode` 含 margin / `renderImage`）读标志挂 `.strikethroughStyle = .single`
- 嵌套组合正确：`~~**bold**~~` 同时有粗体与删除线（context 下传互不覆盖）
- 机制与权衡见 [03-principles §3.2](../contributor-guide/03-principles.md)；范式 A 的叶子遗漏风险与 v2 容器化演进见 [roadmap B9](../roadmap.md)

### 已知限制

- **`inlineSyntaxes` 命中时不继承删除线**：自定义行内语法（如 `@提及`、`$标签$`）在 `renderText` 内 early-return，跳过了挂删除线的代码路径；且 `InkInlineContext` 当前不透传删除线状态。因此 `~~@张三~~` 的 `@张三` 部分无删除线。
  - 不在补删除线时顺手修，因为它牵涉公开扩展点 API（`InkInlineContext` 是否承载样式状态）的设计，应单独立项。
  - 临时规避：自定义语法自行在产物上挂 `.strikethroughStyle`（若需要）。
- 删除线颜色当前未接入 `InkAppearance`，使用 UIKit 默认（跟随文字前景色）。主题化配置留待后续。

## 自动链接（已渲，走 `Link`）

- CommonMark：`<https://example.com>`
- GFM 另有裸 URL 识别（cmark-gfm autolink extension）；解析结果仍是 `Link`，渲染与普通链接相同

## 未专门处理

| 语法 | 节点 | 说明 |
| --- | --- | --- |
| 脚注 | — | 超出范围 |
| `@Directive` | `BlockDirective` | 可用 `InkBlockHandler` |
| `CustomInline` | 同左 | 用 `InkInlineSyntax` |

## 扩展支持矩阵

| 扩展 | 状态 |
| --- | --- |
| 表格 | 块路由完整 |
| 任务列表 | 只展示，不切换 |
| 删除线 | 已渲（`inlineSyntaxes` 命中时不继承，见上） |
| 自动链接 | 走 `Link` |
| 脚注 / Directive | 未做 / 可扩展 |
