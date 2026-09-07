# 23：让生产 Coordinator 使用完整流式宿主 module

Status: done
Blocked by: 22
Implementation authorization: 已由用户授权执行（18–26 批次）。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [session-spec.md](../session-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [22](./22-host-environment-events.md)
- Acceptance IDs: S-01, S-04, S-07, S-08, S-11, S-14
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

真实 SwiftUI production 调用链通过新 host 完成流式呈现和退出。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift](../../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift)
- [Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownRepresentable.swift](../../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownRepresentable.swift)
- [Sources/InkMarkdownSwiftUI/Views/InkStreamMarkdownView.swift](../../../Sources/InkMarkdownSwiftUI/Views/InkStreamMarkdownView.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. Coordinator 持有一个 streaming host，把 updateStreaming 和流式 teardown 委托给它；不再在 caller 顺序执行 token/env/observer/bind。
2. static/blocks 切换进来先释放 streaming host；从 static 切换为 streaming 先按既有策略结束 static continuity。
3. 同一个 container 不能同时由旧 static 和新 streaming owner 操作；dismantle 传入实际移除的 container。
4. 清除只供旧流式路径使用的临时读写调用，剩余 dead code 的系统删除在 25。
5. Representable 的 environment snapshot、promotionGeneration 与 iOS16 sizeThatFits 分支保持；不改公共 View 初始化器。

## Acceptance

- [x] 真实 updateUIView→Coordinator→新 host→continuity/container 链路可核对。
- [x] static→streaming→static、Session A→B 均不遗留绑定/环境。
- [x] existing handoff 与公开 onDisplayUpdate 测试使用生产路径通过。
- [x] Coordinator 不再逐项操纵流式 owner/token 顺序。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 continuity、Session、loop prevention、workload 组及新 host suite。
- 核对生产调用引用，未被调用的新 host 测试通过不能充当迁移证据。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/23-coordinator-use-host.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不切换成 native SwiftUI renderer，不将滚动策略或 transport 移入库。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：实现并验证完成；证据见 `../evidence/23-coordinator-use-host.md`。
