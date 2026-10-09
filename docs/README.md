# InkMarkdown 文档

InkMarkdown 是 UIKit-first Markdown 库，SwiftUI 通过独立 adapter 共享渲染语义。

| 任务 | 入口 |
| --- | --- |
| 了解当前能力与未验收项 | [当前状态](current-status.md) |
| 接入与贡献 | [贡献者指南](contributor-guide/README.md)、[贡献规范](../CONTRIBUTING.md) |
| 理解工程结构 | [Codebase](codebase/README.md) |
| 确认架构约束 | [有效 ADR](decisions/README.md) |
| 查询渲染契约 | [语义规范](spec/README.md) |
| 配置图片后端 | [图片后端指南](contributor-guide/12-image-backends.md) |
| 排查尺寸与布局 | [布局测量契约](contributor-guide/13-layout-measurement-contract.md) |
| 查询三方 API | [参考资料](references/README.md) |
| 安排后续开发 | [路线图](roadmap.md) |
| 准备发布 | [发布清单](release-checklist.md) |

源码、manifest 和实际执行结果证明当前实现；ADR 与语义规范定义预期契约。两者冲突时判断实现缺陷或文档过时，不用修改文档掩盖缺陷。计划与旧验证记录不能充当当前交付证明。

当前能力和未验收项仅在 current-status.md 维护，技术细节归对应指南。README 核心信息变化时同步英文和中文版本。只保留有效文档；被替代内容删除并修复入口，不创建备份、归档或重复任务摘要。
