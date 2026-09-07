# 08：删除表格旧平行输入协议

Status: ready-for-agent
Blocked by: 05, 07
Implementation authorization: 已由 cursor-prompt 本批 01–09 授权覆盖；本票验收已完成。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [table-spec.md](../table-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [05](./05-table-static-adapter.md)、[07](./07-table-stream-layout.md)
- Acceptance IDs: T-11, G-02, G-09
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

完成表格 contract 阶段，生产代码只剩一条来源和列宽协调路径。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableBlock.swift)
- [Sources/InkMarkdown/Rendering/Components/InkTableBlockView.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableBlockView.swift)
- [Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift](../../../Sources/InkMarkdown/Rendering/Components/InkStreamTableView.swift)
- [Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift](../../../Sources/InkMarkdown/Rendering/Components/InkTableRenderHelper.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 查询旧 helper 签名和 prepared optional 参数的全部引用，包含 Tests；逐一迁移剩余合法消费者。
2. 删除 03 迁移期转发重载、视图旧字段和无人使用分支。
3. 保留 public String 字段与 from 工厂、0.0.1 兼容声明；内部删除不借机改 public 命名。
4. 旧 helper 测试只有被同等行为测试取代才删除，不能丢掉实际几何或 link 测试。
5. 核对新增 module 不只是承接同样多的并行参数；记录实际消失的 caller knowledge。

## Acceptance

- [x] 无 production raw/prepared 平行数组调用协议。
- [x] source preparation 和 width invalidation 各有一个实现所有者。
- [x] 公共声明快照与 baseline 无意外差异。
- [x] 所有过渡重载/死字段有引用检查证据。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 table 组一次；执行 git diff --check（限本票文件）。
- 提交 evidence/08-table-contract.md，列出旧符号到保留替代路径的对照。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/08-table-contract-old-plumbing.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不要把有实际语义的富文本 renderer 或 UIKit 建行代码删除。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
- 2026-09-07：完成。删除平行协议；28/28。证据 `../evidence/08-table-contract-old-plumbing.md`。
