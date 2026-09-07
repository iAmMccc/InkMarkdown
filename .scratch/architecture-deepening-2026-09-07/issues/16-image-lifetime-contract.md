# 16：验证释放并删除图片旧观察路径

Status: ready-for-agent
Blocked by: 12, 13, 15
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [image-spec.md](../image-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [12](./12-image-block-adapter.md)、[13](./13-image-attachment-adapter.md)、[15](./15-image-preview-adapter.md)
- Acceptance IDs: I-05, I-11, I-12, G-02, G-09
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

三个呈现入口释放后不被加载回调留住，且不存在旧的重复 subscription implementation。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Image/InkImageBlock.swift](../../../Sources/InkMarkdown/Rendering/Image/InkImageBlock.swift)
- [Sources/InkMarkdown/Rendering/Image/InkImageAttachment.swift](../../../Sources/InkMarkdown/Rendering/Image/InkImageAttachment.swift)
- [Sources/InkMarkdown/Rendering/Image/InkImagePreviewController.swift](../../../Sources/InkMarkdown/Rendering/Image/InkImagePreviewController.swift)
- [Tests/InkMarkdownTests/ImageRenderingTests.swift](../../../Tests/InkMarkdownTests/ImageRenderingTests.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 测试挂起请求时释放 Block、Attachment 或 Preview owner，使用 weak 引用和显式 loader 事件确认释放与最后订阅取消。
2. 验证注入/default Store 的资源持有仍遵守 ADR-011，generated source 仍走统一 Store。
3. 查询直接 resolve/switch/subscribe 的呈现端引用；只删除已被共享 module 取代的旧代码。
4. 保留 attachment identity、preview controller generation 等职责不同的 guard，记录保留理由。
5. 核对新 MainActor 清理路径没有 self retain cycle、新 unchecked Sendable 或 public isolation 变化。

## Acceptance

- [ ] owner weak 引用可归零，最后请求被取消，另一个订阅仍在时不误取消共享任务。
- [ ] 三入口只有共享 module 解释 Store 观察状态。
- [ ] 显式/default Store 预算与 generated loader isolation 测试保持。
- [ ] 公开声明对照无变化。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行所有新增 load/preview suite 与 ImageRenderingTests 中 store/ownership/paragraph/block 相关场景。
- 记录旧符号引用清理及 actor 诊断结果。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/16-image-lifetime-contract.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不通过增加 deinit sleep、全局强引用或关闭并发检查掩盖泄漏。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
