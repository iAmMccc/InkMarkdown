# 四、开发指南

## 环境

| 项 | 要求 |
| --- | --- |
| macOS + Xcode | 能提供 Swift 6.2 工具链（Xcode 15+） |
| Swift | 6.2+（`swift --version`） |
| 平台 | 仅 iOS 14+（`Package.swift`） |
| 网络 | `swift build` 需拉 GitHub 上的 `swift-markdown` |

## 构建 / 测试

```bash
git clone <repo> && cd InkMarkdown
swift build
swift test
swift package clean && rm -rf .build   # 清理
```

| 测试文件 | 内容 |
| --- | --- |
| `InkMarkdownTests.swift` | 固定行高、context 样式、流式边界、appearance 默认值 |
| `Snapshots/` | 语义属性快照基建（`RenderSnapshot`） |
| `StreamingPerformanceTests.swift` | 增量 ≤ 全量 30% 时长 + 一致性 |

改核心前先 `swift test`。

## ExampleApp

```bash
open ExampleApp/ExampleApp.xcodeproj
```

| 入口 | 作用 |
| --- | --- |
| `CategoryListViewController` / `DemoCatalog` | 功能目录 |
| `SSE/` | 模拟流式 + 流式表 |
| `BlockRendering/` | 块扩展 demo |
| `ServerMarkdownViewController` 等 | 完整渲染 |

宿主只需 `import InkMarkdown`（`@_exported import Markdown`，不必再链 Markdown target）。

## 依赖

当前 `Package.swift`：

```swift
.package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main")
```

离线：

```bash
./Packages/scripts/fetch-packages.sh   # → Packages/Caches/
# 再把 Package.swift 改为 path: "Packages/Caches/swift-markdown" 并自测
```

`Packages/Caches/` 已 gitignore，不要提交。

## 规范

- 源码 `Sources/InkMarkdown/`，测试 `Tests/InkMarkdownTests/`
- 公开 API：`///` 中文文档（用途 / 参数 / 返回 / 用法）
- 内部注释写「为什么」
- 公开行为变更时，同步 README 中英与本目录文档
- 不要提交 `.build/`、`Packages/Caches/`、`DerivedData/`、`xcuserdata/`

## 扩展

### 行内：`InkInlineSyntax`

```swift
struct TagInlineSyntax: InkInlineSyntax {
  func render(text: String, context: InkInlineContext) -> NSAttributedString? {
    guard text.hasPrefix("$"), text.hasSuffix("$"), text.count > 2 else { return nil }
    let label = String(text.dropFirst().dropLast())
    return NSAttributedString(string: "#\(label)", attributes: [
      .font: context.baseFont,
      .foregroundColor: UIColor.systemBlue,
    ])
  }
}

let config = InkConfiguration(inlineSyntaxes: [TagInlineSyntax()])
let attr = InkAttributedRenderer.render(source, configuration: config)
```

`nil` = 交给下一个扩展或默认。基于 `context.baseFont` / `textColor`，才能跟容器匹配。

### 块：`InkBlockHandler`

```swift
struct MyCodeBlockHandler: InkBlockHandler {
  func canHandle(_ markup: Markup) -> Bool { markup is CodeBlock }
  func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let code = markup as? CodeBlock else { return nil }
    return MyFancyCodeCard(code: code.code)
  }
}

var config = InkConfiguration.standard
config.blockHandlers = [MyCodeBlockHandler(), InkTableBlockHandler(), InkThematicBreakHandler()]
let blocks = InkBlockRenderer.render(source, configuration: config)
```

### 其它

- `sourceFilter`：解析前改字符串
- `linkTapHandler`：拦截 `.link`；有自定义 handler 时关闭 `dataDetectorTypes`

## 推荐流程

1. `swift test` 基线绿
2. 优先走扩展点，不写只治症状的补丁
3. 补 `@Test`
4. `swift build` + `swift test` + ExampleApp 目测
5. 公开 API 变更时更新文档

## 调试

| 症状 | 查 |
| --- | --- |
| 流式卡顿 | `charactersPerFrame`、`isDisplayPaused`、`maxParseLength` |
| 样式错 | `attributes(at:effectiveRange:)`；有 enumerate 回写就改 context |
| 表格列宽 | `measureColumnContentWidths`、`columnMaxWidthRatio` |
