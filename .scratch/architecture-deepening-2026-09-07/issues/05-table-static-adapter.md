# 05：迁移静态表格到集中呈现状态

Status: ready-for-agent
Blocked by: 04
Implementation authorization: 已由 cursor-prompt 本批 01–09 授权覆盖；本票验收已完成。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [table-spec.md](../table-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [04](./04-table-layout-state.md)
- Acceptance IDs: T-01, T-02, T-05, T-08, T-10
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

静态 makeView/apply/resize 都消费 InkTablePresentation，视图不再配对 raw/prepared 数组。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift)
- [Sources/InkMarkdown/Rendering/Components/InkTableBlockView.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableBlockView.swift)
- [Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift)
- [Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift](../../../Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. makeView/updateExistingView 将完整 cell 来源内容交给静态视图的 presentation，不改变现有公开 String 字段。
2. apply 建立新的输入接纳；layoutSubviews 和 sizeThatFits 只更新 contentWidth，不重复 sourceFilter。
3. 保留 config 与 configuration 的当前角色，prepared factory 输入不因样式更新再次过滤。
4. wrap/scroll 容器、手势、copy 和链接 handler 继续由原视图呈现；仅替换来源/布局协调。
5. 对 raw static 构造增加直接接纳/resize 的 filter 次数测试；对显式 apply 单独记录允许的新接纳。

## Acceptance

- [x] 顶层 prepared filter 一次、raw 每 replace 每 cell 一次，resize 不增。
- [x] makeView 与 updateExistingView 仍返回/接受原宿主类型。
- [x] sizeThatFits 正值、width 协商、copy 手势不重复。
- [x] 富文本链接和 ragged 行 corpus 通过。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 table 组：新 presentation suite、InkAuditSemanticRegressionTests、InkCorpusTableTracerTests。
- 在 UIView 真实布局路径验证几何，不用 snapshot 字段替代宿主测量。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/05-table-static-adapter.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不迁移流式路径，不删除公开 config/configuration 或兼容初始化器。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
- 2026-09-07：完成。静态视图迁至 Presentation；22/22。证据：`../evidence/05-table-static-adapter.md`。
