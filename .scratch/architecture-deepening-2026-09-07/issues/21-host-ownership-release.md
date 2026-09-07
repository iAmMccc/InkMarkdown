# 21：实现新宿主的等待、接管与有序释放

Status: ready-for-agent
Blocked by: 20
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [session-spec.md](../session-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [20](./20-host-render-snapshot.md)
- Acceptance IDs: S-02, S-03, S-04, S-05, S-06, S-10
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

新 host 完整承担 waiting/committed/releasing 语义，释放后才唤醒等待者。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdownSwiftUI/Continuity/InkBlockPresentationContinuity.swift](../../../Sources/InkMarkdownSwiftUI/Continuity/InkBlockPresentationContinuity.swift)
- [Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift](../../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownContainerView.swift)

## 计划文件

- `Sources/InkMarkdownSwiftUI/Bridge/InkStreamingPresentationHost.swift`（计划新建/前置票创建；先查是否已存在，避免重复）
- `Tests/InkMarkdownSwiftUITests/InkStreamingPresentationHostTests.swift`（计划新建/前置票创建；先查是否已存在，避免重复）

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 根据 continuity.ownsAttachment 判定权限，只有 apply 成功才建立资源绑定；waiting 不影响活跃 host。
2. 实现 teardown 顺序：作废本地排队事件、detach/apply 或 token 验证 discard、移除自己的 callback/grant、清空引用、最后 wake waiter。
3. 等待者先 teardown 只清理自己的注册，不 discard 活跃 attachment。
4. 用真实两个 host + 同一 Session 测试等待、等待者退出、旧 host 释放、新 host 接管及旧 release 再次到来。
5. 测试 container 缺失与真实 stale/conflicting apply 情况，不修改 final class 为可继承来伪造失败。

## Acceptance

- [ ] 新 host 接管时旧 observer 已移除，不发生同步回调重入旧宿主。
- [ ] 等待者销毁无权解绑活跃 owner。
- [ ] 缺失 container/失败 apply 不永久卡住自己持有的 attachment。
- [ ] 同 session remount 保留 Thought live 状态。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行新 host 的双宿主/释放场景与 existing continuity suite。
- 用 weak 引用验证 teardown 后 host/UITextView 不因 callback 环留住。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/21-host-ownership-release.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不能用 host 的本地 bool 替代 continuity token 权限，不能清空整份 continuity state 来释放 UIView。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
