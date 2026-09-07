# 17：完成图片方向契约与交互验收

Status: ready-for-agent
Blocked by: 16
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [image-spec.md](../image-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [16](./16-image-lifetime-contract.md)
- Acceptance IDs: I-01, I-02, I-03, I-04, I-05, I-06, I-07, I-08, I-09, I-10, I-11, I-12
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

图片三呈现 adapter 的共享 lifecycle 行为与差异均有证据。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [docs/contributor-guide/05-modules.md](../../../docs/contributor-guide/05-modules.md)
- [docs/decisions/ADR-011-image-store-configuration-ownership.md](../../../docs/decisions/ADR-011-image-store-configuration-ownership.md)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 执行 image 验证组；复用同一最终候选已有测试证据，避免没有新改动仍重复全量。
2. 执行网络图片 block/inline、全屏预览关闭与重开、失败保底关键交互；网络可用性与取消 fixture 证据分开。
3. 检查 LaTeX/Mermaid 生成内容接入仍可加载，方向自动测试用 addon contract，不依赖离屏 WebKit PNG。
4. 更新图片内部生命周期职责说明，保留现有 ADR 的预算与 opt-in 契约。
5. 生成 evidence/17-image-acceptance.md，逐项映射 I-* 并报告 local dependency/remote CI 限制。

## Acceptance

- [ ] I-* 全部有可复查证据，取消/释放不只靠肉眼判断。
- [ ] 三个呈现入口布局/交互差异保留，生成内容加载契约未变。
- [ ] 文档无未验证平台或发布结论。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- image + addon contract 聚焦测试；ExampleApp 图片/预览关键交互。
- 检查文档链接和公共接口对照。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/17-image-acceptance.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不新增真网性能 benchmark 或扩大成所有图片协议的排列组合。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
