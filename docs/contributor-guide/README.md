# 贡献者文档

本文档供阅读源码、修改渲染逻辑或提交测试的开发者参考。建议先查看 [当前状态](../current-status.md)，再根据具体需求阅读对应文档。

## 任务索引

| 任务 | 建议阅读顺序 |
| --- | --- |
| 了解项目概况 | [项目概述](01-overview.md) → [架构设计](02-architecture.md) |
| 修改渲染核心逻辑 | [核心原理](03-principles.md) → [模块详解](05-modules.md) |
| 新增功能或扩展 | [开发指南](04-development.md) → [渲染语义规范](../spec/README.md) |
| 构建与运行测试 | [开发指南：构建与测试](04-development.md#构建与测试) |
| 排查 CI 或 Xcode 工具链问题 | [CI 与工具链排坑](07-ci-and-toolchain-pitfalls.md) |
| 排查渲染显示问题 | [FAQ](06-faq.md) → [开发指南](04-development.md) |
| 查找 API 或模块位置 | [模块详解](05-modules.md) → [swift-markdown API 速查](../references/swift-markdown-api-guide.md) |

## 文档结构说明

| 文档 | 类型 | 说明 |
| --- | --- | --- |
| `01-overview.md` | Overview | 项目说明与边界 |
| `02-architecture.md` | Architecture | 分层结构与双通道设计原理 |
| `03-principles.md` | Principles | 行高计算、Context 传递与流式处理原则 |
| `04-development.md` | Guide | 构建、测试、自定义扩展与调试指南 |
| `05-modules.md` | Reference | 源码类型、模块与扩展点分布 |
| `06-faq.md` | Troubleshooting | 常见显示与渲染问题排查 |
| `07-ci-and-toolchain-pitfalls.md` | Troubleshooting | CI 环境配置、版本差异与排坑记录 |

## 与其他文档的边界

- 语法渲染样式规范：查看 [渲染语义规范](../spec/README.md)。
- swift-markdown 接口说明：查看 [API 速查](../references/swift-markdown-api-guide.md)。
- 功能交付状态与限制：查看 [当前状态](../current-status.md)。
- 快速运行 ExampleApp：查看 [开发指南](04-development.md)。

## 文档修改检查项

1. 确认文档类型与目标读者。
2. 结合源码与测试核对技术细节。
3. 确保代码示例与最新公开 API 一致。
4. 确保新文档在 `README.md` 中包含对应链接。
5. 修改文件路径时更新关联的相对链接。
