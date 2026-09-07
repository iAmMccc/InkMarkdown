# Agent 指令体系重构记录

日期：2026-09-07。范围：InkMarkdown 项目入口、个人全局 AGENTS.md，以及直接影响规划、实施、审查和指令维护的个人 skills。仅修改文档与指令，没有修改业务代码或模型配置。

## 依据与来源限制

已通过 OpenAI Docs MCP 读取 [GPT-6 Astra 官方指南](https://developers.openai.com/api/docs/guides/latest-model#gpt-6-astra-testing-and-verification)。其提示词章节指出：检查 AGENTS.md / skills 的隐性冲突，明确任务持续性与权限边界，控制响应风格，并使测试范围与实际改动相称。本次没有照搬官方示例中的自动建 worktree 或广泛代理委派，而是结合当前项目约束选择行为。

已读取 [Codex skills](https://developers.openai.com/codex/skills/) 与 [AGENTS.md 发现规则](https://developers.openai.com/codex/guides/agents-md/)，用于核对显式调用策略与指令层级。

用户给出的 [Eric Provencher 原文](https://x.com/pvncher/status/2095991462416490862) 经网页抓取返回 403，浏览器读取超时。已读到标注原文地址的[中文转载](https://www.jxxy.net/ai/articles/pvncher-2095991462416490862/)，但未独立核对英文全文。转载提出缩短描述、按需披露和减少固定流程；本次技术规则以已读取的官方文档为依据，不将转载当作官方规范。

## 已实施

| 位置 | 调整 |
| --- | --- |
| 项目 AGENTS.md | 从 17,877 bytes 缩减为 4,131 bytes（约 77%）；保留产品边界，删除目录树、历史结果及重复工具教程 |
| 项目 CLAUDE.md | 改为指向 AGENTS.md 的单一规则入口 |
| docs/agents/tooling.md | 按代码查询、知识查询、构建和验证分支加载；工具不可用时允许说明后降级 |
| docs/agents/domain.md | 领域文档改为按任务触发，不要求任何探索前都加载 |
| 个人全局 AGENTS.md | 统一授权延续、skill 优先级与验证停止条件；保留用户简洁风格 |
| implement | 新增测试权限不再等价于强制 TDD；实施覆盖适用验证 |
| implement-spec | 按依赖图实施；取消固定建 PR、分支、多 worktree 和最大并发；保留整合验收 |
| to-spec | 移除“不采访却确认测试 seam”的冲突；未知决策明确记录为 needs-info |
| to-tickets | 直接产出本地小 tickets；移除固定审批轮次，保留依赖和授权边界 |
| code-review | 聚焦可证实的问题，按严重度去重汇总；代码气味不再自动变成修改任务 |
| spm-local | 仅离线需求或网络故障触发；保留远程 revision pin，明确临时覆盖边界 |
| writing-for-agents | 缩短主体，更新 Codex 调用策略说明，要求区分静态校验与行为实测 |

个人 skills 位于 `~/.codex/skills/`；本机 `~/.agents/skills` 是它的符号链接，因此无需维护第二份。未修改插件缓存或系统内置 skills。deep-discuss 与 diagnosing-bugs 已有按范围推进、证据和验证边界，本次保留。其他个人 skills 仅做入口模式筛查，未进行全体系逐文件行为审计。

## 静态验收

以下是对新指令的人工场景推演，不是模型运行实验：

| 输入场景 | 新规则期望 |
| --- | --- |
| 改文档拼写 | 直接修改并检查差异，不初始化 Xcode 或读取全部 ADR |
| 分析并修复行为缺陷 | 调查、修复、相关验证连续完成，不等待第二次开工批准 |
| 只讨论架构 | 产出结论和真实待决问题，不实施业务代码 |
| 将明确方案拆成 tickets | 直接写本地文件、验收项及依赖，不强制采访 |
| spec 存在未决公共契约 | 标记 needs-info，继续不依赖该决策的已授权工作 |
| 更新远程 SPM pin | 不自动触发本地依赖改造 |
| MCP 未暴露 | 区分能力缺失并使用有依据的回退，不强制安装重载 |
| 小范围改动验证通过 | 完成任务，不自动扩大到全量测试 |
| 明确指定 checkout | 保持该 checkout，skill 不自行要求多 worktree |

实际检查：7 个修改的 SKILL.md frontmatter 和修改的 openai.yaml 通过 YAML 解析；14 个本地 Markdown 引用均存在；4 个实施/规划 skills 保持 Codex explicit-only policy；项目与全局不存在 AGENTS.override.md 遮蔽；git diff --check 通过。仅文档变更，未执行 App 构建、测试、运行或远程 CI。

## 生效与限制

个人全局文件影响其他仓库，项目文件只约束 InkMarkdown。当前任务已经读入旧指令；在新任务或重启会话后确认新入口加载，不宣称本轮工具校验等于未来模型行为已经改善。未修改宿主权限，也未更改模型、reasoning effort 或插件注册。

仓库文件可通过 Git diff 审阅；个人文件不属于本仓库 Git diff，单独保留了本轮修改前快照及 unified diff。未执行 commit 或 push。
