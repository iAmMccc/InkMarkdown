# 渲染语义规范

规定「Markdown → UIKit 上长什么样」。不讲架构实现（见 contributor-guide），不讲依赖 API（见 references）。

| 文档 | 范围 |
| --- | --- |
| [common-syntax.md](common-syntax.md) | CommonMark 核心 |
| [extended-syntax.md](extended-syntax.md) | GFM 扩展（表 / 任务列表 / 删除线等） |

约定：

- 渲染结果和本文不符 → **以源码为准**，再改文档
- 要扩渲染 → 先定这里的契约，再查 references 里的节点属性，最后用 development 的扩展点
- 产品阶段与「做什么 / 不做什么」→ [roadmap.md](../roadmap.md)
