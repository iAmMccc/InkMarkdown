# 09：完成表格方向验收和规格证据映射

Status: ready-for-agent
Blocked by: 08
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [table-spec.md](../table-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [08](./08-table-contract-old-plumbing.md)
- Acceptance IDs: T-01, T-02, T-03, T-04, T-05, T-06, T-07, T-08, T-09, T-10, T-11, T-12
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

T-01 至 T-12 均有可复查证据，表格 module 职责文档与实现一致。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [docs/contributor-guide/05-modules.md](../../../docs/contributor-guide/05-modules.md)
- [docs/decisions/ADR-008-swiftui-adapter-architecture.md](../../../docs/decisions/ADR-008-swiftui-adapter-architecture.md)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 复用 02–08 的同一最终代码证据，只有最终修改使证据失效时才重跑。
2. 执行 table 与 SwiftUI corpus/measurement 的受影响测试，确认新深 module 的生产消费者。
3. 在 ExampleApp 对静态表格、逐行表格执行窄宽切换、复制和 link 关键交互，按 execution-guide 记录。
4. 仅更新与表格内部职责有关的现有开发文档，不把规划写入已交付状态。
5. 生成 evidence/09-table-acceptance.md，逐行映射 T-*，并列出未验证平台。

## Acceptance

- [ ] 每个 T-* 有测试或交互证据路径与结果。
- [ ] 表格方向没有未迁移 caller 或失效的旧 sourceFilter 语义。
- [ ] 文档不宣称没有执行的 iOS 15/远程 CI 通过。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- table + SwiftUI 表格 corpus/measurement；ExampleApp 相关交互。
- 验证本方向文档链接、diff 与公共声明。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/09-table-acceptance.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不扩大成全 App UI 覆盖，不修改图片生命周期或会话接管。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
