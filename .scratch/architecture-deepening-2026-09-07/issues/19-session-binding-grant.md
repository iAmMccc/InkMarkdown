# 19：把 Session 的 observer 与文本绑定收成一组资源

Status: ready-for-agent
Blocked by: 18
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [session-spec.md](../session-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [18](./18-host-handoff-regression.md)
- Acceptance IDs: S-03, S-05, S-08, G-05
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

Session 用一个内部 binding record/grant 管理 private observer 与可选 textView，旧释放不能清掉新绑定。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift](../../../Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift)
- [Tests/InkMarkdownSwiftUITests/InkMarkdownRenderSessionTests.swift](../../../Tests/InkMarkdownSwiftUITests/InkMarkdownRenderSessionTests.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 在 Session 同文件实现内部 binding record；生命周期方法必须在 MainActor，owner/observer 弱捕获不留住 host。
2. 提供成组 install/update/release，release 必须匹配当前 grant；textView 可以为 nil 而 observer 有效。
3. 旧 bindTextView/installPresentationDisplayUpdateObserver 等内部函数暂作兼容转发，现有生产调用保持编译；不要改 public onDisplayUpdate。
4. 把旧两个 owner 字段的权限判断集中到 record，grant 只表达资源撤销，不声称拥有 continuity attachment。
5. 测试新 install 替换旧 grant、旧 release 无效、promoted 无 textView 仍通知，以及公开 callback 与 private observer 共存。

## Acceptance

- [ ] 文本绑定与 observer 由同一个资源记录控制。
- [ ] 旧 grant release 无法解绑新 record；nil textView observer 可用。
- [ ] public onDisplayUpdate 未被内部 observer 覆盖。
- [ ] Session canonical source/state/hopper/continuity lifetime 未迁走。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 Session tests、18 的 handoff 场景；检查 legacy 转发只为迁移存在。
- 确保新增 record 未公开、无对 SwiftUI core 的反向引用。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/19-session-binding-grant.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不能把 grant 作为第二套 attachment 权限；不能为重构移动 live Thought 状态。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
