# 06：迁移流式表格的输入接纳与参考行所有权

Status: ready-for-agent
Blocked by: 04
Implementation authorization: 已由 cursor-prompt 本批 01–09 授权覆盖；本票验收已完成。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [table-spec.md](../table-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [04](./04-table-layout-state.md)
- Acceptance IDs: T-03, T-04, T-09
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

流式表头、实际行和参考行由 presentation 接纳，视图不再维护三组 prepared 平行数组。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift](../../../Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift)
- [Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift)
- [Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift](../../../Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. setHeaders 一次性接纳 headers/referenceRows/alignments；第二次调用保持 no-op。
2. appendRow 保留分隔行过滤，普通行只接纳一次；相同文本重复追加仍算独立行。
3. rowCount 与 copy 只读取实际可见行，reference 永远不进入两者。
4. 现有宽度控制可在本票暂时从 presentation 获取来源快照，不能回建第二份长期 prepared 数组。
5. 用 02 测试证明计数、reference 和重建路径不漂移。

## Acceptance

- [x] 视图删除 preparedHeaders/preparedReferenceRows/preparedRows 的并行所有权。
- [x] 相同文本作为 reference 和 body 各处理一次，总计数符合输入事件。
- [x] reference 不显示、不计数、不复制。
- [x] 公开 setHeaders/appendRow 的顺序与分隔行行为保持。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 table 来源场景及流式原始 filter/参考行回归。
- 检查 onHeightChange 在合法接纳事件上保持原次数。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/06-table-stream-input.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不新增 append-before-header 能力；不把 referenceRows 当作提前可见 body。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
- 2026-09-07：完成。stream 输入迁 Presentation；证据 `../evidence/06-table-stream-input.md`。
