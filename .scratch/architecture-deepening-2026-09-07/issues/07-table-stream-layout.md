# 07：迁移流式扩列和 resize 到同一布局规则

Status: ready-for-agent
Blocked by: 06
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [table-spec.md](../table-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [06](./06-table-stream-input.md)
- Acceptance IDs: T-04, T-05, T-06, T-07, T-10
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

流式视图仅按 layout snapshot 应用追加或重建，不再独立计算列宽。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift](../../../Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift)
- [Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift)
- [Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift](../../../Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. layoutSubviews 将真实 contentWidth 交给 presentation；通过 snapshot 决定是否重建。
2. append 依据布局结果只建新行或重建历史行，保持 O(cols) 快速检查的所在 implementation。
3. 删除视图 widthsNeedExpand 内重复字体、inline render、boundingRect、padding 和 cap。
4. rebuildAllRows 使用同一 prepared cell 和 width mode，不能重过滤。
5. 保留 wrap resize 无 onHeightChange 递归、scroll 自然内容宽不变的细节。

## Acceptance

- [ ] 视图不再拥有可独立失真的 fixedWidths/ratio 转换规则。
- [ ] 未显示 reference 行经 resize 和新长行追加后仍有效。
- [ ] 短行追加不全量重建；长行可按需扩列。
- [ ] static/stream 最终几何等价且两个模式保持差异。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行完整 table 组和现有 Dynamic Type 表格场景。
- 手动 code review 确认 stream view 不再直接调用 boundingRect 测列宽。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/07-table-stream-layout.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不因收拢代码改变 UIScrollView viewport、末列 trailing 或列数策略。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
