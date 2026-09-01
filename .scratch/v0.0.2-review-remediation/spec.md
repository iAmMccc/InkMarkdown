# v0.0.2 Review Remediation

Status: complete

## Problem Statement

`feat/swiftUI` 的 Block Presentation Continuity 实现已完成主体开发，但后续 code review 发现四条行为关键链路和若干硬性规范、文档证据存在缺口。修复必须落在共享渲染或 adapter seam，不能增加只覆盖当前症状的补丁，也不能把 UIKit renderer 与 SwiftUI presentation lifecycle 混合。

## Requirements

1. [Ticket 01](issues/01-apply-source-filter-once-per-top-level-render.md)：一次顶层渲染只执行一次 `sourceFilter`，包括 Thought 正文、suffix、view 创建与复用。
2. [Ticket 02](issues/02-refresh-mounted-view-after-promoted-environment-update.md)：promotion 后环境变化立即刷新 mounted view。
3. [Ticket 03](issues/03-reconcile-thought-collapsibility-on-reused-view.md)：复用 Thought 完整协调可折叠状态；交互、布局与可访问性通过 ExampleApp 手工验收。
4. [Ticket 04](issues/04-preserve-child-backgrounds-in-thought-attributed-fallback.md)：Thought fallback 只补缺失背景，不覆盖子节点语义。
5. [Ticket 05](issues/05-align-public-api-diagnostics-and-comment-standards.md)：公开文档、DEBUG 诊断、注释和 import 顺序符合仓库规范。
6. [Ticket 06](issues/06-migrate-changed-tests-to-repository-naming-standard.md)：仅机械迁移本分支触及的测试命名。
7. [Ticket 07](issues/07-normalize-changed-code-formatting-and-whitespace.md)：仅做受控格式与 whitespace 清理。
8. [Ticket 08](issues/08-verify-remediation-and-refresh-authoritative-evidence.md)：用当前 checkout 的测试、构建和人工结果同步权威证据。

## Architecture Constraints

- 延续 [Block Presentation Continuity spec](../block-presentation-continuity/spec.md) 与 [ADR-009](../../docs/decisions/ADR-009-block-presentation-continuity.md)；continuity 仍由 SwiftUI adapter 持有。
- raw Markdown 与已执行顶层预处理的源码通过 internal typed seam 区分；不得把 preparation 状态暴露为 public contract。
- 自动化只覆盖数据、状态和调用次数等关键链路；UI 结构与视觉通过 ExampleApp 手工检查。
- 保持 `0.0.1` public API 源兼容、iOS/iPadOS 14 目标和 Swift 5 language mode。

## Verification

- 运行 sourceFilter、Thought scanner、背景与 render-session environment 等数据/状态关键路径聚焦测试；Thought reuse 的 UI 行为使用 ExampleApp 手工检查。
- 在 iOS Simulator destination 构建并运行 package 测试；记录实际数量和失败摘要。
- `git diff --check` 必须通过；运行时和人工证据不能仅由 agent 完成声明代替。

## Out of Scope

- 重审整个 `main...HEAD`、重开已拒绝的 ExampleApp scope creep；
- 新增 UI automation、snapshot 或排列矩阵；
- 宣布 iOS/iPadOS 14–15、完整可访问性或真机性能已经交付。

## Comments

- 2026-08-31：follow-up code review 的 1 个 P1、3 个硬规范项与 2 个 Fowler 判断项已修复。iPhone 16 Pro / iOS 18.5 全量测试共 337 项，336 通过、0 失败、1 跳过；ExampleApp 构建通过。一次全量运行出现 2 个 Mermaid/WebKit 超时；对应套件单独复跑 10/10 通过，随后全量复跑恢复为上述绿色结果。
- 2026-08-31：独立终审追加发现的 handler preparation 边界、双语公开文档、target 回归断言与 UI 证据漂移均已关闭；最终 checkout 已重新完成三条 ExampleApp 实走链路。
- 2026-08-31：按最终测试策略删除 36 个 UI、重复边界与入口排列测试；保留数据、状态、调用次数及渲染语义关键链路。聚焦测试 20/20 与 sourceFilter 定向测试通过；全量共 301 项，300 通过、0 失败、1 跳过。
