# 22：集中提交后环境更新与显示通知

Status: done
Blocked by: 21
Implementation authorization: 已由用户授权执行（18–26 批次）。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [session-spec.md](../session-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [21](./21-host-ownership-release.md)
- Acceptance IDs: S-02, S-07, S-08, S-09, S-12
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

新 host 统一暂存环境、commit 后应用、重入抑制和旧事件作废。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift](../../../Sources/InkMarkdownSwiftUI/Bridge/InkMarkdownCoordinator.swift)
- [Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift](../../../Sources/InkMarkdownSwiftUI/Session/InkMarkdownRenderSession.swift)

## 计划文件

- `Sources/InkMarkdownSwiftUI/Bridge/InkStreamingPresentationHost.swift`（计划新建/前置票创建；先查是否已存在，避免重复）
- `Tests/InkMarkdownSwiftUITests/InkStreamingPresentationHostTests.swift`（计划新建/前置票创建；先查是否已存在，避免重复）

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. waiting 环境仅存于 host；成功 apply/成组 binding 后，验证 token 再更新 Session 环境。
2. 同步显示通知遇正在 reconcile 不嵌套 apply；退出后仅安排一个必要的补充 reconcile。
3. 补充事件带 Session 身份、cycle 和 host generation 校验；多次环境变化取最新 pending 值。
4. cycle 已变化时允许当前 mounted host 清理旧视图，不能一律以 token 无效丢弃 reset/cancel 通知。
5. finished 无 remainder textView 仍保留 observer；public onDisplayUpdate 继续由 Session 驱动。

## Acceptance

- [x] waiting dark 不污染 active light，接管后最新环境生效。
- [x] reset/cancel/session 替换后排队旧事件无副作用。
- [x] 环境同步回调不产生 reconcile 递归或无穷 dispatch。
- [x] 终态环境与尺寸更新仍生效；PublishHopper 调度实现未改变。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行新 host 环境/cycle/重入场景及 Session publish/终态环境场景。
- 保留事件序列证据，不能单靠最终色值证明顺序正确。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/22-host-environment-events.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不把 default-mode deferred published 写入改成 main.async，也不扩大 dirty slots 的公共职责。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：实现并验证完成；证据见 `../evidence/22-host-environment-events.md`。
