# 07: 统一本分支格式并清除 whitespace

Status: ready-for-agent

## Summary

对本分支修改的 Swift、测试和 ExampleApp 源码执行受控的机械格式清理：统一 2 空格缩进并移除 trailing whitespace，同时保持行为、资源和生成内容不变。

## Context

- Spec: [v0.0.2 Review Remediation](../spec.md)
- Standards: [代码格式与风格](../../../docs/codebase/CONVENTIONS.md#3-代码格式与风格)
- Scope: [Package.swift](../../../Package.swift)、[ExampleApp](../../../ExampleApp/ExampleApp/AppDelegate.swift)

Blocked by: 05, 06.

## Acceptance

- [x] `main...HEAD` 范围内修改的可执行 Swift 源码与测试统一使用 2 空格缩进。
- [x] ExampleApp 本分支修改的 Swift 源码完成同样的缩进收口；不机械改写资源、第三方产物或嵌入内容语义。
- [x] 所有被追踪文本文件清除 trailing whitespace，最终 `git diff --check main...HEAD` 通过。
- [x] 格式化 diff 不改变标识符、控制流、字符串内容、测试断言或公开 API。
- [x] InkMarkdown package 与 ExampleApp 在 iOS Simulator destination 上保持可构建。
- [x] 如委派给 subagent，必须使用不继承主 agent 上下文的独立会话；本票正文是其唯一任务上下文。

## Comments

- 2026-08-31：实现完成。`git diff --check` 对 remediation 基线和 `main` 均通过；纯格式 Example 文件的 whitespace-insensitive diff 为空，Package 与 ExampleApp 构建通过。
