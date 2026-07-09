# 六、FAQ

## 1. 旧文档和代码对不上？

以 **源码 + 本 guide** 为准。

| 旧说法 | 现状 |
| --- | --- |
| 本地 `path:` + SmartCodable | 远程 `swiftlang/swift-markdown`，无 SmartCodable |
| iOS / macOS / tvOS / watchOS | 仅 `.iOS(.v14)` |
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

早期规划。当前**只承诺 iOS 14+**。多平台是远期试探（[roadmap](../roadmap.md) Phase D），不默认进正式支持。

## 10. 会不会改成只支持 TextKit 2？

不会作为 v1/v2 默认。库内自定义绘制（代码底、引用线）走 **TextKit 1**。TextKit 2 只做长文 / 迁移试探。

宿主只用 attributed 字符串时，引擎由其所在 `UITextView` 决定；要完整视觉请用库的 block / 绑定流式 API。

## 11. 拉不动依赖 / 离线构建？

```bash
./Packages/scripts/fetch-packages.sh
# Package.swift → path: "Packages/Caches/swift-markdown"
```

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
