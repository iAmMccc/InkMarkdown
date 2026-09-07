# 04：集中表格测量和列宽失效状态

Status: ready-for-agent
Blocked by: 03
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [table-spec.md](../table-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [03](./03-table-cell-source.md)
- Acceptance IDs: T-04, T-05, T-06, T-07
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

InkTablePresentation 能用一份测量规则处理静态输入、追加行和宿主宽度变化。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift)
- [Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift](../../../Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift)

## 计划文件

- `Sources/InkMarkdown/Rendering/Components/InkTablePresentation.swift`（计划新建/前置票创建；先查是否已存在，避免重复）
- `Tests/InkMarkdownTests/InkTablePresentationTests.swift`（计划新建/前置票创建；先查是否已存在，避免重复）

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 在 03 文件扩展 presentation，持有已接纳 headers/rows/referenceRows 和布局模式；向调用方返回一致 layout snapshot。
2. 把字体、inline render、boundingRect、padding、上限和 ratio 换算收进同一 implementation。
3. 追加行先做 O(cols) 增量检查，只在扩列或 wrap 宽变化时要求全量重建；reference 样本始终保留。
4. 用真实 attributed text 测量，沿用既有末列、ragged 行与 0.5pt 容差规则；不发明等宽列或新布局算法。
5. snapshot 不暴露可变缓存，static/stream 只选择输入操作，不自行同步 widthMode/fixedWidths。

## Acceptance

- [ ] 宽→窄→宽可恢复 reference 影响；scroll viewport 变化不改变自然列宽。
- [ ] 同内容静态一次接纳与逐行接纳产生等价最终列布局。
- [ ] 短行 append 不要求全量重建，更长行按需重建。
- [ ] 只有一处 cell 宽度计算规则；新 module 有真实输入/输出测试。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 InkTablePresentationTests 布局状态场景；断言文本/布局结果，不断言内部缓存数组。
- 记录 snapshot 到 production 的后续消费者票 05、07，不能把未迁移当成完成方向。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/04-table-layout-state.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不缓存所有历史 NSAttributedString，不引入新的布局引擎或全量 append 重绘。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
