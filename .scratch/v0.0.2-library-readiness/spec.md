# InkMarkdown v0.0.2 Library Readiness

Status: in-progress

## Objective

将当前 `feat/swiftUI` 分支推进到可复现、可审查的 v0.0.2 Release Candidate。范围覆盖发布工程、消费者接入、公开 interface、文档、开源协作资产、兼容性与验证证据；不创建 tag、Release 或合并 PR。

## Sources of truth

1. `AGENTS.md`
2. `docs/qa/InkMarkdown-current-task-summary-2026-08-28.md`
3. `docs/current-status.md`
4. `docs/roadmap.md`
5. 当前源码、测试和最新结构化验证结果
6. `0.0.1` tag 的已发布公开 interface

## Required outcomes

- CI 分离 Core、SwiftUI adapter、optional addons 与 ExampleApp/consumer build，当前候选 SHA 的必要任务全部通过。
- 普通消费者可分别导入四个 product；Core 不被迫链接 iosMath 或 Mermaid 资源。
- 中英文 README 示例与当前源码一致；CHANGELOG、CONTRIBUTING 与权威状态文档无事实漂移。
- 对比 `0.0.1` 完成公开 interface 审计；保留已发布源兼容性，安全收敛未发布的内部类型。
- 流式上限、生命周期和 addon 失败具备明确、可观察、可文档化的结果。
- 完成可用 Simulator 上的 iPhone/iPad 与 ExampleApp 人工矩阵；最低系统无运行环境时保留真实 blocker，不自动提高 deployment target。
- 补齐必要开源协作资产；SECURITY 只使用已确认可用的私密报告渠道。
- 自动化测试只覆盖数据、状态、语义、调用次数、消费者接入和关键业务链路；UI 通过 ExampleApp 手工验收。
- 独立 Standards 与 Spec 审查无未解决 P1/P2。

## Non-goals

- Native SwiftUI renderer、InkIR、Transformer、TextKit 2 或新平台支持。
- UI 自动化、视觉快照扩张或非核心路径单测。
- 自动提高最低系统版本。
- 合并 PR、创建 tag 或发布 Release。

## Delivery

改动按功能粒度提交。最终推送 `feat/swiftUI`，创建或更新指向 `main` 的 PR，等待同一 SHA 的必要 CI 结果。
