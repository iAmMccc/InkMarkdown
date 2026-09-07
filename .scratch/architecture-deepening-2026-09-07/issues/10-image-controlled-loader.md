# 10：建立可控图片加载事件 fixture

Status: ready-for-agent
Blocked by: 01
Implementation authorization: 已由本批 10–17 授权覆盖；本票验收已完成。

## Parent spec 与范围

- Parent spec: [三方向规格](../spec.md)
- Direction spec: [image-spec.md](../image-spec.md)
- Required guide: [执行与验证指南](../execution-guide.md)
- Blocking dependencies: [01](./01-capture-current-baseline.md)
- Acceptance IDs: I-02, I-03, I-04
- 工作目录：`/Users/shizihan/DailyUse/Github/InkMarkdown`；当前规划基线 `feat/swiftUI` / `ee049f0`，实施前必须核对。

## Outcome

后续生命周期测试可精确控制成功、失败、取消与忽略取消的晚到结果，不依赖网络和固定 sleep。

## 必读与定位

先读根 AGENTS.md、本票、direction spec 的相关章节及所有前置票的最终证据。下面是已核对的源码入口；行号会变化，按类型/方法定位，不按旧行号盲改。

- [Tests/InkMarkdownTests/ImageRenderingTests.swift](../../../Tests/InkMarkdownTests/ImageRenderingTests.swift)
- [Sources/InkMarkdown/Rendering/Image/InkImageLoading.swift](../../../Sources/InkMarkdown/Rendering/Image/InkImageLoading.swift)
- [Sources/InkMarkdown/Rendering/Image/InkImageStore.swift](../../../Sources/InkMarkdown/Rendering/Image/InkImageStore.swift)

## 计划文件

- `Tests/InkMarkdownTests/Support/InkControlledImageLoader.swift`（计划新建/前置票创建；先查是否已存在，避免重复）

仅在本票结果需要时修改邻近文件；额外修改必须在结果中解释因果关系。不得触碰无关工作树改动。

## 实施步骤

1. 检查现有 MockImageLoader/CancellationIgnoringLoader，能复用则提取其可控部分，避免第三套重复假实现。
2. fixture 以显式请求编号和事件驱动 started、succeed、fail、observeCancel，正确同步并发访问。
3. 提供协作取消和非协作晚到两种行为；所有悬挂请求在测试清理时完成，防止泄漏 continuation。
4. 用真实 InkImageStore 验证两个订阅共享一次 load、最后订阅取消，以及 queued 尚未启动；这些是 fixture 对接证据。
5. 测试等待使用现有有界 probe 或显式事件；超时错误应显示等待的请求编号。

## Acceptance

- [x] fixture 可重复地产生 A 晚于 B、queued cancel 和 failure。
- [x] 真实 Store 的 loader 调用/取消次数可观察，不访问 private map。
- [x] 测试结束无未完成请求或后台 task。
- [x] 本票涉及的规格条目都有真实验证结果；没有执行或失败的项目保持未勾选。
- [x] 变更没有放宽现有断言、增加无依据的超时或悄悄删除兼容声明。

## Verification

- 运行 InkImageStoreTests 相关 cancel/coalescing 场景及新增 fixture 对接场景。
- 重复运行仅在发现调度不稳定时使用，禁止用重复直到绿掩盖失败。
- 按 execution-guide 使用当前发现的真实测试选择器；需要新增 suite 的名称为本票规划名，先确认确有测试被发现，0 tests 不是通过。
- 记录到 `../evidence/10-image-controlled-loader.md`：SHA+diff、实际命令、scheme/destination、通过/失败/跳过、log/xcresult 路径、未验证项。
- 已在同一最终文件版本上通过的检查不重复执行；新改动或失败使证据失效时才重跑。

## 不做与失败处理

不改 production Store；不使用真实 HTTP、不加新的测试 target。

若与当前公共契约/ADR 冲突，记录冲突和所需决定，把受影响票标为 needs-info；环境故障记录为验证阻塞，不伪装成产品回归。不能凭本票 readiness 推断提交、push、发布或其他票的实施授权。

## 完成交接

列出实际修改文件、责任从哪里移到哪里、验收编号到证据的映射。说明哪些临时转发/旧字段尚需后续票清理。前置票完成的判定是验收与证据齐全，不是文件存在或 Status 为 ready-for-agent。

## Comments

- 2026-09-07：仅完成规格与拆票，尚未实现或执行本票验证。
- 2026-09-07：完成。InkControlledImageLoader + fixture 21/21。证据 `../evidence/10-image-controlled-loader.md`。
