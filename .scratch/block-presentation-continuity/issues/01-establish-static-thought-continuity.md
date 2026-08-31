# 01: 建立静态 Thought 呈现连续性闭环

Status: complete

**What to build:** 让同一静态 SwiftUI 呈现周期中的 Thought 在内容更新和重新渲染后保留用户可见状态，同时允许宿主明确更新初始状态。该切片应建立最小 Block Presentation Continuity reconciliation seam，并让静态场景端到端使用它。

**Blocked by:** None (can start immediately)

- [x] 同一静态 host identity 和 Coordinator 生命周期内，source 变化继续使用同一呈现周期，不使用整篇 source hash 决定周期。
- [x] Thought 首次 caller-supplied state 初始化 live state；用户修改后，普通内容更新不覆盖 live state；caller-supplied state 相对上次明确变化时覆盖 live state。
- [x] continuity module 成为该周期内 Thought live presentation state 的唯一事实源；静态路径不再额外手工复制该状态。
- [x] reconciliation 以不可变 snapshot 输入并产出一次性原子 apply plan；UIKit container 只消费计划，不重新判断状态连续性。
- [x] Markdown renderer 仍只输出语义 block，不新增 presentation cycle、lineage 或 live state 职责。
- [x] 第一条关键链路测试建立可复用 fixture，覆盖 initial state → user mutation → content update → caller override 的静态部分；不为内部 map、具体 UIView identity 或相邻变体增加重复测试。
- [x] 使用现有静态 Example 场景手工确认 Thought 状态连续、caller override 生效且布局无明显回归；不新增 UI automation 或 snapshot test。
- [x] 当前 checkout 的相关构建与聚焦测试通过，并记录实际证据；历史结果或 agent 自报完成不算验收。

执行前读取父 spec、ADR-009 和仓库协作规则，并先检查当前 dirty working tree。若委派 subagent，必须使用无上下文继承模式，并提供包含仓库、范围、依赖、约束、证据和输出契约的完整 brief。

## Comments

- 2026-08-28：新增 `InkBlockPresentationContinuity`，以不可变 snapshot 生成带版本校验的一次性 apply plan。container 只执行 plan operations；begin/complete/abort 将 durable continuity state 的提交与 UIKit 变更绑定。
- 2026-08-28：静态 Coordinator 生命周期持有 cycle identity；source 更新不会生成新 cycle。Thought live state 只由 continuity module 维护，renderer 仍输出语义 block。
- 2026-08-28：Serena 对 continuity、container、coordinator、Thought block 和聚焦测试文件的诊断均为空；相关 tracked diff 通过 `git diff --check`。
- 2026-08-28：XcodeBuildMCP，`InkMarkdown-Package` scheme，iPhone 17 / iOS 26.5：continuity 聚焦测试 1 passed / 0 failed；continuity + P0 gate 11 passed / 0 failed / 1 skipped。
- 2026-08-28：XcodeBuildMCP 构建并启动 ExampleApp；iPad Pro 13-inch (M5) / iOS 26.5 手工确认流式终态 Thought 可展开并折叠，一次键盘/宿主 UI 重渲染后仍为 `已折叠`，布局未见空白或重叠。caller override 的完整 Example 手工项尚未覆盖，因此对应验收框保持未勾选，纳入 Ticket 07 的统一矩阵。
- 未创建 GitHub Issue，未 commit，未 push。
- 2026-08-28 最终验收：同一静态文档更新保持用户折叠态；configuration 页的 caller override 可重新控制状态；新 static host 使用初始状态。相邻正文、代码和表格未见空白或重叠。
