# 六、FAQ

本页按症状给出第一检查点和权威文档入口。需要完整操作步骤时，继续阅读对应的开发指南或语义规范。

## 1. 旧文档和代码对不上？

先看[当前状态](../current-status.md)。产品范围以根目录协作文件为准；已交付能力以
`Package.swift`、源码和通过的测试为证据。

| 旧说法 | 现状 |
| --- | --- |
| 本地 `path:` + SmartCodable | 默认 manifest 已 **pin swift-markdown revision**（ADR-001）；`Packages/Caches` + `path:` 仅为可选离线手段。SmartCodable 未使用 |
| iOS / macOS / tvOS / watchOS | 目标平台矩阵尚未全部落地；当前只验证 `.iOS(.v14)` |
| `customTableBlockFactory` / `InkTableStyleConfig` | `InkBlockHandler` + `InkAppearance.Table` |

## 2. 表格变成一堆 `|`？

走了 `InkAttributedRenderer`。表格节点在富文本通道没有布局，必须走块路由：

```swift
let blocks = InkBlockRenderer.render(source)  // 默认含 InkTableBlockHandler
for b in blocks { stack.addArrangedSubview(b.makeView()) }
```

## 3. 标题里代码被加粗 / 引用里链接变引用色？

事后 enumerate 覆盖了。改用 `InkTextContext` 派生（[03 §3.2](03-principles.md)）。

## 4. 自定义字体斜体无效？

没有 italic 变体时 `withSymbolicTraits` 失败 → context 退回 `obliqueness = 0.25` 伪斜体。有意兜底。

## 5. 流式卡顿 / 跳动 / 滑动掉帧？

| 旋钮 | 作用 |
| --- | --- |
| `charactersPerFrame`（默认 2） | 每帧吐字 |
| `isDisplayPaused` | 滑动时暂停 textStorage 写入 |
| `maxParseLength`（50_000） | 超长停解析 |
| 流式表 `referenceRows` / `columnMaxWidthRatio` | 降低列宽跳动 |

## 6. 图片只有 `[🖼 …]`？

有意不做下载 / 缓存。占位串：`plainText`，否则 `source`，再否则 `"image"`。

真图路径（`Image` 是 **InlineMarkup**，不能靠块 handler 拦整块）：

- 自定义 `InkInlineSyntax`，或改 attributed 行内分支
- 或 `sourceFilter` 预处理图片语法

## 7. 怎么加行内 / 块扩展？

见 [04 扩展](04-development.md)。

## 8. 改 appearance 默认值测试红了？

`appearance_defaultValues` 与 `fixedLineHeight_*` 是契约。改行为必须改测试。

## 9. 为何文档写过多平台、Package 只有 iOS？

这是“目标平台矩阵”和“已验证交付平台”的区别。当前源码直接依赖 UIKit，
`Package.swift` 也只声明 `.iOS(.v14)`，因此对外只宣称 iOS 14+。其它平台必须完成条件编译与验证后才能标记为已支持，见[当前状态](../current-status.md)。

## CI 红了但本机绿？

先看 [CI 与工具链排坑](07-ci-and-toolchain-pitfalls.md)。摘要：

- CI **不读**你本机 Xcode；合并以钉死环境为准（当前 Xcode 26.6 + iPhone 17 Pro / iOS 26.5）。
- 本机用 Xcode 27 开发可以，但新 API / 更严诊断可能导致「本地过、CI 不过」——按 CI 修或显式抬高 CI 版本。
- 常见失败：钉死的 Xcode 路径在 runner 镜像中消失、模拟器 OS 变更、`Package.resolved` / revision、误用 macOS destination。

## 10. 会不会改成只支持 TextKit 2？

不会作为 v1/v2 默认。库内自定义绘制（代码底、引用线）走 **TextKit 1**。TextKit 2 只做长文 / 迁移试探。

宿主只用 attributed 字符串时，引擎由其所在 `UITextView` 决定；要完整视觉请用库的 block / 绑定流式 API。

## 11. 拉不动依赖 / 离线构建？

运行 `./Packages/scripts/fetch-packages.sh` 可准备 `Packages/Caches/`。当前 manifest
尚未统一切换为 `path:`，不要把个人临时修改作为项目标准提交；依赖策略差异记录在
[当前状态](../current-status.md)。

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

完整测试必须指定 iOS Simulator；不要在 macOS host 上直接运行 `swift test`。命令见
[开发指南](04-development.md#构建与测试)。
