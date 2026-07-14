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

## 删除线 `Strikethrough`（降级）

- 语法：`~~text~~`
- 内容会渲出，**未**加 `.strikethroughStyle`（default 分支渲子节点）
- 补齐点：`renderInline` 为 `Strikethrough` 加删除线 attribute（路线 v2）

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
| 删除线 | 有字无样式 |
| 自动链接 | 走 `Link` |
| 脚注 / Directive | 未做 / 可扩展 |
