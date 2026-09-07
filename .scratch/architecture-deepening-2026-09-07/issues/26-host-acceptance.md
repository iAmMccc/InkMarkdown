# 26：完成宿主接管方向验收与职责文档

Status: done
Blocked by: 25
Implementation authorization: 已由用户授权执行（18–26 批次）。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [session-spec.md](../session-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [25](./25-host-contract-old-plumbing.md)
- Acceptance IDs: S-01, S-02, S-03, S-04, S-05, S-06, S-07, S-08, S-09, S-10, S-11, S-12, S-13, S-14
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

S-01 至 S-14 的证据闭合，文档明确 Session、host 与 continuity 的最终职责。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [docs/contributor-guide/08-swiftui-adapter-architecture.md](../../../docs/contributor-guide/08-swiftui-adapter-architecture.md)
- [docs/contributor-guide/11-block-presentation-continuity.md](../../../docs/contributor-guide/11-block-presentation-continuity.md)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 复核 18–25 的最终候选测试与真实 remount 证据；只重跑被后来代码变更影响的结果。
2. 在 ExampleApp SwiftUI 流式入口验证 append/finish、Thought 展开/折叠、环境变化、退出重入、reset/cancel。
3. 运行现有 workload/loop prevention/source limit 回归，不声称未测得的性能提升。
4. 更新两个相关开发文档的流式宿主接管职责，保持 ADR-008/009 各自所有权不变。
5. 生成 evidence/26-host-acceptance.md，逐项 S-* 映射、runtime 与未验证项。

## Acceptance

- [x] 所有 S-* 有生产路径或真实宿主证据。
- [x] source truth、live presentation state 和 host 资源职责清晰且无重复真相。
- [x] 原有语义/性能计数断言未被放宽以让重构通过。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- session 全组、ExampleApp SwiftUI 流式关键交互。
- 检查文档和公共声明对照，不能用旧审查的手工结果替代。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/26-host-acceptance.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不在本票新增第二渲染引擎、会话 transport 或业务滚动行为。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：实现并验证完成；证据见 `../evidence/26-host-acceptance.md`。
