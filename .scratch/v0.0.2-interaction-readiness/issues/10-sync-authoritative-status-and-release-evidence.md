# 10: 同步当前事实与发布证据

**What to build:** 将已完成实现、当前候选验证结果、仍存在的 release blocker 和明确的不支持边界同步到项目权威文档与本地证据。读者应能区分已发布 `0.0.1`、本地 v0.0.2 候选事实、未来工作和尚未执行的远端门禁。

**Blocked by:** 09 / 执行候选集成验证与独立复审。

**Status:** partial (2026-09-02) — 权威文档与本地证据已按当前工作树事实更新；ExampleApp 人工矩阵与远端 CI 仍明确未交付。

- [x] README 中英文版对产品范围、图片默认行为、新增配置和限制保持一致。
- [x] 渲染规范、FAQ、CHANGELOG、roadmap、current status 与 release checklist 反映实际完成行为和 ADR-006 决策。（roadmap/release checklist 仍把 ExampleApp 真网与最低版本列为未勾选 blocker）
- [x] 完整 VoiceOver 不再描述为本轮交付项；已有 VoiceOver 行为保留，后续工作与当前支持边界表达准确。
- [x] iOS/iPadOS 14–15 runtime 与真机性能继续作为独立 blocker，不因本 spec 完成而标记为已交付。
- [x] 测试数量、scheme、destination、失败和跳过原因来自当前候选 checkout，删除旧数量与当前事实的漂移。
- [ ] ExampleApp 人工证据包含链接、表格、旋转、Split View、网络图片和环境失败边界。（入口已记录；执行 BLOCKED）
- [x] 文档明确图片真图仍为 opt-in；开启后 host 默认开放，业务 allowlist 可选，图片资源安全边界始终生效。
- [x] 新增文档与证据从现有索引可发现，不包含本机绝对路径、凭据、缓存或构建产物。
- [x] 文档不把本地测试、agent 结论、计划、旧 SHA 或未执行的远端 CI 写成当前远端通过事实。
- [x] 本 ticket 只完成本地文档与证据收口；不 push、不创建 PR、tag 或 GitHub Release。
