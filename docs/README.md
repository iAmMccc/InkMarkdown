# InkMarkdown 文档

这里是项目知识库入口。InkMarkdown 当前是 **UIKit 专用** Markdown 渲染库，不提供也不规划 SwiftUI 渲染器。

## 先从哪里开始

| 你想做什么 | 推荐阅读 |
| --- | --- |
| 完全不懂 Markdown，从 UIKit 经验开始学习 | [零基础学习路径](learning-path/README.md) |
| 了解现在已经做到哪 | [当前状态](current-status.md) |
| 查为什么做了某项工程决策 | [架构决策 ADR](decisions/README.md) |
| Agent / 快速建立仓库工程事实（栈、结构、风险） | [Codebase 证据基线](codebase/README.md) |
| 30 分钟建立项目全貌 | [贡献者文档](contributor-guide/README.md) → [项目概述](contributor-guide/01-overview.md) → [架构设计](contributor-guide/02-architecture.md) |
| 修改渲染核心 | [核心原理](contributor-guide/03-principles.md) → [模块详解](contributor-guide/05-modules.md) |
| 对比主流 iOS Markdown 库与项目定位 | [对比学习章](learning-path/08-library-landscape-and-design-tradeoffs.md) → [生态 Reference](references/ios-markdown-ecosystem.md) |
| 排查常见问题 | [FAQ](contributor-guide/06-faq.md) |
| CI 失败 / 本机 Xcode 与 CI 不一致 | [CI 与工具链排坑](contributor-guide/07-ci-and-toolchain-pitfalls.md) |
| 查询 swift-markdown API | [依赖 API 参考](references/README.md) |
| 确认某种 Markdown 应怎样渲染 | [渲染语义规范](spec/README.md) |
| 查看后续开发优先级 | [路线图](roadmap.md) |

## 文档分层

| 层级 | 回答的问题 | 主要文件 |
| --- | --- | --- |
| 项目约束 | 定位、平台和协作规则是什么 | 根目录 `AGENTS.md` / `CLAUDE.md` |
| 入门课程 | Markdown、Markup 树、富文本和渲染管线怎样串起来 | [learning-path/](learning-path/README.md) |
| 当前事实 | 仓库现在真正交付了什么 | [current-status.md](current-status.md)、`Package.swift`、公开 API、测试 |
| 工程证据基线 | 栈、目录、架构摘要、约定、测试方式、风险（可核验短文档） | [codebase/](codebase/README.md) |
| 决策记录 | 为什么选定某方案、否决了什么 | [decisions/](decisions/README.md) |
| 开发知识 | 为什么这样设计，怎样修改 | [contributor-guide/](contributor-guide/README.md) |
| 行为契约 | Markdown 应呈现什么语义 | [spec/](spec/README.md) |
| 依赖知识 | swift-markdown 提供什么 API | [references/](references/README.md) |
| 未来计划 | 接下来做什么，但尚未交付什么 | [roadmap.md](roadmap.md) |

## 按文档类型查找

项目保留面向任务的目录结构，同时用 Diátaxis 四类文档帮助选择阅读方式：

| 类型 | 入口 | 适合的问题 |
| --- | --- | --- |
| Tutorial | [零基础学习路径](learning-path/README.md) | 我想循序学习并完成练习 |
| How-to | [开发指南](contributor-guide/04-development.md) | 我想完成一次构建、扩展或调试任务 |
| Explanation | [架构与原理](contributor-guide/02-architecture.md) | 我想理解设计原因和约束 |
| Reference | [API 速查](references/README.md)、[语义规范](spec/README.md) | 我需要准确查找类型、参数和行为 |

`current-status.md` 和 `roadmap.md` 是项目事实记录与计划记录，不属于四类教程页面。学习路径是 Tutorial 系列；为了让初学者保持连续阅读，其中会嵌入必要的概念解释，但 API 细节仍以 Reference 为准。

出现冲突时，不要简单用“源码永远正确”掩盖问题：

1. 产品定位和明确决策以 `AGENTS.md` / `CLAUDE.md` 为准。
2. 已交付 API 与平台能力以 `Package.swift`、源码和通过的测试为证据。
3. `docs/codebase/` 是工程事实快照，不替代 `current-status.md` 或 `contributor-guide/`；与源码冲突时以源码 / 测试为准并回写 codebase。
4. 规范与实现不一致时，先判断是实现缺陷还是规范过时，再同步修正对应一侧。
5. Roadmap 只代表计划；未在当前状态和测试中出现的能力不能写成已支持。

## 维护规则

- 功能、平台、依赖或公开 API 变化时，先更新 [current-status.md](current-status.md)。
- 修改 README 时，同时更新 `README.md` 与 `README.zh-CN.md`。
- 新增渲染行为时，更新 `spec/` 并补语义测试。
- 新增核心抽象时，更新架构、模块地图和对应 FAQ。
- 解析器、TextKit 路径或三条渲染入口变化时，复查 `learning-path/` 中的示例和图。
- Apple 文本 API 或外部 Markdown 库的公开边界变化时，先更新 `references/`，再复查学习章节。
- 新增文档时，把它加入对应目录的 README 或本页入口；不要留下只能通过文件搜索找到的页面。
- 栈、依赖、公开入口、测试方式或高风险点变化时，更新 [codebase/](codebase/README.md) 对应文件（可重跑 `acquire-codebase-knowledge` 扫描）。
- `Sources/InkMarkdown/Rendering/Components/TABLE_INTEGRATION_GUIDE.md` 使用旧 API，仅可作为历史材料；当前接入方式以 contributor guide 和公开 API 为准。
