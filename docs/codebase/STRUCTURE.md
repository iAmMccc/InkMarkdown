# 目录结构

## 核心布局

### 1) 顶层结构

| 路径 | 作用 | 验证依据 |
|------|---------|----------|
| `Sources/InkMarkdown/` | UIKit-first 核心源码库（SPM target） | `Package.swift` `path: "Sources/InkMarkdown"` |
| `Sources/InkMarkdownSwiftUI/` | 未发布 v0.0.2 的 SwiftUI presentation adapter（SPM target） | `Package.swift` `path: "Sources/InkMarkdownSwiftUI"` |
| `Sources/InkMarkdownLaTeX/` | 未发布 v0.0.2 的 opt-in iosMath addon（SPM target） | `Package.swift` `path: "Sources/InkMarkdownLaTeX"` |
| `Sources/InkMarkdownMermaid/` | 未发布 v0.0.2 的 opt-in WebKit Mermaid addon（SPM target） | `Package.swift` `path: "Sources/InkMarkdownMermaid"` |
| `Tests/InkMarkdownTests/` | UIKit core 测试集（SPM test target） | `Package.swift` `path: "Tests/InkMarkdownTests"` |
| `Tests/InkMarkdownCoreContractTests/` | Core-only product 边界测试（SPM test target） | `Package.swift` core contract testTarget |
| `Tests/InkMarkdownAddonContractTests/` | Addon 注册边界测试（SPM test target） | `Package.swift` addon contract testTarget |
| `Tests/InkMarkdownLaTeXTests/` / `Tests/InkMarkdownMermaidTests/` | addon 关键路径测试（SPM test targets） | `Package.swift` addon testTarget |
| `Tests/InkMarkdownSwiftUITests/` | SwiftUI adapter 契约测试（SPM test target） | `Package.swift` `path: "Tests/InkMarkdownSwiftUITests"` |
| `Tests/ExampleAppPolicyTests/` | ExampleApp 关键业务策略测试（SPM test target） | `Package.swift` ExampleApp policy testTarget |
| `ExampleApp/ExampleAppMermaidIntegrationTests/` | 真实 App 生命周期下的 Mermaid WebKit → PNG 关键链路 | `ExampleApp.xcodeproj` app-hosted unit-test target |
| `ExampleApp/` | UIKit + SwiftUI adapter 示例应用工程 | `ExampleApp/ExampleApp.xcodeproj` |
| `Packages/` | 本地依赖拉取脚本与缓存目录 `Caches/` | `Packages/scripts/fetch-packages.sh` |
| `docs/` | 项目文档与工程事实基线 | `docs/README.md` |
| `Package.swift` / `Package.resolved` | SPM 配置与依赖锁定文件 | 根目录 |
| `AGENTS.md` / `CLAUDE.md` | 项目规范与协作约定 | 根目录 |
| `README.md` / `README.zh-CN.md` | 对外说明文档（中/英） | 根目录 |
| `.build/` | SPM 构建产物目录 | `.gitignore` |
| `Packages/Caches/` | 第三方依赖源码缓存目录 | `.gitignore` |

### 2) 源码结构 (`Sources/InkMarkdown`)

```text
Sources/InkMarkdown/
├── InkMarkdown.swift              # 模块入口，声明 @_exported import Markdown
├── Configuration/
│   ├── InkAppearance.swift        # 全局与实例样式配置
│   └── InkConfiguration.swift     # 渲染配置容器
├── Parser/
│   ├── InkParser.swift            # Document(parsing:) 薄封装
│   └── InkLineClassifier.swift    # 行类型分类辅助
└── Rendering/
    ├── AttributedString/
    │   └── InkAttributedRenderer.swift
    ├── Block/
    │   ├── InkBlockRenderer.swift
    │   ├── InkBlockHandler.swift
    │   ├── InkRenderableBlock.swift
    │   └── InkAttributedTextBlock.swift
    ├── Components/                  # 代码块 / 表格 / 分割线 / LayoutManager
    ├── InkStreamRenderer.swift
    ├── InkTextContext.swift
    └── InkInlineSyntax.swift
```

`Rendering/Components/TABLE_INTEGRATION_GUIDE.md` 已在 `Package.swift` 中使用 `exclude` 排除，使用旧版 API，不作为接入依据。

### 3) 测试与示例程序结构

| 模块 | 目录布局 | 说明 |
|------|--------|-------|
| Tests | Core、core/addon contract、LaTeX、确定性 Mermaid、SwiftUI adapter、ExampleApp policy 与 app-hosted Mermaid integration targets | 使用 Swift Testing 与 XCTest；2026-09-01 的 iPhone 17 Pro / iOS 26.5 Package 全量共 298 个逻辑测试：297 项通过、0 失败、1 项跳过；app-hosted Mermaid 另有 1 项通过 |
| ExampleApp | `AppDelegate` / `SceneDelegate`、列表与详情页（块渲染、SSE、Pager 等） | 独立 Xcode 工程，提供宿主集成示例 |

### 4) 公开入口

| 入口 | 职责 | 验证依据 |
|-------|------|----------|
| `InkAttributedRenderer.render` | 将 Markdown 渲染为 `NSAttributedString` | `Rendering/AttributedString/InkAttributedRenderer.swift` |
| `InkBlockRenderer.render` | 将 Markdown 渲染为 `[InkRenderableBlock]` | `Rendering/Block/InkBlockRenderer.swift` |
| `InkStreamRenderer` | 流式增量渲染与 `UITextView` 绑定 | `Rendering/InkStreamRenderer.swift` |
| `InkParser.parse` | 字符串解析为 `Document` | `Parser/InkParser.swift` |
| `Package.swift` | SPM Products `InkMarkdown`、`InkMarkdownSwiftUI`、`InkMarkdownLaTeX`、`InkMarkdownMermaid` 定义 | 根目录 Manifest |
| `ExampleApp` | 渲染逻辑演示 | `ExampleApp/ExampleApp/` |

### 5) 命名规范

- **目录**：英文 PascalCase 或语义命名（如 `AttributedString`、`Components`）。
- **源文件**：`Ink` 前缀 + PascalCase（如 `InkAppearance.swift`）。
- **测试文件**：功能模块 + `Tests` / `Scaffold` 后缀。
- **文档文件**：小写 kebab-case 或带序号前缀（如 `docs/contributor-guide/02-architecture.md`）。

### 6) 验证依据

- `Package.swift`
- `Sources/InkMarkdown/**`
- `Tests/InkMarkdownTests/**`
- `docs/codebase/.codebase-scan.txt`
- 当前候选已跟踪 `Sources` 下的 74 个 Swift 源文件；`git status --porcelain=v2` 为空
