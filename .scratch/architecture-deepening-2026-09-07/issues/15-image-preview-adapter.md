# 15：迁移预览 Store 分支并保持显式直载

Status: ready-for-agent
Blocked by: 14
Implementation authorization: 未授权；收到后续实施指令后，且前置票完成证据已核对，才执行本票。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [image-spec.md](../image-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [14](./14-image-async-adapter.md)
- Acceptance IDs: I-09, I-10
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

预览的 bypassStore=false 通过共享 async adapter；true 仍按原 loader 直载。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Sources/InkMarkdown/Rendering/Image/InkImagePreviewController.swift](../../../Sources/InkMarkdown/Rendering/Image/InkImagePreviewController.swift)
- [Tests/InkMarkdownTests/ImageRenderingTests.swift](../../../Tests/InkMarkdownTests/ImageRenderingTests.swift)

## 计划文件

- `Tests/InkMarkdownTests/InkImagePreviewLoadTests.swift`（计划新建/前置票创建；先查是否已存在，避免重复）

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 用 14 的 async adapter 替换 loadFromStore 内分支解释，移除确认无引用的 private bridge。
2. 保留 highResTask/highResGeneration 对 controller task 生命周期的保护，以及 maxPreviewPixel 计算。
3. bypassStore=false 保留注入 Store 或 controller 自持 Store，不能退回全局 shared。
4. dismiss/viewDidDisappear 的 cancelHighResTask 继续结束等待；failure/cancel 保留已有降采样图。
5. 用 controlled loader 对两条策略分支、关闭后晚到结果建立 focused 预览测试。

## Acceptance

- [ ] false 分支遵循 Store 预算/合并，true 不经 Store。
- [ ] 关闭后旧 high-res 不应用；新一轮显示结果不被旧任务覆盖。
- [ ] 失败不弹新错误、不清空原图。
- [ ] private bridge 删除且无重复 continuation 接线。
- [ ] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [ ] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行新 PreviewLoadTests、共享 async suite 和既有 Store tests。
- ExampleApp 全屏预览进入/退出/再进入的交互留至 17 集中验收。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/15-image-preview-adapter.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不能为了统一删 bypassStore、强制缓存高清图或新增预览 UI。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
