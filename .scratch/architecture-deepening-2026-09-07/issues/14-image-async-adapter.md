# 14：为共享观察提供一次终结的 async adapter

Status: done
Blocked by: 11
Implementation authorization: 已由用户授权执行（10–17 批次）。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [image-spec.md](../image-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [11](./11-image-load-module.md)
- Acceptance IDs: I-09
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

Store 观察可由内部 async 调用者等待，取消与 continuation 终结不再由预览单独实现。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Image/InkImagePreviewController.swift](../../../Sources/InkMarkdown/Rendering/Image/InkImagePreviewController.swift)

## 计划文件

- `Sources/InkMarkdown/Rendering/Image/InkImagePresentationLoad.swift`（计划新建/前置票创建；先查是否已存在，避免重复）
- `Tests/InkMarkdownTests/InkImagePresentationLoadTests.swift`（计划新建/前置票创建；先查是否已存在，避免重复）

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 在共享 load implementation 邻近增加内部 async adapter，不新建第二套 resolve switch。
2. 明确 continuation 未安装/已安装/已终结的行为，先检查预取消再启动观察。
3. cancellation handler 只通过安全的 MainActor 清理路径取消观察并 resume CancellationError 一次。
4. 同步 ready、rejected、nil failure 与外部 cancel 竞争时按先终结者生效；后到者 no-op。
5. 保留现有内部错误映射，不能承诺 Store 已丢失的网络错误详情。

## Acceptance

- [x] pre-cancel 不启动 loader，等待不会悬挂。
- [x] 取消与成功竞争只 resume 一次。
- [x] 同步 ready 正常结束，无额外 pending。
- [x] adapter 内不再复制 Store loading/queued 处理。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 async cancellation/ready/failure 聚焦场景。
- 每个 fixture pending continuation 均在 defer 清理；用有界等待证明终结。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/14-image-async-adapter.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不先修改 PreviewController，不改变公开错误类型或引入 async-only public 图片 interface。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：实现并验证完成；证据见 `../evidence/14-image-async-adapter.md`。
