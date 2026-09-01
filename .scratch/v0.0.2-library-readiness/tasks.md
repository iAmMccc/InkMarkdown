# v0.0.2 Library Readiness Tasks

## Baseline

- [x] 审计并保护当前工作树。
- [x] 确认稳定基线 `a9fc7cb`，工作树干净。
- [x] 建立本地 spec 与证据目录。

## Parallel tracks

- [ ] A：CI、四 product 消费者接入、ExampleApp build。
- [ ] B：README/CHANGELOG/CONTRIBUTING、开源协作资产。
- [ ] C：`0.0.1` 公开 interface 对比、深度审计、错误契约。
- [ ] D：Simulator/runtime 盘点、ExampleApp 人工矩阵、性能证据。

## Integration

- [ ] 集成各轨改动并更新权威状态文档。
- [ ] 完成本地构建、关键测试、全量测试与消费者冒烟。
- [ ] 完成 ExampleApp 手工验收。
- [ ] 完成独立 Standards 与 Spec 审查。
- [ ] 修复确认问题并重跑受影响验证。
- [ ] 按功能提交、推送、创建或更新 PR、等待 CI。

## External decisions

- [ ] iOS/iPadOS 14 runtime 不可用时，由维护者决定继续寻找验证环境或调整最低版本。
- [ ] 仓库无已确认私密安全报告渠道时，由维护者选择渠道后再提交 SECURITY.md。
