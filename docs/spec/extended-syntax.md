# 扩展语法（GFM 等）

支持状态：已渲染 · 降级处理 · 未处理

swift-markdown 底层由 cmark-gfm 驱动，支持解析 GFM 扩展语法。本库对各类扩展语法的渲染规范如下：

## 表格 `Table`（已渲染）

```markdown
| 名称 | 数量 |
| --- | ---: |
| A | 1 |
```

- **渲染方式**：仅在块路由中产出 `InkTableBlock` → `InkTableBlockView`；若仅使用 `InkAttributedRenderer`，退化为管道符纯文本。
- **表头与对齐**：支持表头/表体样式区分；基于 `:--` / `--:` / `:-:` 设置列对齐方式。
- **列宽计算**：测量内容宽度并按比例分配；通过 `columnMaxWidthRatio` 设置最大比例上限。
- **布局模式**：`InkTableLayoutMode` 支持 `.wrap`（换行适应宽度）与 `.scroll`（横向滚动）。
- **单元格渲染**：子节点调用 `format()` 保留内联 Markdown，再执行 `renderInline`。
- **流式渲染**：由 `InkStreamTableView` 实现逐行增量追加。
- **主题配置**：读取 `InkAppearance.Table` 样式。

## 任务列表（已渲染）

```markdown
- [ ] 待办
- [x] 已完成
```

- **AST 节点**：`ListItem.checkbox` 对应 `.checked` / `.unchecked`。
- **显示形态**：渲染为 ☑ 或 ☐，无内置交互切换（交互状态由业务层管理）。

## 删除线 `Strikethrough`（已渲染）

- **语法**：`~~text~~`
- **渲染实现**：`renderInline` 拦截删除线节点，通过 `context.striking()` 向下传递删除线标记。文本叶子节点（`renderText` / `renderInlineCode`）检查标记并应用 `.strikethroughStyle = .single`。
- **样式嵌套**：支持 `~~**bold**~~` 等加粗与删除线叠加效果（Context 状态互相独立）。
- **设计权衡**：参考 [03-principles §3.2](../contributor-guide/03-principles.md)；演进规划参考 [roadmap B9](../roadmap.md)。

### 已知限制

- **`inlineSyntaxes` 命中时不继承删除线**：自定义行内语法（如 `@提及`、`$标签$`）在 `renderText` 中触发 early-return，跳过删除线设置逻辑，且 `InkInlineContext` 未透传删除线状态。因此 `~~@张三~~` 中 `@张三` 缺少删除线。
  - **因由与规划**：该问题涉及公开 API（`InkInlineContext` 样式透传机制）的设计调整，需独立改进。
  - **变通方案**：如需要，自定义语法可在生成 `NSAttributedString` 时手动添加 `.strikethroughStyle`。
- **图片叶子节点**：`renderImage` 当前不写入 `.strikethroughStyle`；`~~![alt](url)~~` 不承诺图片上的删除线视觉效果。
- **颜色配置**：删除线颜色目前使用 UIKit 默认文字前景色，未接入 `InkAppearance`。后续版本补充主题配置。

## 自动链接（已渲染，使用 `Link` 节点）

- CommonMark 标准：`<https://example.com>`
- GFM 裸 URL 识别（cmark-gfm autolink 扩展）：解析产物仍为 `Link`，渲染逻辑与标准链接一致。

## 未独立处理语法

| 语法 | AST 节点 | 建议处理方式 |
| --- | --- | --- |
| 脚注 | — | 超出当前支持范围 |
| `@Directive` 指令 | `BlockDirective` | 使用 `InkBlockHandler` 自定义扩展 |
| `CustomInline` | `CustomInline` | 使用 `InkInlineSyntax` 自定义扩展 |

## 扩展语法矩阵

| 语法扩展 | 支持状态 | 渲染逻辑 |
| --- | --- | --- |
| 表格 | 已渲染 | 块路由完整支持 |
| 任务列表 | 已渲染 | 仅展示状态，不包含交互控制 |
| 删除线 | 已渲染 | 支持主要场景（行内自定义语法未继承，见限制说明） |
| 自动链接 | 已渲染 | 统一路由至 `Link` 渲染路径 |
| 脚注 / 指令 | 未处理 | 提供自定义扩展点 |
