# Codebase 证据基线（`docs/codebase/`）

本目录由 `acquire-codebase-knowledge` 工作流生成，描述**可从仓库核验的工程事实**，供 agent 与新贡献者快速建立代码库心智模型。

## 与现有文档的边界

| 目录 / 文件 | 角色 | 权威性 |
| --- | --- | --- |
| `docs/codebase/` | 仓库扫描产物：栈、结构、架构摘要、约定、集成、测试、风险 | **工程事实快照**；与源码冲突时以源码 / 测试为准，并回写本目录 |
| [`docs/current-status.md`](../current-status.md) | 产品交付状态、能力矩阵、已知限制 | **“现在交付了什么”** 的人类可读基线 |
| [`docs/contributor-guide/`](../contributor-guide/) | 设计意图、原理、模块地图、开发 How-to | **为什么这样设计、怎么改** |
| [`docs/spec/`](../spec/) | Markdown 渲染语义契约 | **应渲染成什么** |
| [`docs/references/`](../references/) | 三方 API 速查 | 依赖边界，不描述本库实现 |
| [`docs/roadmap.md`](../roadmap.md) | 计划 | 未交付能力不得写进 codebase 的“已支持” |

**规则：**

1. 本目录**不复制** contributor-guide 的长文解释，只保留可追溯证据的短基线。
2. 深度设计与扩展指南仍写在 `contributor-guide/` / `spec/`。
3. 能力是否已交付，以 `current-status.md` + 测试为准；本目录引用它们，不另立第二真相。
4. 扫描原始输出见 [`.codebase-scan.txt`](.codebase-scan.txt)（机器产物，可不手改）。

## 七件套

| 文件 | 内容 |
| --- | --- |
| [STACK.md](STACK.md) | 语言、平台、依赖、构建工具链 |
| [STRUCTURE.md](STRUCTURE.md) | 目录布局与入口 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 分层、双通道、流式双缓冲 |
| [CONVENTIONS.md](CONVENTIONS.md) | 命名、注释、扩展约定 |
| [INTEGRATIONS.md](INTEGRATIONS.md) | 外部依赖与宿主集成面 |
| [TESTING.md](TESTING.md) | 测试框架、分布与验证方式 |
| [CONCERNS.md](CONCERNS.md) | 风险、债务、漂移、待确认问题 |

## 维护触发

出现以下变化时，应重扫并更新本目录（至少相关文件）：

- `Package.swift` 平台 / 依赖 / Swift 模式变化
- 公开 Renderer / Configuration / 自定义扩展点变化
- 测试框架或验证命令变化
- 发现新的高 churn 热点或硬编码限制

基线生成日期见各文件 Evidence 与 `current-status.md` 对齐说明。
