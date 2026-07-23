# 渲染语义规范

定义 Markdown 到 UIKit 的渲染行为规范与输出契约。不包含内部架构实现与依赖 API 速查。

## 使用流程

1. 新增或修改语法支持时，先在本文档目录确定渲染行为契约。
2. 结合 [贡献者文档](../contributor-guide/README.md) 确定实现方式。
3. 补充语义测试用例，并同步核对本文档。

## 规范目录

| 文档 | 范围 |
| --- | --- |
| [common-syntax.md](common-syntax.md) | CommonMark 核心语法 |
| [extended-syntax.md](extended-syntax.md) | GFM 扩展语法（表格、任务列表、删除线等） |

## 约定事项

- **结果不一致排查**：渲染结果与规范不一致时，需确认是代码实现缺陷还是规范调整，修正对应实现或文档并补充测试。
- **扩展新增语法**：先在本文档定义行为契约，再参照参考文档中的节点定义进行实现。
- **产品路线与规划**：参考 [roadmap.md](../roadmap.md)。
- **交付状态**：参考 [current-status.md](../current-status.md)。
