# 四、开发指南

本页提供从环境准备、构建测试到扩展和调试的开发流程。它是构建与测试命令的唯一维护入口。

## 准备开发环境

| 项 | 要求 |
| --- | --- |
| macOS + Xcode | 能提供 Swift 6.2 工具链；以 `swift --version` 为准 |
| Swift | 6.2+（`swift --version`） |
| 平台 | 仅 iOS 14+（`Package.swift`） |
| iOS Simulator | 至少安装一个可用设备 |
| 网络 / 缓存 | 当前 manifest 首次解析需访问 GitHub；本地缓存脚本见下文 |

## 构建与测试

InkMarkdown 直接依赖 UIKit。不要在 macOS host 上用 `swift build` 或 `swift test` 判断库是否可用；它们会因缺少 UIKit 失败。请在 iOS Simulator 上验证。

### 原生 xcodebuild：任何人都能跑的基线路径

这条路径不依赖任何 AI 客户端或 MCP 服务，`git clone` 之后就能独立跑通，是本项目构建与测试的基线方式。

```bash
git clone <本仓库地址>
cd InkMarkdown
xcrun simctl list devices available   # 确认本机可用的 iOS Simulator 名称
```

构建：

```bash
xcodebuild -scheme InkMarkdown -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build
```

测试：

```bash
xcodebuild -scheme InkMarkdown -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' test
```

本机若没有 `iPhone 17 Pro` 这个模拟器，把 `name=` 换成上一步 `xcrun simctl list devices available` 列出的任意可用设备名，`OS=latest` 保持不变即可。

改核心代码前后都跑一遍测试。这两条命令也是 `.github/workflows/ci.yml` 门禁的本地对照（见下文「CI 与本机工具链」）。

### 使用 XcodeBuildMCP（AI 客户端可用时的加速路径）

当前 AI 客户端若已注册 XcodeBuildMCP 工具，可以用它代替上面的手动命令：自动发现 project / scheme / simulator，并把结果整理成结构化摘要，省去手动拼 `destination` 字符串。

按以下顺序运行：

1. 查看当前 session defaults。
2. 仅在 project、scheme 或 simulator 缺失时，使用项目发现和 simulator 列表。
3. 选择 `InkMarkdown` scheme 和一个可用的 iOS Simulator，不要写死 UUID。
4. 运行 simulator tests。
5. 记录实际 scheme、destination、测试数量和失败摘要。

这条路径跑出的结果应该和上面的原生 `xcodebuild test` 一致。如果 XcodeBuildMCP 当前不可用、报错，或你就是想要人可读的原始命令行输出，直接改用上面的原生命令即可，不必先排查 MCP 为什么不可用。

### 修复 XcodeBuildMCP 加载问题

当前会话没有暴露 XcodeBuildMCP 工具时，先检查本机状态：

```bash
command -v xcodebuildmcp
xcodebuildmcp --version
```

