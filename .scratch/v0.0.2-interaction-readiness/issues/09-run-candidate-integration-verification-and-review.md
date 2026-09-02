# 09: 执行候选集成验证与独立复审

**What to build:** 对完成前八个 tickets 的同一候选 checkout 执行聚焦与全量验证，并由独立审查代理复核仓库规范和本 spec。只有当前候选的构建、关键测试和人工证据均成立，且确认的 P1/P2 已解决，才能进入文档收口。

**Blocked by:** 08 / 完成 ExampleApp 跨功能人工验收。

**Status:** partial (2026-09-02) — Package 全量本地通过；不继承主上下文的 Standards / Spec 独立审查已完成，确认问题已按共享边界修复并重跑验证；ExampleApp 构建与完整人工证据仍 BLOCKED。证据：`docs/qa/InkMarkdown-interaction-acceptance-2026-09-02.md`

- [x] 工作树目标改动范围清楚，`git diff --check` 通过，不包含缓存、DerivedData、凭据或无关用户修改。
- [x] 使用 XcodeBuildMCP 发现当前可用 scheme 与 iOS Simulator destination；MCP 不可用时按仓库规则完成安装/注册排查后才使用原生命令。
- [x] canonical corpus、列表、表格、链接、measurement、图片策略、网络预算、取消与缓存隔离聚焦关键测试通过。
- [x] `InkMarkdown-Package` 全量测试通过；记录实际 scheme、destination、逻辑测试数量、失败与跳过原因。
- [ ] 受影响的外部消费者与 ExampleApp Debug/Release 构建通过。
- [x] 自动化范围遵守硬性测试约束；发现重复、UI-only、非核心或内部实现测试时合并或删除，不新增补丁式测试。
- [x] Standards 与 Spec 审查分别由不继承主上下文的独立代理执行。
- [x] 审查代理 prompt 自包含仓库路径、spec/ADR、范围、证据要求和只读输出合同。
- [x] 所有确认的 P1/P2 已在共享策略、并发状态、缓存 identity / generation 与 canonical corpus seam 修复，并重新验证；低优先级建议未扩张本 spec。
- [x] 不 push、不创建或更新 Pull Request，不把本地验证写成远端 CI 事实。
