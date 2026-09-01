# 06: 机械迁移本分支测试命名规范

Status: ready-for-agent

## Summary

将 `main...HEAD` 范围内新增或修改的测试方法统一迁移到仓库规定的 `domain_behavior` 或 `component_expectation` 命名，不改变测试覆盖、断言或产品行为。

## Context

- Spec: [v0.0.2 Review Remediation](../spec.md)
- Standards: [测试命名规范](../../../docs/codebase/CONVENTIONS.md#1-命名规范)
- Source: [InkMarkdownTests](../../../Tests/InkMarkdownTests/InkMarkdownTests.swift)、[InkMarkdownSwiftUITests](../../../Tests/InkMarkdownSwiftUITests/InkMarkdownViewTests.swift)

Blocked by: 01, 02, 03, 04.

## Acceptance

- [x] 本分支新增或修改的测试方法全部符合 `domain_behavior` 或 `component_expectation` 命名。
- [x] 保留现有 Swift Testing 展示名称、断言、fixture、等待条件和 actor 隔离；不新增或删除测试用例。
- [x] 不扩张到 `main` 基线中未被本分支触及的历史命名债务。
- [x] 测试发现数量与迁移前一致；聚焦测试和全量测试仍可执行。
- [x] 该票按机械重命名处理，不夹带测试重构、helper 抽象或新的覆盖矩阵。
- [x] 如委派给 subagent，必须使用不继承主 agent 上下文的独立会话；本票正文是其唯一任务上下文。

## Comments

- 2026-08-31：实现完成。机械改名保持断言与 fixture 不变；分支仅因 Tickets 01–04 净增四条关键测试，全量测试 335 通过/0 失败/1 跳过。
