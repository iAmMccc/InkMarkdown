# 12：迁移块级图片到共享生命周期

Status: done
Blocked by: 11
Implementation authorization: 已由用户授权执行（10–17 批次）。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [image-spec.md](../image-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [11](./11-image-load-module.md)
- Acceptance IDs: I-01, I-03, I-06
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

Block 只保留图片尺寸、占位和交互，Store 观察由共享 module 负责。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Image/InkImageBlock.swift](../../../Sources/InkMarkdown/Rendering/Image/InkImageBlock.swift)
- [Tests/InkMarkdownTests/ImageRenderingTests.swift](../../../Tests/InkMarkdownTests/ImageRenderingTests.swift)

## 计划文件

- 不要求新增生产文件；只修改上述入口及完成本票所需的邻近测试。

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. configure 继续计算 display 和 effectiveWidth，但将 resolve/subscribe 委托给 load module。
2. pending 驱动现有 placeholder，image 驱动 showImage，失败/reject 驱动原 fallback。
3. prepareForReuse 作废当前观察，再重置图片、尺寸与 fallback；deinit 取消不得 retain self。
4. 只有在共享 generation 覆盖了 showImage 的 token 用途后，才删除 loadToken；不能删掉仍保护延迟视觉动作的有效 guard。
5. 保留 deprecated initializer、makeView 返回 self、tapAction、.button 和等价内容判定。

## Acceptance

- [x] 缓存命中不闪 loading placeholder、尺寸紧凑。
- [x] prepareForReuse 后 A 晚到成功或失败都不能更新清空/新配置的 view。
- [x] pending、失败 fallback、tap 回调和类型兼容保持。
- [x] Block 不再 switch loading/queued 或直接保存 Store subscription。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 existing imageBlock_* 场景及 load module suite；选择器以测试发现为准。
- 用 controlled loader 验证重配 A/B 与 prepareForReuse；不通过私有 imageView 字段断言，可沿用既有 view 检查 seam。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/12-image-block-adapter.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不改变图片 tap 产品行为或把旧 public 初始化器改成 internal。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：实现并验证完成；证据见 `../evidence/12-image-block-adapter.md`。
