# 13：迁移行内图片观察并保留宿主重绑语义

Status: done
Blocked by: 11
Implementation authorization: 已由用户授权执行（10–17 批次）。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [image-spec.md](../image-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [11](./11-image-load-module.md)
- Acceptance IDs: I-03, I-07, I-08
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

Attachment 复用共享加载生命周期，仍正确处理 materialization identity 与 TextKit 段落更新。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Image/InkImageAttachment.swift](../../../Sources/InkMarkdown/Rendering/Image/InkImageAttachment.swift)
- [Tests/InkMarkdownTests/ImageRenderingTests.swift](../../../Tests/InkMarkdownTests/ImageRenderingTests.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 保留 source/rendering 和非隔离构造/测量；加载 module 在 MainActor 显示绑定阶段建立。
2. materialize 继续用 display/Store/loader identity 判定是否真正需要重请求，再调用共享 start。
3. 共享结果到达时使用当前 layoutManager/段落绑定应用图片，旧宿主不得被迟到结果失效。
4. 只删除被共享模块覆盖的 subscription/generation；materialization identity 不因“看似重复”而删。
5. 保留 renderedImage 快照、图片加载通知、onHeightChange、动画提示、段落最大行高抬升策略。

## Acceptance

- [x] 同 identity 不重启；display/Store/loader 任一有效变化触发新请求。
- [x] 纯 render/attachmentBounds 不创建网络 task。
- [x] host 重绑后只有当前宿主/段落收到尺寸失效。
- [x] 段落缩进、对齐、min line height 等几何不退化。
- [x] 原有 nonisolated interface 保持，未新增不安全 Sendable 标注。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 existing bindAttachments、inlineAttachmentMaterializationIdentity、textViewBindingHelperRematerializes、applyImage 段落场景。
- 运行 load module suite，核对 StrictConcurrency 编译诊断。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/13-image-attachment-adapter.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不把 UIKit/MainActor 动作塞进 TextKit 的 nonisolated 测量，不提前物化图片。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：实现并验证完成；证据见 `../evidence/13-image-attachment-adapter.md`。
