# 六、FAQ

本页按症状提供排查入口。需要完整步骤时，查看对应的开发指南或语义规范。

## 1. 旧文档和代码对不上？

先看[当前状态](../current-status.md)。产品范围以根目录协作文件为准，实际能力以 `Package.swift`、源码及测试结果为准。

| 旧说法 | 现状 |
| --- | --- |
| 本地 `path:` + SmartCodable | 默认 manifest 已 **pin swift-markdown revision**（ADR-001）；`Packages/Caches` + `path:` 仅作为可选离线路径。SmartCodable 未使用 |
| iOS / iPadOS / 其他平台 | 当前产品路线仅承诺 iOS 15+ / iPadOS 15+；不支持其他平台。已发布 `0.0.1` 为 UIKit-first；未发布的 v0.0.2 已有 SwiftUI adapter 及新版 Simulator 基础测试，iOS/iPadOS 15 验证尚未交付 |
| `customTableBlockFactory` / `InkTableStyleConfig` | `InkBlockHandler` + `InkAppearance.Table` |

## 2. 表格变成一堆 `|`？

走了 `InkAttributedRenderer`。表格节点在富文本通道没有布局，必须走块路由：

```swift
let blocks = InkBlockRenderer.render(source)  // 默认含 InkTableBlockHandler
for b in blocks { stack.addArrangedSubview(b.makeView()) }
```

## 3. 标题里代码被加粗 / 引用里链接变引用色？

事后 enumerate 覆盖导致。改用 `InkTextContext` 派生（[03 §3.2](03-principles.md)）。

## 4. 自定义字体斜体无效？

没有 italic 变体时 `withSymbolicTraits` 失败 → context 退回 `obliqueness = 0.25` 伪斜体。属于预期兜底行为。

## 5. 流式卡顿 / 跳动 / 滑动掉帧？

| 旋钮 | 作用 |
| --- | --- |
| `charactersPerFrame`（默认 2） | 每帧吐字 |
| `isDisplayPaused` | 滑动时暂停 textStorage 写入 |
| `maximumSourceLength`（默认 50_000） | 超长停解析 |
| 流式表 `referenceRows` / `columnMaxWidthRatio` | 降低列宽跳动 |

## 6. 图片只有 `[🖼 …]`？

**默认如此**（`InkImageRendering.isEnabled` 默认 `false`，契约见 [ADR-004](../decisions/ADR-004-v1-image-and-strikethrough-contract.md)）。占位串：`plainText`，否则 `source`，再否则 `"image"`。

**需要真图时**：详见 [ADR-006](../decisions/ADR-006-opt-in-image-rendering.md)。将 `appearance.imageRendering.isEnabled` 设为 `true` 后，空 `allowedHosts` 默认 **允许** 所有满足资源安全边界的 HTTP(S) host（业务策略默认开放）。域名 allowlist 是可选业务配置，不是开启真图的前置条件。

库始终执行资源安全边界：scheme、HTTP 2xx、有效图片数据、默认最多 3 次重定向、默认可配置的 20 MiB 响应上限；相对 URL 需提供 `baseURL`，否则明确失败并走占位。

宿主通常需要：

1. `isEnabled = true`
2. （可选）配置 `allowedHosts` / `emptyHostPolicy`，或注入自定义 loader
3. （可选）设置 `baseURL` 以解析相对图片地址

