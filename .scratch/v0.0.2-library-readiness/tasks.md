# v0.0.2 Library Readiness Tasks

> 状态模型：`Baseline` / `Implementation tracks` 只记录历史起点与实现接入；`Current candidate gates` 才表示当前工作树验收。当前候选身份、日期和门禁证据统一以 [`docs/qa/InkMarkdown-interaction-acceptance-2026-09-02.md`](../../docs/qa/InkMarkdown-interaction-acceptance-2026-09-02.md) 为 SSOT。

## Baseline

- [x] 任务启动时审计并保护工作树。
- [x] 任务启动时确认稳定基线 `a9fc7cb`；此项仅记录历史起点，不描述当前工作树。
- [x] 建立本地 spec 与证据目录。

## Implementation tracks（历史实现接入）

- [x] A：CI job、四 product 消费者与 ExampleApp build wiring 已接入。（不表示当前候选已通过消费者 / ExampleApp build）
- [x] B：README/CHANGELOG/CONTRIBUTING、发布清单与开源协作资产。
- [x] C：`0.0.1` 公开 interface 对比、深度审计、错误契约。
- [x] D：完成可用 Simulator/runtime 盘点、ExampleApp 人工矩阵定义与入口准备；最低系统、当前候选人工执行、真机性能及完整可访问性保留真实 blocker。

## Current candidate gates（2026-09-02 工作树）

- [x] 集成各轨改动并更新权威状态文档。
- [ ] 完成同一候选的本地构建、关键测试、全量测试与消费者冒烟。（Package：333 通过、0 失败、1 跳过；ExampleApp / 外部消费者仍未完成当前候选验证）
- [ ] 完成 ExampleApp 手工验收。（依赖解析受失效代理阻塞，未构建安装）
- [x] 完成独立 Standards 与 Spec 审查。
- [x] 修复确认问题并重跑受影响验证；私密披露渠道属于需 maintainer 授权的外部决策，文档不虚构已可用。
- [x] 按功能完成本地提交。（text / image 06-07 / corpus harness / ExampleApp 08 / docs 09-10）
- [ ] 推送、创建或更新 PR、等待同一 SHA 的必要 CI；按维护者要求延期。

## External decisions

- [ ] iOS/iPadOS 14 runtime 不可用时，由维护者决定继续寻找验证环境或调整最低版本。
- [ ] 仓库无已确认私密安全报告渠道时，由维护者选择渠道后再提交 SECURITY.md。
