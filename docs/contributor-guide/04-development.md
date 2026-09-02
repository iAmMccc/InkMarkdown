# 四、开发指南

本文介绍从准备环境、运行构建与测试，到添加扩展与调试的开发流程。

## 准备开发环境

| 项目 | 要求 |
| --- | --- |
| macOS + Xcode | 提供 Swift 6.2 工具链；以 `swift --version` 输出为准 |
| Swift | 6.2+ |
| 目标平台 | 已发布 `0.0.1`：iOS 14+；v0.0.2 目标：iOS / iPadOS 14+（最低版本运行验证待完成） |
| iOS 模拟器 | 安装至少一个可用模拟器 |
| 网络/缓存 | 首次解析远程依赖需联网；离线缓存脚本见后文 |

## 构建与测试

InkMarkdown 依赖 UIKit。由于 macOS 环境缺少 UIKit，请勿在 macOS host 上直接运行 `swift build` 或 `swift test`，需使用 iOS 模拟器进行构建和测试。

### 使用 xcodebuild 命令

```bash
git clone <repository-url>
cd InkMarkdown
xcrun simctl list devices available   # 查看本机可用的 iOS 模拟器名称
```

构建命令：

```bash
xcodebuild -scheme InkMarkdown -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build
```

测试命令：

```bash
xcodebuild -scheme InkMarkdown-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' test
```

如果本机没有 `iPhone 17 Pro` 模拟器，将 `name=` 替换为 `xcrun simctl list devices available` 中列出的任意设备名称。

这两条命令也是 CI（`.github/workflows/ci.yml`）门禁的本地运行方式。

### 使用 XcodeBuildMCP

已注册 XcodeBuildMCP 工具时，可以使用该工具自动查找 project、scheme 及 simulator 并进行构建测试。

步骤如下：

1. 查看当前 session 配置。
2. 测试选择 `InkMarkdown-Package` scheme 与可用的 iOS 模拟器；`InkMarkdown` scheme 仅用于 build。
3. 运行模拟器测试。
4. 检查测试数量与结果。

若 XcodeBuildMCP 不可用或出现异常，直接使用上文的 `xcodebuild` 原生命令。

### 修复 XcodeBuildMCP 加载问题

如果工具未正常加载，先检查本机状态：

```bash
command -v xcodebuildmcp
xcodebuildmcp --version
```

