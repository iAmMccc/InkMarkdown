# 24：验证真实 SwiftUI 移除与重挂载

Status: ready-for-agent
Blocked by: 23
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [session-spec.md](../session-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [23](./23-coordinator-use-host.md)
- Acceptance IDs: S-06, S-11, S-12, S-13
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

通过真实 UIHostingController rootView 更新验证相同 Session remount 后继续接收内容。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Tests/InkMarkdownSwiftUITests/InkMarkdownViewTests.swift](../../../Tests/InkMarkdownSwiftUITests/InkMarkdownViewTests.swift)
- [Tests/InkMarkdownSwiftUITests/InkMarkdownRenderSessionTests.swift](../../../Tests/InkMarkdownSwiftUITests/InkMarkdownRenderSessionTests.swift)
- [Sources/InkMarkdownSwiftUI/Views/InkStreamMarkdownView.swift](../../../Sources/InkMarkdownSwiftUI/Views/InkStreamMarkdownView.swift)

## 计划文件

- `Tests/InkMarkdownSwiftUITests/InkStreamingPresentationHostTests.swift`（计划新建/前置票创建；先查是否已存在，避免重复）

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 在现有 SwiftUI test target 构造最小 SwiftUI harness，以明确条件移除并重新插入 InkStreamMarkdownView；不创建新 App target。
2. 用真实 UIHostingController、布局与有界 runloop 推进 make/update/dismantle；不能手动直接调用 Coordinator 来代替本票场景。
3. 初始显示 Thought/正文，执行折叠；移除、append 后重挂载相同 Session，验证最新正文与状态延续。
4. 在 promotion 发布待执行时触发 reset/cancel 的 focused 场景继续验证旧状态不会被发布回来。
5. 清理 hosting/window/rootView 和未完成 Session，测试结束不得留下活跃 observer。

## Acceptance

- [ ] 真实 SwiftUI remount 后新 delta 可见，原有 Thought live 状态按同周期规则保留。
- [ ] 不同 Session 不继承旧内容或 pending environment。
- [ ] reset/cancel 前排队的 promotion 不复活旧终态。
- [ ] 测试不依赖截图像素、网络、固定长延时。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行真实 remount 场景、新 host suite 和 Session deferred publish 场景。
- 如果 runtime 无法承载 UIHostingController 测试，保留未验证并记录具体错误，不能用纯 Coordinator 测试改写成通过。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/24-swiftui-remount-regression.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不扩大 UI 自动化矩阵，不修改 SwiftUI diff 行为以适应测试。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
