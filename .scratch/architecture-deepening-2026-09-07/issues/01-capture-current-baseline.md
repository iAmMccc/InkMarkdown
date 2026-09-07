# 01：建立三个方向的当前可复查基线

Status: ready-for-agent
Blocked by: None
Implementation authorization: 已由 cursor-prompt 本批 01–09 授权覆盖；本票验收已完成。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [spec.md](../spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: 无
- Acceptance IDs: G-07, G-08
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

形成 evidence/01-baseline.md，区分当前通过、既有失败和环境阻塞，为后续回归归因提供基准。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Package.swift](../../../Package.swift)
- [.github/workflows/ci.yml](../../../.github/workflows/ci.yml)
- [docs/current-status.md](../../../docs/current-status.md)
- [Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift](../../../Tests/InkMarkdownTests/InkAuditSemanticRegressionTests.swift)
- [Tests/InkMarkdownTests/ImageRenderingTests.swift](../../../Tests/InkMarkdownTests/ImageRenderingTests.swift)
- [Tests/InkMarkdownSwiftUITests/InkBlockPresentationContinuityTests.swift](../../../Tests/InkMarkdownSwiftUITests/InkBlockPresentationContinuityTests.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 确认用户已另行授权实施；记录分支、HEAD、git status、目标路径 diff，保留无关文档改动。
2. 按 execution-guide 动态发现 scheme、Simulator 与依赖模式；只读发现，不安装工具、不变更 manifest。
3. 记录受影响公共声明快照及相关文件列表，供最终对照；同时记录现有测试选择器。
4. 运行 baseline 验证组（表格既有 suite、Store suite、Session/continuity/workload）；不要先增删测试来“清理”基线。
5. 对失败记录最小错误、复现命令、发生在编译/发现/执行哪一阶段；发现代码问题时明确哪些后续票受影响。

## Acceptance

- [x] 证据包含 SHA、diff、toolchain、scheme、destination、依赖解析方式。
- [x] 每个基线组有实际通过/失败/跳过数量；未执行不写为通过。
- [x] 公共声明快照可用于 G-02 对照，不将临时依赖路径写入发布 manifest。
- [x] 原有工作树修改完整保留。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 执行 execution-guide 的 baseline 组一次；确认非零测试被执行。
- 检查证据中的命令可复用且不含凭证。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/01-capture-current-baseline.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不做任何重构或失败修复；已知失败不能通过删断言、增超时或跳过测试处理。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
- 2026-09-07：实施完成。HEAD `f71cc29`；baseline 6 suite / 51 tests 全部通过（iPhone 17 Pro / iOS 26.5，local overlay）。证据：`../evidence/01-capture-current-baseline.md`。远程 GitHub 解析未验证；发布 manifest 已恢复 remote pin。无生产代码改动。
