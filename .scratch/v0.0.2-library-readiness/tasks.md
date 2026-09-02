# v0.0.2 Library Readiness Tasks

## Baseline

- [x] 审计并保护当前工作树。
- [x] 确认稳定基线 `a9fc7cb`，工作树干净。
- [x] 建立本地 spec 与证据目录。

## Parallel tracks

- [x] A：CI、四 product 消费者接入、ExampleApp build。
- [x] B：README/CHANGELOG/CONTRIBUTING、发布清单与开源协作资产。
- [x] C：`0.0.1` 公开 interface 对比、深度审计、错误契约。
- [x] D：可用 Simulator/runtime 盘点与 ExampleApp 人工矩阵；最低系统、真机性能及完整可访问性保留真实 blocker。

## Integration

- [x] 集成各轨改动并更新权威状态文档。
- [x] 完成本地构建、关键测试、全量测试与消费者冒烟。
- [x] 完成 ExampleApp 手工验收。
- [x] 完成独立 Standards 与 Spec 审查。
- [x] 修复确认问题并重跑受影响验证；私密披露渠道属于需 maintainer 授权的外部决策，文档不虚构已可用。
- [x] 按功能完成本地提交。
- [ ] 推送、创建或更新 PR、等待同一 SHA 的必要 CI；按维护者要求延期。

## External decisions

- [ ] iOS/iPadOS 14 runtime 不可用时，由维护者决定继续寻找验证环境或调整最低版本。
- [ ] 仓库无已确认私密安全报告渠道时，由维护者选择渠道后再提交 SECURITY.md。
