# 目录结构

## 核心布局

### 1) 顶层结构

| 路径 | 作用 | 验证依据 |
|------|---------|----------|
| `Sources/InkMarkdown/` | 核心源码库（SPM target） | `Package.swift` `path: "Sources/InkMarkdown"` |
| `Tests/InkMarkdownTests/` | 测试集（SPM test target） | `Package.swift` `path: "Tests/InkMarkdownTests"` |
| `ExampleApp/` | UIKit 示例应用工程 | `ExampleApp/ExampleApp.xcodeproj` |
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
| Tests | `InkMarkdownTests.swift`、`StreamingPerformanceTests.swift`、`Snapshots/` | 使用 Swift Testing 框架，包含约 32 个测试项 |
| ExampleApp | `AppDelegate` / `SceneDelegate`、列表与详情页（块渲染、SSE、Pager 等） | 独立 Xcode 工程，提供宿主集成示例 |

### 4) 公开入口

| 入口 | 职责 | 验证依据 |
|-------|------|----------|
| `InkAttributedRenderer.render` | 将 Markdown 渲染为 `NSAttributedString` | `Rendering/AttributedString/InkAttributedRenderer.swift` |
| `InkBlockRenderer.render` | 将 Markdown 渲染为 `[InkRenderableBlock]` | `Rendering/Block/InkBlockRenderer.swift` |
| `InkStreamRenderer` | 流式增量渲染与 `UITextView` 绑定 | `Rendering/InkStreamRenderer.swift` |
| `InkParser.parse` | 字符串解析为 `Document` | `Parser/InkParser.swift` |
| `Package.swift` | SPM Product `InkMarkdown` 定义 | 根目录 Manifest |
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
- `Sources` 下的 21 个 Swift 源文件
