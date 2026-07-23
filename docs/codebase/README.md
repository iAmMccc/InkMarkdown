# Codebase 证据基线（`docs/codebase/`）

本目录记录仓库当前的工程事实，帮助开发者与 Agent 了解代码库结构与规范。

## 与现有文档的边界

| 目录 / 文件 | 角色 | 权威性 |
| --- | --- | --- |
| `docs/codebase/` | 仓库扫描产物：栈、结构、架构摘要、约定、集成、测试、风险 | **工程事实快照**；与源码冲突时以源码/测试为准 |
| [`docs/current-status.md`](../current-status.md) | 产品交付状态、能力矩阵、已知限制 | 交付状态说明 |
| [`docs/contributor-guide/`](../contributor-guide/) | 设计意图、原理、模块地图、开发指南 | 设计原理与修改方法 |
| [`docs/spec/`](../spec/) | Markdown 渲染语义契约 | 渲染规范与标准 |
| [`docs/references/`](../references/) | 三方 API 速查 | 外部依赖接口说明 |
| [`docs/roadmap.md`](../roadmap.md) | 计划 | 未交付功能不写入 codebase |

**规则：**

1. 本目录不重复 `contributor-guide` 的详细说明，只保留带代码证据的简短基线。
2. 架构设计与扩展指南维护在 `contributor-guide/` 和 `spec/` 中。
3. 功能交付状态以 `current-status.md` 与测试为准，本目录仅做引用。
4. 扫描原始数据见 [`.codebase-scan.txt`](.codebase-scan.txt)。

## 文档索引

| 文件 | 内容 |
| --- | --- |
| [STACK.md](STACK.md) | 语言、平台、依赖与构建工具链 |
| [STRUCTURE.md](STRUCTURE.md) | 目录布局与入口 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 分层结构、双通道与流式双缓冲 |
| [CONVENTIONS.md](CONVENTIONS.md) | 命名、注释与扩展约定 |
| [INTEGRATIONS.md](INTEGRATIONS.md) | 外部依赖与宿主集成接口 |
| [TESTING.md](TESTING.md) | 测试框架、分布与验证方法 |
| [CONCERNS.md](CONCERNS.md) | 风险、技术债务与待确认问题 |

## 维护触发条件

出现以下情况时，更新本目录文件：

- `Package.swift` 平台、依赖或 Swift 模式变更
- 公开 Renderer、Configuration 或扩展点变更
- 测试框架或构建验证流程变更
- 出现新的代码热点或新增硬编码限制

基线生成日期见各文件 Evidence 与 `current-status.md`。
