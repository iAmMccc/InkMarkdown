# 渲染语义规范

这是 Reference 文档，规定「Markdown → UIKit 上长什么样」。它描述稳定的行为契约，不讲架构实现，也不替代依赖 API 参考。

## 使用方式

1. 新增或修改语法时，先在本目录确定预期行为。
2. 再到 [贡献者文档](../contributor-guide/README.md) 选择实现边界。
3. 最后在测试中补语义断言，并回到本目录核对文字。

| 文档 | 范围 |
| --- | --- |
| [common-syntax.md](common-syntax.md) | CommonMark 核心 |
| [extended-syntax.md](extended-syntax.md) | GFM 扩展（表 / 任务列表 / 删除线等） |

约定：

- 渲染结果和本文不符 → 先判断是实现缺陷还是规范过时；修正对应一侧并补语义测试
- 要扩渲染 → 先定这里的契约，再查 references 里的节点属性，最后用 development 的扩展点
- 产品阶段与「做什么 / 不做什么」→ [roadmap.md](../roadmap.md)
- 当前是否已经交付 → [current-status.md](../current-status.md)
