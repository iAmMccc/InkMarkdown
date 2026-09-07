# 02：固化表格来源和未显示参考行回归场景

Status: ready-for-agent
Blocked by: 01
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [table-spec.md](../table-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [01](./01-capture-current-baseline.md)
- Acceptance IDs: T-01, T-03, T-04
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

现有生产路径上的表格测试能区分重复过滤与丢失未显示参考行。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift](../../../Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift)
- [Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift](../../../Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift)
- [Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 扩展 stream raw filter 测试，统计 2 个 header、2 个 reference cell、2 个 body cell 的接纳次数，不再只用 >0。
2. 通过公开 setHeaders/appendRow 和真实 UIView resize 驱动，断言同一批输入经历重建后计数不增。
3. 把很长内容只放 referenceRows；实际 append 短行，不能把 reference 实际显示来掩盖遗失。
4. 保留顶层 renderer prepared-source 测试，追加尺寸重建后的文本与计数断言。
5. 测试只观察文本、首列几何、rowCount；不要访问 private prepared 数组。

## Acceptance

- [ ] 测试能在故意遗漏 reference 样本的实现下失败（通过代码审查说明判别点，不提交破坏版本）。
- [ ] 流式过滤次数按 6 个输入 cell 精确计数，第二次 setHeaders 不增加。
- [ ] 宽→窄→宽后未显示参考行仍影响列宽。
- [ ] 现有 prepared 顶层一次性行为不变。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 InkAuditSemanticRegressionTests 聚焦 suite。
- 若新场景暴露基线缺陷，记录到证据，不把该票标完成；回到规格判断是来源/宽度范围内修复还是范围外问题。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/02-table-source-regression.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不改 production；本票是后续迁移的行为护栏，不新建重复测试 target。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
