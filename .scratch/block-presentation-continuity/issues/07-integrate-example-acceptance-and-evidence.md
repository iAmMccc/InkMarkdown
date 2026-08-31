# 07: 完成 Example 验收与交付证据

Status: complete

**What to build:** 将完整 Block Presentation Continuity 行为作为一个可核验交付收口：通过现有 Example 场景人工验证用户体验，通过受控的关键链路测试和当前构建证明业务状态正确，并只在证据成立后更新当前状态。

**Blocked by:** 06: 收缩旧 renderer identity seam

- [x] 在现有 static、configuration、streaming 和 chat Example 场景中完成手工检查，不复制新的顶层 demo catalog。
- [x] 手工覆盖 Thought 内容更新、用户折叠态、caller override、environment/宽度变化、streaming promotion、same-session remount、reset、cancel、新 static host 和 custom fallback。
- [x] 手工确认状态未串块、布局无陈旧高度/空白/重叠、局部 fallback 不影响其他 blocks；不以 UIView 实例相同作为验收标准。
- [x] 使用项目规定的 XcodeBuildMCP 和 iOS Simulator 完成构建及聚焦测试，记录实际 scheme、destination、测试数量和失败摘要。
- [x] 自动化保持三条关键 reconciliation 链路；只保留 continuity seam 无法表达的少量跨 module contract，不新增 UI automation、snapshot 或 exhaustive unit-test matrix。
- [x] 使用现有 profiling workload 或 debug counters 核对更新 locality，没有无关 block 全量重建/重测的明显回归；不把具体 cache-hit、UIView reuse 次数或固定性能数字写成 public contract。
- [x] 核对最低 iOS/iPadOS 14 边界、MainActor 隔离、公开 API 兼容性，以及 ADR-009、技术设计和实现的一致性。
- [x] 仅在构建、关键测试、Example 手工检查和 locality 证据齐备后更新当前状态文档；未通过项继续记为 release blocker，不把计划或 agent 状态写成已交付事实。

执行前读取父 spec、ADR-009 和仓库协作规则，并先检查当前 dirty working tree。若委派 subagent，必须使用无上下文继承模式，并提供包含仓库、范围、依赖、约束、证据和输出契约的完整 brief。

## Comments

- 2026-08-28：XcodeBuildMCP 使用 `InkMarkdown-Package` scheme、iPad Pro 13-inch (M5) / iOS 26.5。最终两批聚焦测试合计 47 passed / 0 failed / 1 skipped；完整回归 332 passed / 0 failed / 1 skipped。跳过项是本机没有 iOS 14 runtime 的 ICS gate。
- 2026-08-28：同一 destination 上重新构建、安装并启动 `ExampleApp`（bundle `Mccc.ExampleApp`）。static、configuration、components、streaming 与 AI SSE/chat 场景完成手工矩阵；最终歧义用例“折叠 A → 删除 A”确认 B 仍展开，画面无空白或重叠。
- 2026-08-28：按问题截图的 AI SSE 用例再次完成“展开 → 折叠 → 再展开”验收：4 行思考内容始终完整位于内层灰色卡片，`</think>` 后正文位于外层回复区；折叠后没有陈旧空白，再展开恢复完整内容。Example host 现在会在首次 display、流式结束和 Thought 交互后重新测量行高，并为 Markdown host 建立确定宽度。
- 2026-08-28：reconciliation 使用 snapshot-wide lookup，更新不再每 candidate 扫描全部 records；连续宽度变化清理旧宽 measurement cache。现有 workload/P0 gate 通过。最低 iOS/iPadOS 14 目标、MainActor 与公开 API 已核对；iOS/iPadOS 14 实际运行仍保留为 release blocker。
- 2026-08-28：上述 host 回流通知落地后再次运行全量 `InkMarkdown-Package` 测试：332 passed / 0 failed / 1 skipped；结果包为 `test_sim_2026-08-28T14-29-00-031Z_pid19761_8b52b5cd.xcresult`。
- 2026-08-28：最终 `gpt-5.6-sol max` 独立审查提出 4 个可复现问题，均已处理：code span 内反斜杠不再误伤合法 backtick closer；零内容流可完成 promotion；异步高度回调使用最后实际测量宽度；PREFIX Thought 改由 core SPI 增量状态机消费 delta，避免每片全文重扫。没有宣称 Thought UIView 的完整 Markdown 重渲染链为线性复杂度。
- 2026-08-28：审查修复采用既有测试函数内的关键链扩展，红灯为 3 tests failed，修复后聚焦 5 passed / 0 failed / 0 skipped；最终全量 332 passed / 0 failed / 1 skipped，结果包为 `test_sim_2026-08-28T15-09-17-162Z_pid19761_e4cb32bc.xcresult`。最新 ExampleApp 再次完成“展开 → 折叠 → 再展开”，结果与问题截图验收标准一致。
- 2026-08-28：修复后第二个 `gpt-5.6-sol max` 无上下文独立复审无可操作 findings；保留的实质风险只有 iOS/iPadOS 14 runtime 未验证，以及增量 scanner 的线性检查不代表完整 UIView Markdown 重渲染链线性。
- 未创建 GitHub Issue，未 commit，未 push。
