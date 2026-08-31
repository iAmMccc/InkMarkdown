# 08: 完成集成验证并同步权威证据

Status: ready-for-agent

## Summary

对全部 review remediation 进行集成验证，并只依据当前 checkout 的实际结果更新权威状态文档。完成后，维护者能够区分已修复缺陷、已通过证据和仍未完成的 v0.0.2 release blockers。

## Context

Blocked by: 07.

## Acceptance

- [x] 使用 XcodeBuildMCP 发现实际 scheme 与 iOS Simulator destination，运行四条修复链路的聚焦测试、全量 package 测试和 ExampleApp 构建，记录测试总数、通过、失败与跳过数量。
- [x] 使用 ExampleApp 手工检查 Thought 卡片范围与 inline code 背景、可折叠能力切换，以及 promotion 后环境变化的即时刷新；不新增 UI automation 或 snapshot tests。
- [x] 当前任务摘要修正为实际 commit/worktree 状态、最新测试证据和 `git diff --check` 结果，不继续保留“未提交”或旧测试数量等漂移事实。
- [x] 核心原理文档修正删除线测试状态；架构文档明确 swift-markdown 的基础 Markdown AST 边界与自定义扩展语法 scanner seam，不把允许的扩展误写为第二套 Markdown parser。
- [x] 编码规范中的诊断/日志策略与最终实现一致；若 README 核心信息发生变化，必须同步更新中英文版本。
- [x] 使用无继承上下文的 `gpt-5.6-sol max` reviewer subagents，分别完成 Standards 与 Spec 审查；先检查 remediation range，再复核 `main...HEAD`，确认 1 个 P1、3 个 P2 和硬性规范/文档漂移均已关闭。
- [x] Fowler smells 只作为判断项记录接受、修复或延期理由；已拒绝的 ExampleApp scope-creep finding 不重新纳入范围。
- [x] iOS/iPadOS 14–15、完整可访问性与真机性能若仍未验证，必须继续标为独立 release blockers，不能写成已交付。
- [x] 如委派执行工作，所有 subagents 必须使用不继承主 agent 上下文的独立会话；agent 自报完成不替代当前 checkout 验证。

## Comments

- 2026-08-31：XcodeBuildMCP 在 iPhone 16 Pro / iOS 18.5 完成聚焦 60/60、全量 335 通过/0 失败/1 跳过；ExampleApp 构建、安装、启动与三条手工链路通过。
- 2026-08-31：Spec 轴 `gpt-5.6-sol max` 终审 PASS、无 P1/P2。Standards 轴仅发现 ticket tracker 格式 P2；按 `Status:`、Summary、Context、Acceptance、Comments 规范修复后，定向复核 PASS。
- 2026-08-31：Fowler smells 判断：prepared-source seam、缺失背景回填与 presentation-environment dirty slot 位于现有共享边界，接受；已拒绝的 ExampleApp scope-creep 不重启。iOS/iPadOS 14–15、完整可访问性和真机性能继续作为独立 release blockers。