- 找不到二进制：按 [XcodeBuildMCP 官网](https://www.xcodebuildmcp.com/)说明安装并注册 MCP 服务。
- 二进制存在：检查客户端是否以 `xcodebuildmcp mcp` 启动服务，然后重载客户端或新建会话。

排查无果或不想排查时，直接用上一节的原生 `xcodebuild` 命令，不影响后续开发。

### 最近验证记录

| 项目 | 结果 |
| --- | --- |
| 日期 | 2026-07-13 |
| Scheme | `InkMarkdown` |
| Destination | iPhone 17 Pro / iOS 26.5 Simulator |
| 测试 | 32 项通过，0 项失败，0 项跳过 |
| 工具路径 | XcodeBuildMCP 完成发现；SwiftPM test workflow 未暴露后回退原生 `xcodebuild` |

测试源码中共有 32 个 `@Test`，与测试结果一致。测试文件分工如下：

| 测试文件 | 内容 |
| --- | --- |
| `InkMarkdownTests.swift` | 固定行高、context 样式、流式边界、appearance 默认值 |
| `Snapshots/` | 语义属性快照基建（`RenderSnapshot`） |
| `StreamingPerformanceTests.swift` | 增量 ≤ 全量 30% 时长 + 一致性 |

改核心前后都要运行 iOS Simulator 测试。

### 清理构建产物

清理 SPM 产物可使用：

```bash
swift package clean
rm -rf .build
```

## 运行 ExampleApp

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

## 准备 swift-markdown 依赖

默认（ADR-001）：`Package.swift` **固定 revision** 引用远程 swift-markdown：

```swift
.package(
    url: "https://github.com/swiftlang/swift-markdown.git",
    revision: "07ebc9c071b22a5d021031b798c3a84b76281213"
)
```

升级依赖：改 revision → `swift package resolve` / Xcode resolve → 更新 `Package.resolved` →
iOS Simulator 全量测试（或推送触发 CI）。

可选离线（网络受限本机）：

```bash
./Packages/scripts/fetch-packages.sh   # → Packages/Caches/
```

然后在**本地临时**改为 `path:` 覆盖；不要把 path 当作默认发布 manifest 提交。
`Packages/Caches/` 已 gitignore，不要提交。

## CI 与本机工具链

- **权威门禁**：`.github/workflows/ci.yml` 钉死的 Xcode / 模拟器（见文件顶部 `env`）。
- **本机**：推荐 Xcode 26.x，最低需能处理 tools 6.2 并在 iOS Simulator 上测试；不必与 CI 补丁号完全一致。
- **排坑**（本机绿 CI 红、升级钉死版本、开源协作影响）：[07-ci-and-toolchain-pitfalls.md](07-ci-and-toolchain-pitfalls.md)。

## 遵守代码与提交规范

- 源码 `Sources/InkMarkdown/`，测试 `Tests/InkMarkdownTests/`
- 公开 API：`///` 中文文档（用途 / 参数 / 返回 / 用法）
- 内部注释写「为什么」
- 公开行为变更时，同步 README 中英与本目录文档
- 不要提交 `.build/`、`Packages/Caches/`、`DerivedData/`、`xcuserdata/`

## 最小第一次改动

在动手写自定义 `InkInlineSyntax` 或 `InkBlockHandler` 之前，先做能最快看到效果的小改动：渲染一段字符串，或者调一个 `InkAppearance` 的值（比如 `InkAppearance.shared.text.fontSize`），在 ExampleApp 里确认真的生效了。跑通「改一个值 → 在 ExampleApp 里看到变化」这条最短链路后，再看下面的扩展点示例写自定义 handler / syntax，遇到问题也更容易判断是扩展点写错了还是环境没搭对。

最短第一次运行：

1. 打开 `ExampleApp/ExampleApp.xcodeproj`（或 `open ExampleApp/ExampleApp.xcodeproj`）。
2. Scheme 选 `ExampleApp`，选一个可用的 iOS Simulator，Cmd-R 运行。
3. 在 App 中打开任一标准样式样例，确认能看到渲染结果与源码页切换。
4. 再改一处 `InkAppearance` / 渲染输入，热重跑确认变化可见。

## 添加自定义语法与组件路由扩展

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

`nil` = 交给下一个自定义行内语法扩展或默认。基于 `context.baseFont` / `textColor`，才能跟容器匹配。

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

### 使用 sourceFilter 和 linkTapHandler

- `sourceFilter`：解析前改字符串
- `linkTapHandler`：拦截 `.link`；有自定义 handler 时关闭 `dataDetectorTypes`

## 完成一次开发改动

1. iOS Simulator 测试基线绿
2. 优先走扩展点，不写只治症状的补丁
3. 补 `@Test`
4. iOS Simulator 测试 + ExampleApp 目测
5. 公开 API 变更时更新文档

## 排查常见渲染问题

| 症状 | 查 |
| --- | --- |
| 流式卡顿 | `charactersPerFrame`、`isDisplayPaused`、`maxParseLength` |
| 样式错 | `attributes(at:effectiveRange:)`；有 enumerate 回写就改 context |
| 表格列宽 | `measureColumnContentWidths`、`columnMaxWidthRatio` |

## 下一步

- 修改渲染行为前，先查[渲染语义规范](../spec/README.md)。
- 不确定代码位置时，查[模块详解](05-modules.md)。
- 遇到已有症状时，查[FAQ](06-faq.md)。