ExampleApp **2. 自定义组件与富媒体**（`SwiftUIComponentsDemoView` / `UIKitComponentsDemoViewController`）通过 `DemoInkConfigurationBuilder.makeComponentsConfiguration()` 显式收窄到演示 CDN（`placehold.co`、`picsum.photos`）并提供 `demoImageEnabled` 开关；这是 Example 验收预设，不是库默认。走查细节见 [ExampleApp 走查 SSOT](../qa/example-app-walkthrough-issues.md#p2--自定义组件与富媒体)。

库内提供行内 `InkImageAttachment`、独占块 `InkImageBlock`、`InkImageStore` 与 `ImageSecurityPolicy`。`Image` 是 **InlineMarkup**，纯块 handler 拦不住行内节点；库内独占段提升由 `InkImageBlockHandler` 负责。亦可自定义 `InkInlineSyntax` 或 `sourceFilter` 预处理图片语法。

图片资源预算以 [ADR-011](../decisions/ADR-011-image-store-configuration-ownership.md) 为准：显式注入 Store 时，由宿主配置该 Store；默认路径根据完整 `storeConfiguration` 隔离预算。不要同时依赖注入 Store 与渲染配置互相覆盖。运行时提高 Store 并发上限会启动已排队请求；缩容保留已接受的请求，不静默取消。

## 7. 怎么加自定义行内语法扩展 / 块级组件路由？

见 [04 开发与自定义扩展](04-development.md)。

## 8. 改 appearance 默认值测试红了？

`appearance_defaultValues` 与 `fixedLineHeight_*` 是契约。改行为必须改测试。

## 9. 当前支持哪些平台？

当前产品路线仅支持 iOS 15+ / iPadOS 15+，不支持其他平台（[ADR-008](../decisions/ADR-008-swiftui-adapter-architecture.md)）。`Package.swift` 已仅声明 `.iOS(.v15)`，源码直接依赖 UIKit；这不构成 macOS、tvOS、watchOS 或 visionOS support promise。当前全量回归证据来自 iPhone 17 Pro Max / iOS 26.5；最低版本验证仍是 v0.0.2 release blocker；以[当前状态](../current-status.md)为准。

## CI 红了但本机绿？

先看 [CI 与工具链排坑](07-ci-and-toolchain-pitfalls.md)。摘要：

- CI **不读**你本机 Xcode；合并以钉死环境为准（当前 Xcode 26.6 + iPhone 17 Pro / iOS 26.5）。
- 本机用 Xcode 27 开发可以，但新 API / 更严诊断可能导致「本地过、CI 不过」——按 CI 修或显式抬高 CI 版本。
- 常见失败：钉死的 Xcode 路径在 runner 镜像中消失、模拟器 OS 变更、`Package.resolved` / revision、误用 macOS destination。

## 10. 会不会改成只支持 TextKit 2？

不会作为 v1/v2 默认。库内自定义绘制（代码底、引用线）走 **TextKit 1**。TextKit 2 只做长文 / 迁移试探。

宿主只用 attributed 字符串时，引擎由其所在 `UITextView` 决定；要完整视觉请用库的 block / 绑定流式 API。

流式渲染时控制台可能出现 TextKit 1 / `layoutManager` 相关警告，属 v1 刻意路径下的**预期日志**，不是待修 defect。ExampleApp 走查见 [P3.1](../qa/example-app-walkthrough-issues.md#p31-textkit-1-layoutmanager-警告)。

## 11. 拉不动依赖 / 离线构建？

运行 `./Packages/scripts/fetch-packages.sh` 可准备 `Packages/Caches/`。当前 manifest 尚未统一切换为 `path:`，不要把个人临时修改作为项目标准提交；依赖策略差异记录在[当前状态](../current-status.md)。

## 12. 左右对不齐 / 无水平边距？

`blockInsets` 默认 `.zero`，边距归宿主。需要时覆盖 `blockInsets`。

## 13. 链接点不动 / 被系统抢走？

传 `linkTapHandler`，返回 `true` 表示已处理。有自定义 handler 时关闭 `dataDetectorTypes`。表格单元格用 `InkTableCellTextView`，同一套回调。

## 14. Swift 版本报错？

需要 **6.2+** 工具链；库用 `.swiftLanguageMode(.v5)`。

## 15. 单测某一段？

```swift
InkAttributedRenderer.render(markups: [node])
// 或看 InkBlockRenderer 是否命中 handler
// attributes(at:effectiveRange:) 查样式
```

完整测试必须指定 iOS Simulator；不要在 macOS host 上直接运行 `swift test`。命令见[开发指南](04-development.md#构建与测试)。

## 16. 公式与图表怎么 opt-in？

LaTeX / Mermaid 默认关闭，且是独立 product。完整 opt-in 顺序：

1. 将 `InkMarkdownLaTeX` / `InkMarkdownMermaid` product 链接到宿主 target。
2. `import InkMarkdownLaTeX` / `import InkMarkdownMermaid`。
3. 在渲染前调用 `InkMarkdownLaTeX.register()` / `InkMarkdownMermaid.register()`。
4. 再开启 `config.enableLaTeXRendering()` 或 `appearance.mermaidRendering.isEnabled = true`。

只打开样式开关而没有注册 addon 时，生成图 loader 会明确报告对应 owner 未注册；不会悄然退回为另一套渲染实现。行内 LaTeX 可用 `config.enableLaTeXRendering()`（或 `appearance.latexRendering.isEnabled = true`）；Mermaid 用 `appearance.mermaidRendering.isEnabled = true`。块级 `$$`、`\[\]` 与 ` ```mermaid ` 须走 **`InkBlockRenderer`**，纯 `InkAttributedRenderer` 仅文本回退。ExampleApp SSE 演示的是 Demo 全量 **`InkBlockRenderer`** 路径，不是 `InkStreamRenderer` 增量 API。

## 17. SwiftUI 中修改配置或环境导致界面卡死 / 内存暴涨（OOM 崩溃）？

**症状**：在 SwiftUI 界面中切换与 `InkConfiguration` 相关的 `@State`（如字号、段落间距、主题等），界面瞬间卡死，内存极速暴涨（数百 MB 至数 GB），随后被系统 Jetsam 强杀（`Terminated due to memory issue`, Code 9）。

**根因**：`UIViewRepresentable.updateUIView` 缺乏幂等脏检查。
- SwiftUI 在状态变更和布局测量阶段会多次调用 `updateUIView`。
- 若在 `updateUIView`（或 Coordinator 的 `updateStatic`）中无条件全量解析 Markdown、清空重配子视图并调用 `invalidateIntrinsicContentSize()`，会导致 SwiftUI 认为尺寸改变并重新发起 layout pass，再次调用 `updateUIView`，陷入**主线程递归更新死循环**，每秒分配数千个 TextKit 对象导致内存耗尽。
- 此外，在 `layoutSubviews()` 内部调用 `invalidateIntrinsicContentSize()` 也会强化这一循环。

**解决方案**：
1. **Coordinator 幂等脏检查**：`InkMarkdownCoordinator` 缓存上次渲染的 `markdown` 与 `configuration` 快照，使用 `isSemanticallyEqualTo(_:)` 进行语义比对；无语义变化时直接跳过重建。
2. **纯化布局生命周期**：严禁在 `layoutSubviews()` 中调用 `invalidateIntrinsicContentSize()`；仅在内容源或配置发生实际变更时由 Coordinator 或数据源发起失效。
3. **为重建型依赖提供稳定语义身份**：SwiftUI `body` 若反复构造行为等价的闭包或 loader，应通过 `setSourceFilter(_:semanticIdentity:)`、`setLinkTapHandler(_:semanticIdentity:)`、`InkImageRendering` 的语义 setter 等 API 传入稳定的 `InkSemanticIdentity`；捕获状态会改变行为时必须同步更换 identity。直接赋值仍会保守地视为新语义，避免旧回调或旧 loader 被错误复用。
4. 详细排坑见 [09 SwiftUI UIViewRepresentable 踩坑指南 §1、§6、§22](09-swiftui-uiviewrepresentable-gotchas.md)。

## 18. SwiftUI / UIKit 混编报错 `Unable to simultaneously satisfy constraints` / Auto Layout 零尺寸冲突？

**症状**：控制台输出 `<NSAutoresizingMaskLayoutConstraint: ... height == 0>` 与 `UIScrollView` / `UILabel` 内部约束冲突报错，且代码块、表格在初次测量时可能高度显示异常。

**根因**：自定义 UIKit Block View（如 `InkCodeBlockViewImpl`、`InkTableBlockView`、`InkThematicBreakBlock`）内部使用了 Auto Layout，但**未重写 `sizeThatFits(_:)` 与 `intrinsicContentSize`**。
- Frame 容器（如 `InkMarkdownContainerView`）通过 `view.sizeThatFits(...)` 测量子视图时，默认 `UIView.sizeThatFits` 返回 `(0, 0)`。
- 容器将其 frame 设置为高 0，由于视图默认开启 `translatesAutoresizingMaskIntoConstraints = true`，系统生成了 `height == 0` 的约束，与子控件固定高度/内边距约束直接冲突。

**解决方案**：
1. **重写 `sizeThatFits` 与 `intrinsicContentSize`**：所有自定义 Block View 必须提供确定性的尺寸测量（如代码块按字号行高 padding 算高、表格按 StackView fittingSize 算高、分割线按线宽留白算高）。
2. **布局解耦**：简单容器改用 Frame 布局（`layoutSubviews`）；复杂 Auto Layout 视图内部的父子约束应将坚硬的底部 pinning 优先级设为 999（`defaultHigh`），避免与临时零尺寸 mask 产生硬冲突。
3. **首轮有限宽**：chat / table 宿主在 layout 前若已知终态内容宽，设置 `preferredMeasurementWidth` / `.preferredMeasurementWidth(_:)`，避免零宽测量与二次抬高。完整契约见 [13 布局测量契约](13-layout-measurement-contract.md)。
4. 详细排坑见 [09 SwiftUI UIViewRepresentable 踩坑指南 §11](09-swiftui-uiviewrepresentable-gotchas.md)。

## 19. 控制台噪声（Simulator / 系统）

以下日志在 ExampleApp 走查中常见，**多数可忽略**，不必当作 InkMarkdown 缺陷上报。完整症状、复现与归因见 [ExampleApp 走查 SSOT](../qa/example-app-walkthrough-issues.md)。

| 噪声类型 | 典型关键字 | 归因 | 处理 |
| --- | --- | --- | --- |
| LaunchServices / 沙盒 | `canmaplsdatabase`、`sandbox extension` | 系统 | 点链接仍可跳转；Example 已用 `DemoLinkOpening.inkHandler` |
| RunningBoard (RBS) | `RBSAssertionErrorDomain`、`Unable to obtain a task name port right` | 系统 | Simulator 进程权限噪音；与渲染无关，**只文档化** |
| WebKit / Mermaid | `GPU IdleExit`、`Failed to terminate`、`web-browser-engine` | 系统 + Mermaid 离线渲染 | **只文档化**；不申请 web-browser-engine entitlement |
| TextKit 1 | `layoutManager` 相关 | 库契约（v1 刻意 TextKit 1） | 见 [§10](#10-会不会改成只支持-textkit-2) |
| 第三方 IME | 搜狗输入法、`usermanagerd` | 系统 / 第三方 | Chat 输入时常见，与渲染无关 |
| 键盘占位 | `UIKeyboardImpl`、`placeholder`、InputSystem 相关 | 系统 | Chat 输入框聚焦/切换键盘时的 Simulator 噪音，**只文档化** |

SwiftUI adapter 的 Publishing / 会话 defer 见 [09 §12](09-swiftui-uiviewrepresentable-gotchas.md#12-publishing-与-session-defer)。Chat 滚动粘底与流式吐字暂停见 ExampleApp `ChatScrollPolicy`（[P4](../qa/example-app-walkthrough-issues.md#p4--ai-sse-对话)）；`shouldPauseDisplay` 仅在用户拖拽/减速期间为 true，由 `session.isDisplayPaused` 转发至 renderer。
