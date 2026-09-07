# 03：让单元格来源成为一个不可错配的内部输入

Status: ready-for-agent
Blocked by: 02
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [table-spec.md](../table-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [02](./02-table-source-regression.md)
- Acceptance IDs: T-01, T-02, T-03, T-11
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

raw/prepared 单元格以成对值进入内部渲染，来源转换有唯一实现。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift)
- [Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift)
- [Sources/InkMarkdown/Parser/InkPreparedMarkdownSource.swift](../../../Sources/InkMarkdown/Parser/InkPreparedMarkdownSource.swift)

## 计划文件

- `Sources/InkMarkdown/Rendering/Components/InkTablePresentation.swift`（计划新建/前置票创建；先查是否已存在，避免重复）
- `Tests/InkMarkdownTests/InkTablePresentationTests.swift`（计划新建/前置票创建；先查是否已存在，避免重复）

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 定义 internal InkTableCellSource 和 prepared cell 值，将原文与已准备源码绑定；不新增 public 类型。
2. 为 raw 接纳执行一次 sourcePreparedForParsing；prepared 输入直接沿用，不再执行 filter。
3. 让 helper 新入口消费完整 cell 值；旧参数入口只做临时转发，调用方迁移在 05–07 完成。
4. 通过实际 inline render 验证 @@ 非幂等转换和 fallbackText/复制原文仍可用。
5. 保留直接 raw static 的新 replace 可重新接纳语义，不按字符串相等跨生命周期缓存。

## Acceptance

- [ ] cell 值无法表达 raw 与另一个 cell 的 prepared 数组错位。
- [ ] 同一接纳结果反复测量/建行不重复 filter。
- [ ] prepared Markup 派生内容计数为零；raw 每输入 cell 一次。
- [ ] 旧路径编译且 existing table suite 不回归。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行新 InkTablePresentationTests 的来源场景及既有 InkAuditSemanticRegressionTests。
- 检查新增声明保持 internal，public init isolation 无变化。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/03-table-cell-source.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不改变所有表格列宽算法；不要为 cell source 建新 package 或 CONTEXT 领域词条。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
