# 给后续执行模型的完整交接 prompt

以下 prompt 可以直接复制。将 `NN-...md` 替换为 tickets.md 中具体票文件名；一次只给一个未被依赖阻塞的票。若用户希望连续实施，需要在发送时明确列出授权票范围。

```text
请实施 InkMarkdown 的指定 ticket，不扩展到其他票。

工作目录：/Users/shizihan/DailyUse/Github/InkMarkdown
指定 ticket：.scratch/architecture-deepening-2026-09-07/issues/NN-...md
本次授权：实现该票及其必要验证；不自动授权 commit、push、PR、发布或后续票。

先阅读：
1. 工作目录根 AGENTS.md。
2. 指定 ticket，以及它链接的 parent spec、direction spec。
3. .scratch/architecture-deepening-2026-09-07/execution-guide.md。
4. Blocked by 所列前置票的实际完成证据；未完成则不要跳过依赖。

规划基线是 feat/swiftUI / ee049f0，但可能已过时。先核对当前 branch、HEAD、git status 和本票涉及文件的 diff。保留其他任务改动，不 checkout/reset/stash/清理工作树，不切到别的 worktree。计划新文件可能已被前置票创建，先读再改。

按票的 Outcome、步骤、Acceptance IDs 实施。规格是默认设计，不是现成源码。新类型、状态和 helper 仅在内部；不增加 public/SPI surface，不改变原 actor isolation、iOS 15 deployment target、依赖 pin 或 SwiftUI/UIKit 所有权。

测试必须能区分正确行为和回归。使用真实生产 module interface，不断言私有 token/字典；异步使用 controlled loader 或有界 runloop/probe，不使用真网/固定长 sleep。运行 iOS Simulator 测试，按当前工具/测试发现结果选择真实 scheme、destination 和 test identifier；0 tests 不算通过。

完成本票必须：
- 提供实际修改文件与职责变化。
- 对每条 Acceptance 给出真实证据；未执行/失败保留未勾选。
- 在指定 evidence 路径记录 SHA+diff、命令、scheme/destination、通过/失败/跳过、log/xcresult。
- 说明本票完成了 expand、migrate 还是 contract，列出后续票仍需删除的临时代码。
- 区分构建、安装启动、交互、远程 CI；不复制历史通过数字。
- 只在真实完成后更新本票 Acceptance 与 Comments；ready 状态本身不是完成证据。

如果发现公共契约/ADR 冲突，写清冲突和所需决定，仅停受影响部分；如果是环境故障，记录具体阻塞，不改测试期待或 manifest 伪造通过。报告后停止，不自动实施下一票。
```

## 建议分派顺序

先 01。表格从 02、图片从 10、宿主从 18 分别推进；依赖以 tickets.md 为准。较弱模型建议按编号串行完成一个方向后再开始下一个方向，避免跨任务同时编辑同文件。

## 给整合/复查模型的检查要点

1. 读真实 diff 与证据，不只读执行者总结。
2. 检查三类需要消失的 caller knowledge：表格的平行来源/列宽规则，图片的重复订阅状态，Coordinator 的流式接管顺序。
3. 检查应该保留的状态：attachment 的 materialization identity、preview 的 controller generation、Session canonical source/phase、continuity live state/token。
4. 检查没有通过更大 interface、新 public 协议或第二份状态机换取“文件变短”。
5. 把新失败归因到实际代码路径；测试/构建/交互/远程 CI 分开判断。
