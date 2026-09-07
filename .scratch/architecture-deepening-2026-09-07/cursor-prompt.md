# Cursor 执行 prompt

建议每批使用一个新会话，按顺序执行：`01–09`、`10–17`、`18–26`、`27`。将下面的“本次授权范围”替换为对应批次，再将整个代码块复制到 Cursor Agent。也可以填单个编号。批次之间先查看上一批的验收与阻塞记录。

本文件是供用户发送给 Cursor 的指令模板；生成本文件没有启动实施。发送后，其中明确的实施授权覆盖旧规划文件中的“未授权”说明，但不代表前置依赖已完成。

```text
请在当前 InkMarkdown 仓库使用实际已安装的 Matt skills，实施已有架构 tickets。

工作目录：/Users/shizihan/DailyUse/Github/InkMarkdown
规划目录：/Users/shizihan/DailyUse/Github/InkMarkdown/.scratch/architecture-deepening-2026-09-07
本次授权范围：01–09

【授权与执行方式】
本次明确授权实现上述范围的 tickets、必要回归测试、相关构建和验收，以及更新本地 ticket 与证据文档。请直接执行到本批完成；不要仅输出计划，也不要在每张票后重新索要批准。旧规划中的“Implementation authorization: 未授权”是生成时的历史状态，本条指令提供本批实施授权。

逐票串行推进，同一时间只实施一张票。完成并验证当前票后，继续范围内下一张依赖已满足的票。不要一次实现整批再补测试和证据；不要跳过依赖；不要实施范围外票。未授权 commit、push、PR、发布、外发消息或另起并行代理。

【先确定输入与环境】
1. 阅读仓库 AGENTS.md，以及规划目录的 tickets.md、execution-guide.md。按需读取 docs/agents/issue-tracker.md 和 docs/agents/triage-labels.md。
2. 查看当前 branch、HEAD、git status，以及本批相关文件已有 diff。规划基线 feat/swiftUI / ee049f0 仅供定位，不要求退回该提交。保留其他任务改动；不要切分支、另建 worktree、reset、stash 或清理工作树。
3. 当前票开始前，阅读票全文、父 spec.md、对应 table-spec.md / image-spec.md / session-spec.md。核对 Blocked by 的 Acceptance 和真实证据，不能只看状态或执行者总结。
4. 计划新建的文件可能已由前置工作创建，先检查再修改。源码发生漂移时按符号和调用关系定位；不要机械套用旧行号或覆盖已有实现。

【如何使用 Matt skills】
先查看 Cursor 当前可用的 skills 清单和相关 SKILL.md，按实际名称与内容选用，不猜命令，也不假装已调用。仅加载本票需要的 skill。
- 已有 spec 和 tickets 是实施输入；不要默认重新执行 to-spec、to-tickets 或重新审查整个仓库。
- 如果存在 ticket 实施类 skill，先读其适用范围；采用其中与本地 Markdown tracker 兼容的流程。不得因此把票发布到外部 tracker。
- 如果存在 tdd，行为变更采用小步 red-green-refactor：一个可观察行为、一个有意义的失败、最小实现、验证后重构。纯基线/证据/文档票按票要求执行，不强造测试。
- 如果存在 codebase-design，用它核对模块边界与 caller knowledge；不借此扩大设计范围。
- 如果存在 code-review，用于当前票的真实 diff 自查。存在缺陷诊断 skill 时，在原因不明的失败中按需使用。
- 没有对应 skill 时，明确说明一次，继续按票和仓库流程实施；不安装或下载新 skills，不把工具缺失误写成产品 needs-info。
用户的本批实施授权持续有效；skill 中的常规确认流程不能让已经授权的实施停在方案阶段。若宿主限制确实阻止必要动作，记录具体动作、限制和影响，不绕过限制。

【每张票的执行循环】
A. 简短说明：当前票编号、Outcome、前置证据、准备改变的职责边界。
B. 阅读实际调用链和相邻消费者，找到唯一状态所有者。按票 Steps 和 Acceptance IDs 列出本票检查项，不另造整批设计。
C. 执行票要求的基线/回归验证，再完成 expand、migrate 或 contract 对应改动。测试先行票若明确交付预期失败证据，应按票标准记录，不能把预期失败说成通过；若票要求测试通过，则不能携带失败继续。
D. 运行适用验证，修复本票引入的问题。自查真实 diff：是否遗漏消费者、重复保存状态、改变公开契约、引入旧回调重入/释放问题。
E. 对照 Acceptance 逐项写证据。满足才勾选；未执行、失败、跳过均如实保留。更新本票 Comments 和指定 evidence 文件，再继续下一张票。

【三个方向必须守住的边界】
具体规则以对应 spec 和票为准，以下是容易误做的重点：
- 表格：原文与 prepared source 绑定为单元格输入；集中接纳、测量、列宽失效。referenceRows 只参与测量，不能进入可见行、rowCount 或复制结果。保留流式追加快速检查，不能每次重建全部历史。
- 图片：共享的是呈现订阅生命周期。保留 InkImageStore 的调度、缓存和资源所有权；保留 attachment materialization identity、preview controller generation 和显式 bypassStore 分支。特别验证 pending/completion 同步重入、旧结果、取消及 async continuation 只终结一次。
- 宿主：集中 Coordinator 的流式接管协调，保留 Session canonical source/phase、continuity 的 live state/token 权威和既有延迟发布语义。不得创造第二份 ownership 状态机；旧宿主不能清除新宿主绑定，释放后最后唤醒等待者。
- 保持 UIKit-first、独立 SwiftUI adapter、Markup 直渲染、现有 public/SPI surface、actor isolation、availability、deployment target 和依赖 pin。
- 迁移期临时代码必须明确归属后续清理票；08、16、25 的交付包括删除旧协调路径。仅移动代码、缩短文件而让调用者继续维护同样的顺序与状态，不算完成架构目标。

【验证与证据】
按 execution-guide.md 选择最小有效验证组，并完成当前票的全部适用要求。测试使用 iOS Simulator；scheme、destination 和 test identifier 以实际发现为准。0 tests 不能算通过，不能把文件名猜成 suite 名。

异步回归使用 controlled loader 或有界事件/runloop；不要用真网或固定长 sleep 证明竞态正确。不要为了测试暴露新的 public 接口，不要断言私有 token/字典替代行为验收。

记录实际 branch/HEAD、未提交 diff 范围、命令或 MCP 参数、scheme/destination、数量、log/xcresult 路径，以及 Acceptance ID 对应证据。已有测试只有仍适用于当前候选时才复用；相关源码改变后重新验证受影响行为。不要复制历史测试数字。

构建、安装启动、实际交互与远程 CI 分别记录。无法执行的检查标记未验证；不能以编译通过代替交互。工具缺失时按仓库规则使用可用 fallback；没有权限/环境完成必要验收时保留阻塞，不能降低测试期待或修改依赖配置伪造通过。

【遇到问题】
常规内部实现选择自行解决，不逐项提问。若发现公共契约或 ADR 冲突，说明冲突、影响和需要决定的唯一问题，仅暂停受影响票及其依赖；本批其他独立且依赖满足的票可以继续。

失败先区分环境、既有问题、预期 red、本票回归。记录实际错误和已尝试的修复，不把所有失败统一标成 needs-info。不能以“后续处理”跳过本票必须满足的 Acceptance。

不要把 ready-for-agent 改成自创的 done，或混用其他 workflow 的 claimed/resolved。按本地 tracker 规则记录状态，完成证据写入 Acceptance、Comments 和 evidence。

【持续交接与本批结束】
每票完成或阻塞时，在规划目录 evidence/cursor-progress.md 更新简短进度：本次授权范围、当前 branch/HEAD、已完成票及证据、当前票、阻塞、下一张可执行票、临时代码归属。会话恢复时先核对这些记录与当前源码，不从头重做，也不把记录当成无需核验的事实。

本批完成或无法继续时，汇报：
1. 各票完成/阻塞/未开始情况。
2. 实际职责变化和关键修改文件。
3. 验证结果与证据路径，明确未验证项。
4. 遗留过渡代码及对应清理票。
5. 下一批建议入口。
到达授权范围末尾即停止；不要自动领取范围外票。

现在开始：核对工作树和 skills，读取本批首张依赖满足的票，随后实施并验证。
```
