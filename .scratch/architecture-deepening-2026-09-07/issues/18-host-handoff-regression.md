# 18：固化宿主交接与周期作废关键场景

Status: done
Blocked by: 01
Implementation authorization: 已由用户授权执行（18–26 批次）。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [session-spec.md](../session-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [01](./01-capture-current-baseline.md)
- Acceptance IDs: S-02, S-03, S-04, S-05, S-07, S-12
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

既有生产 Coordinator 测试明确覆盖交接顺序、旧 owner 释放和待执行通知作废。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Tests/InkMarkdownSwiftUITests/InkBlockPresentationContinuityTests.swift](../../../Tests/InkMarkdownSwiftUITests/InkBlockPresentationContinuityTests.swift)
- [Tests/InkMarkdownSwiftUITests/InkMarkdownRenderSessionTests.swift](../../../Tests/InkMarkdownSwiftUITests/InkMarkdownRenderSessionTests.swift)
- [Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift](../../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 阅读已存在的 719/855 附近关键链路，复用已有测试 fixture，不复制整套 continuity 状态测试。
2. 补旧 A 在 B 已接管后再次 teardown，B 继续接收正文的断言。
3. 补环境补充 reconcile 排队期间 reset/cancel，下一 runloop 不复活旧内容。
4. 保留 B 等待/提前销毁、A 继续 delta、B 最终环境接管的已有断言。
5. 以公开 Session 状态、当前容器内容和回调记录验证；不得断言 owner UUID。

## Acceptance

- [x] 旧 owner 重复释放不影响当前 owner。
- [x] 排队旧环境任务遇 reset/cancel 后不能恢复旧视图。
- [x] 既有 handoff、waiting environment 和 publish 延迟规则有明确测试入口。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 continuity、Session suite；有界驱动 runloop，不加任意长 sleep。
- 若暴露既有问题，记录实际结果和对应 S-*，不要静默把期待改成当前错误。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/18-host-handoff-regression.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不改 production lifecycle，不先搬动 PublishHopper。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：实现并验证完成；证据见 `../evidence/18-host-handoff-regression.md`。
