# 贡献者文档

这组文档面向准备阅读源码、修改渲染行为或提交测试的开发者。先确认[当前状态](../current-status.md)，再按任务进入对应页面。

## 按任务查找

| 任务 | 阅读顺序 |
| --- | --- |
| 第一次了解项目 | [项目概述](01-overview.md) → [架构设计](02-architecture.md) |
| 修改渲染核心 | [核心原理](03-principles.md) → [模块详解](05-modules.md) |
| 增加功能或扩展 | [开发指南](04-development.md) → [渲染语义规范](../spec/README.md) |
| 构建或运行测试 | [开发指南：构建与测试](04-development.md#构建与测试) |
| CI 红 / 本机与 CI Xcode 不一致 | [CI 与工具链排坑](07-ci-and-toolchain-pitfalls.md) |
| 排查显示问题 | [FAQ](06-faq.md) → [开发指南](04-development.md) |
| 确认某个 API 或模块位置 | [模块详解](05-modules.md) → [swift-markdown API 速查](../references/swift-markdown-api-guide.md) |

## 按文档类型查找

本目录沿用项目已有的文件路径，同时明确每篇文档的阅读目的：

| 文档 | 类型 | 适合回答的问题 |
| --- | --- | --- |
| `01-overview.md` | Explanation | 项目解决什么问题，边界在哪里？ |
| `02-architecture.md` | Explanation | 为什么采用双通道和这些层次？ |
| `03-principles.md` | Explanation | 固定行高、Context 和流式边界为什么这样设计？ |
| `04-development.md` | How-to | 怎样构建、测试、进行自定义语法/组件扩展与调试？ |
| `05-modules.md` | Reference | 某个类型、模块或扩展点在哪里？ |
| `06-faq.md` | Troubleshooting | 遇到常见症状时先检查什么？ |
| `07-ci-and-toolchain-pitfalls.md` | Troubleshooting | CI 钉死版本、本机差异、失败原因？ |

单篇文档只承担一个主要阅读目的。需要跨类型内容时，保留摘要并链接到负责该主题的页面，不复制整段规则。

## 与其他文档的边界

- 想确认某种语法应该怎样显示：看[渲染语义规范](../spec/README.md)。
- 想查 swift-markdown 的类型和遍历 API：看[API 速查](../references/swift-markdown-api-guide.md)。
- 想确认仓库当前是否真的支持某项能力：看[当前状态](../current-status.md)。
- 想跑通 ExampleApp 做第一次小改动：看[开发指南](04-development.md)。
- 零基础 Markdown / TextKit Tutorial 不在本仓；维护者个人跟练材料见 PersonalDocument 的 `iOS/InkMarkdown/learning-path/`。

## 修改文档时的最小检查

1. 先确认内容类型和目标读者。
2. 用源码、测试或官方资料核对事实。
3. 示例必须与当前 public API 一致。
4. 新页面必须从本目录或 `docs/README.md` 可达。
5. 修改路径后检查所有相对链接。
