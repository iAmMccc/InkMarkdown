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

### 使用 XcodeBuildMCP

按以下顺序运行：

1. 查看当前 session defaults。
2. 仅在 project、scheme 或 simulator 缺失时，使用项目发现和 simulator 列表。
3. 选择 `InkMarkdown` scheme 和一个可用的 iOS Simulator，不要写死 UUID。
4. 运行 simulator tests。
5. 记录实际 scheme、destination、测试数量和失败摘要。

如果 XcodeBuildMCP 成功完成测试，到这里结束。不要再重复运行原生命令。

### 修复 XcodeBuildMCP 加载问题

当前会话没有暴露 XcodeBuildMCP 工具时，先检查本机状态：

```bash
command -v xcodebuildmcp
xcodebuildmcp --version
```

- 找不到二进制：按 [XcodeBuildMCP 官网](https://www.xcodebuildmcp.com/)说明安装并注册 MCP 服务。
- 二进制存在：检查客户端是否以 `xcodebuildmcp mcp` 启动服务，然后重载客户端或新建会话。

### 回退到原生 xcodebuild

只有以下情况可以回退：

- 当前 MCP 客户端没有暴露 SwiftPM package test workflow。
- XcodeBuildMCP 返回 scheme 未配置 test action 等结构化诊断。
- 正在诊断 XcodeBuildMCP 本身。

先从项目根目录查询本机可用 simulator，再替换命令中的名称：

```bash
xcrun simctl list devices available
xcodebuild \
  -scheme InkMarkdown \
  -destination 'platform=iOS Simulator,name=<simulator-name>,OS=latest' \
  test
```

回退后记录原因，不要把这条命令写成默认流程。

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

当前 `Package.swift` 使用远程依赖：

```swift
.package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main")
```

项目的目标开发策略是使用 `Packages/Caches/` 中的本地依赖。拉取缓存：

```bash
./Packages/scripts/fetch-packages.sh   # → Packages/Caches/
```

当前 manifest 尚未切到 `path:`，这是已记录的知识 / 配置漂移，见
[当前状态](../current-status.md)。不要在个人改动中临时改 manifest 后提交；应通过独立变更统一依赖策略并验证。`Packages/Caches/` 已 gitignore，不要提交。

## 遵守代码与提交规范

- 源码 `Sources/InkMarkdown/`，测试 `Tests/InkMarkdownTests/`
- 公开 API：`///` 中文文档（用途 / 参数 / 返回 / 用法）
- 内部注释写「为什么」
- 公开行为变更时，同步 README 中英与本目录文档
- 不要提交 `.build/`、`Packages/Caches/`、`DerivedData/`、`xcuserdata/`

## 添加渲染扩展

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
