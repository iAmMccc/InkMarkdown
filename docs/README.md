# InkMarkdown 文档

项目知识库入口。InkMarkdown 是 **UIKit-first** Markdown 渲染库；未发布的 v0.0.2 已以独立 SwiftUI adapter product 实现 SwiftUI 支持，发布范围与剩余验证项见 [当前状态](current-status.md) 及 [ADR-008](decisions/ADR-008-swiftui-adapter-architecture.md)。

## 入口索引

| 目标 | 推荐阅读 |
| --- | --- |
| 继续当前任务 | [当前任务摘要](qa/InkMarkdown-current-task-summary-2026-08-28.md) |
| 确认已交付功能 | [当前状态](current-status.md) |
| 排查工程决策原因 | [架构决策 ADR](decisions/README.md) |
| 建立代码库事实基线（技术栈、结构、风险） | [Codebase 证据基线](codebase/README.md) |
| 快速了解项目全貌 | [贡献者文档](contributor-guide/README.md) → [项目概述](contributor-guide/01-overview.md) → [架构设计](contributor-guide/02-architecture.md) |
| 了解 SwiftUI v0.0.2 设计 | [SwiftUI Adapter 总体技术设计](contributor-guide/08-swiftui-adapter-architecture.md) → [ADR-008](decisions/ADR-008-swiftui-adapter-architecture.md) |
| 深入 block identity、状态延续与 promotion | [Block Presentation Continuity](contributor-guide/11-block-presentation-continuity.md) → [ADR-009](decisions/ADR-009-block-presentation-continuity.md) |
| 排查 SwiftUI / UIViewRepresentable 跨框架问题 | [SwiftUI / UIViewRepresentable 踩坑指南](contributor-guide/09-swiftui-uiviewrepresentable-gotchas.md) |
| 运行 SwiftUI ExampleApp | [SwiftUI ExampleApp 指南](contributor-guide/10-swiftui-example-app.md) |
| 修改渲染核心 | [核心原理](contributor-guide/03-principles.md) → [模块详解](contributor-guide/05-modules.md) |
| 查看 v0.0.2 重构审查修复记录 | [2026-08-27 审查修复记录](qa/InkMarkdown-v0.0.2-refactor-review-resolution-2026-08-27.md) |
| 查阅旧工作区审查证据 | [历史审查快照（非当前状态）](qa/InkMarkdown-v0.0.2-refactor-review.md) |
| 对比主流 iOS Markdown 库定位 | [生态 Reference](references/ios-markdown-ecosystem.md) |
| 排查常见问题 | [FAQ](contributor-guide/06-faq.md) |
| ExampleApp 走查 / 已知演示限制 | [ExampleApp 走查 SSOT](qa/example-app-walkthrough-issues.md) |
| 2026-09-02 交互/图片候选验收证据 | [interaction acceptance 2026-09-02](qa/InkMarkdown-interaction-acceptance-2026-09-02.md) |
| 排查 CI / 本机 Xcode 不一致 | [CI 与工具链排坑](contributor-guide/07-ci-and-toolchain-pitfalls.md) |
| 查询 swift-markdown API | [依赖 API 参考](references/README.md) |
| 确认 Markdown 渲染语义 | [渲染语义规范](spec/README.md) |
| 查看后续开发优先级 | [路线图](roadmap.md) |
| 准备 v0.0.2 Release Candidate 或发布 | [v0.0.2 发布清单](release-checklist.md) |

## 文档分层

| 层级 | 职责 | 主要文件 |
| --- | --- | --- |
| 项目约束 | 定位、平台和协作规则 | 根目录 `AGENTS.md` / `CLAUDE.md` |
| 参与开源贡献 | 贡献指南 | [CONTRIBUTING.md](../CONTRIBUTING.md) |
| 版本变更 | 更新日志 | [CHANGELOG.md](../CHANGELOG.md) |
| 当前事实 | 交付产物与现实状态 | [current-status.md](current-status.md)、`Package.swift`、公开 API、测试 |
| 工程证据基线 | 技术栈、目录结构、架构摘要、编码约定、测试方式、风险点 | [codebase/](codebase/README.md) |
| 决策记录 | 方案选型与被否决方案 | [decisions/](decisions/README.md) |
| 开发知识 | 设计细节与修改指南 | [contributor-guide/](contributor-guide/README.md) |
| QA / 走查 | ExampleApp 人工走查 SSOT | [qa/](qa/example-app-walkthrough-issues.md) |
| 行为契约 | Markdown 渲染语义 | [spec/](spec/README.md) |
| 依赖知识 | swift-markdown API 参考 | [references/](references/README.md) |
| 未来计划 | 未交付的后续规划 | [roadmap.md](roadmap.md) |
| 发布门禁 | Release Candidate 与正式发布检查 | [release-checklist.md](release-checklist.md) |

## 按文档类型查找

结合任务导向结构与 Diátaxis 分类：

| 类型 | 入口 | 适用场景 |
| --- | --- | --- |
| How-to | [开发指南](contributor-guide/04-development.md) | 构建、扩展或调试 |
| Explanation | [架构与原理](contributor-guide/02-architecture.md) | 理解设计选择与约束 |
| Reference | [API 速查](references/README.md)、[语义规范](spec/README.md) | 查找类型、参数与行为 |

`current-status.md` 和 `roadmap.md` 用于记录项目事实与后续计划。

出现冲突时的判定规则：

1. 产品定位与决策以 `AGENTS.md` / `CLAUDE.md` 为准。
2. 已交付 API 与平台能力以 `Package.swift`、源码及测试为准。
3. `docs/codebase/` 是工程事实快照；与源码冲突时以源码及测试为准，并更新 codebase。
4. 规范与实现不一致时，需判断是实现缺陷还是规范过时，同步更新对应文件。
5. Roadmap 仅代表计划；未在当前状态与测试中体现的能力不能列为已支持。

## 维护规则

- 功能、平台、依赖或公开 API 变化时，优先更新 [current-status.md](current-status.md)。
- 修改 README 时，同步更新 `README.md` 与 `README.zh-CN.md`。
- 新增渲染行为时，更新 `spec/` 并补充语义测试。
- 新增核心抽象时，更新架构文档、模块地图及 FAQ。
- Apple 文本 API 或外部 Markdown 库公开边界变化时，更新 `references/`。
- 新增文档时，更新对应目录 README 或本入口，避免游离页面。
- 技术栈、依赖、公开入口、测试方式或风险点变化时，更新 [codebase/](codebase/README.md)。
- `Sources/InkMarkdown/Rendering/Components/TABLE_INTEGRATION_GUIDE.md` 使用旧 API，仅作历史参考；接入方式以贡献者指南和公开 API 为准。