- 若找不到二进制文件：按 [XcodeBuildMCP 官网](https://www.xcodebuildmcp.com/) 说明安装与注册服务。
- 若二进制文件存在：检查是否通过 `xcodebuildmcp mcp` 启动服务，然后重载客户端。

### 当前验证记录

| 项目 | 结果 |
| --- | --- |
| 日期 | 2026-09-01 |
| Package scheme | `InkMarkdown-Package` |
| App-hosted scheme | `ExampleApp` / `ExampleAppMermaidIntegrationTests` |
| Destination | iPhone 17 Pro / iOS 26.5 Simulator |
| Package 测试结果 | 2026-09-02 本地候选：333 通过，0 失败，1 跳过（本机无 iOS 14 runtime）；非远端 CI |
| App-hosted 测试结果 | Mermaid PNG/右缘裁切关键链路 1 项通过 |
| 运行方式 | XcodeBuildMCP transport 关闭后按仓库规则回退原生 `xcodebuild`；结果由 `xcresulttool` 结构化确认 |

测试文件分布：

| 测试文件 | 测试内容 |
| --- | --- |
| `InkMarkdownTests.swift` | 固定行高、context 样式、流式边界、appearance 默认值 |
| `Snapshots/` | 语义属性快照基建（`RenderSnapshot`） |
| `StreamingPerformanceTests.swift` | 增量耗时 ≤ 全量耗时 30% 性能闸门及输出一致性 |
| `../InkMarkdownSwiftUITests/` | 静态配置刷新、stream session 状态机、headless finish、重置和 configuration snapshot |
| `ExampleApp/ExampleAppMermaidIntegrationTests/` | 由真实 App 生命周期承载唯一 Mermaid WebKit → PNG → 右缘像素关键链路 |

### 清理构建产物

清理 SPM 产物：

```bash
swift package clean
rm -rf .build
```

## 运行 ExampleApp

```bash
open ExampleApp/ExampleApp.xcodeproj
```

| 目录/文件 | 作用 |
| --- | --- |
| `CategoryListViewController` / `DemoCatalog` | 功能 Demo 目录 |
| `SSE/` | 模拟流式输出与流式表格 |
| `BlockRendering/` | 块级扩展 Demo |
| `ServerMarkdownViewController` | 完整渲染 Demo |
| `SwiftUI/` | SwiftUI adapter 的静态、配置与流式示例，详见 [SwiftUI ExampleApp 指南](10-swiftui-example-app.md) |

UIKit 宿主仅需 `import InkMarkdown`；SwiftUI 示例使用 `import InkMarkdownSwiftUI`，并在 Xcode 工程中链接 `InkMarkdownSwiftUI` product。

## 准备 swift-markdown 依赖

默认配置（ADR-001）：在 `Package.swift` 中**固定 revision** 引用远程 swift-markdown：

```swift
.package(
    url: "https://github.com/swiftlang/swift-markdown.git",
    revision: "07ebc9c071b22a5d021031b798c3a84b76281213"
)
```

升级依赖流程：修改 revision → 运行 `swift package resolve` 或使用 Xcode resolve → 更新 `Package.resolved` → 运行 iOS 模拟器全量测试。

离线环境配置：

```bash
./Packages/scripts/fetch-packages.sh   # 下载至 Packages/Caches/
```

在本地将依赖临时修改为 `path:` 方式覆盖。请勿将本地 path 修改提交至 Git，`Packages/Caches/` 已加入 `.gitignore`。

## CI 与本机工具链

- **权威环境**：`.github/workflows/ci.yml` 指定的 Xcode 与模拟器版本。
- **本机环境**：推荐使用 Xcode 26.x，支持 Swift 6.2 工具链并能在 iOS 模拟器上运行测试即可。
- **踩坑排查**：详见 [07-ci-and-toolchain-pitfalls.md](07-ci-and-toolchain-pitfalls.md)。

## 代码与提交规范

- 源码存放在 `Sources/InkMarkdown/`，测试代码存放在 `Tests/InkMarkdownTests/`
- 公开 API 需添加 `///` 注释（包含用途、参数与返回值说明）
- 内部实现注释重点记录设计逻辑与原因
- 更改公开行为时，需同步更新 README 与相关文档
- 提交前确认排除 `.build/`、`Packages/Caches/`、`DerivedData/`、`xcuserdata/`

## 快速开始改动示例

在编写自定义 `InkInlineSyntax` 或 `InkBlockHandler` 前，可通过修改 `InkAppearance`（如 `InkAppearance.shared.text.fontSize`）在 ExampleApp 中验证链路。

运行步骤：

1. 打开 `ExampleApp/ExampleApp.xcodeproj`。
2. Scheme 选择 `ExampleApp`，选择 iOS 模拟器，按下 `Cmd-R` 运行。
3. 打开样例列表，查看渲染效果与源码展示。
4. 修改样式参数，重新运行确认改动生效。

## 添加自定义扩展

### 行内扩展：`InkInlineSyntax`

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

返回 `nil` 表示交给下一个扩展处理。通过 `context.baseFont` / `textColor` 保持与上下文配置一致。

### 块级路由：`InkBlockHandler`

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

### sourceFilter 与 linkTapHandler

- `sourceFilter`：每次顶层 renderer 调用在解析前执行一次；Thought 正文与 suffix 等派生片段复用 prepared source，不重复执行，因此非幂等 filter 也必须得到稳定结果
- `linkTapHandler`：拦截并响应 `.link` 点击事件

## 开发校验清单

1. iOS 模拟器测试全数通过
2. 通过扩展点实现需求，不直接在核心代码中硬编码临时逻辑
3. 补充对应单元测试 `@Test`
4. 运行模拟器测试并结合 ExampleApp 进行界面验证
5. 修改公开 API 时同步更新文档

## 渲染问题排查指南

| 现象 | 排查位置 |
| --- | --- |
| 流式渲染卡顿 | 检查 `charactersPerFrame`、`isDisplayPaused`、`maximumSourceLength` |
| 样式覆盖或异常 | 检查 `attributes(at:effectiveRange:)`，改为 context 传递模式 |
| 表格列宽错乱 | 排查 `measureColumnContentWidths` 与 `columnMaxWidthRatio` |

## 相关链接

- [渲染语义规范](../spec/README.md)
- [模块详解](05-modules.md)
- [常见问题与解答](06-faq.md)
