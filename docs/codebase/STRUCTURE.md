# Directory Structure

## Core Sections (Required)

### 1) Top-Level Layout

| Path | Purpose | Evidence |
|------|---------|----------|
| `Sources/InkMarkdown/` | 库源码（SPM target） | `Package.swift` `path: "Sources/InkMarkdown"` |
| `Tests/InkMarkdownTests/` | 库测试（SPM test target） | `Package.swift` `path: "Tests/InkMarkdownTests"` |
| `ExampleApp/` | UIKit 示例应用 + Xcode 工程 | `ExampleApp/ExampleApp.xcodeproj` |
| `Packages/` | 本地依赖拉取脚本与 `Caches/` | `Packages/scripts/fetch-packages.sh` |
| `docs/` | 人类可读知识库 + 本 codebase 基线 | `docs/README.md` |
| `Package.swift` / `Package.resolved` | SPM 清单与锁 | 仓库根 |
| `AGENTS.md` / `CLAUDE.md` | Agent / 协作约束 | 仓库根 |
| `README.md` / `README.zh-CN.md` | 对外介绍（中英） | 仓库根 |
| `.build/` | SPM 构建产物（gitignore） | scan 树；`.gitignore` |
| `Packages/Caches/` | 三方源码缓存（gitignore） | `.gitignore`、`AGENTS.md` |

### 2) Library Source Tree (`Sources/InkMarkdown`)

```text
Sources/InkMarkdown/
├── InkMarkdown.swift              # 模块入口；@_exported import Markdown
├── Configuration/
│   ├── InkAppearance.swift        # 全局/实例样式
│   └── InkConfiguration.swift     # 一次渲染的配置容器
├── Parser/
│   ├── InkParser.swift            # Document(parsing:) 薄封装
│   └── InkLineClassifier.swift    # 行类型分类（流式/边界辅助）
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

`Rendering/Components/TABLE_INTEGRATION_GUIDE.md` 被 `Package.swift` **exclude**，且文档标明 API 过时，不作为当前接入入口。

### 3) Tests and ExampleApp

| Area | Layout | Notes |
|------|--------|-------|
| Tests | `InkMarkdownTests.swift`、`StreamingPerformanceTests.swift`、`Snapshots/` | Swift Testing；约 32 个 `@Test` |
| ExampleApp | `AppDelegate` / `SceneDelegate`、分类列表、Detail（块渲染、SSE、Pager 等） | 独立 Xcode 工程，演示宿主接入 |

### 4) Entry Points

| Entry | Role | Evidence |
|-------|------|----------|
| `InkAttributedRenderer.render` | Markdown → `NSAttributedString` | `Rendering/AttributedString/InkAttributedRenderer.swift` |
| `InkBlockRenderer.render` | Markdown → `[InkRenderableBlock]` | `Rendering/Block/InkBlockRenderer.swift` |
| `InkStreamRenderer` | 流式增量渲染 + 可选绑定 `UITextView` | `Rendering/InkStreamRenderer.swift` |
| `InkParser.parse` | 字符串 → `Document` | `Parser/InkParser.swift` |
| `Package.swift` | SPM 产品 `InkMarkdown` | 根 manifest |
| `ExampleApp` | 手动验证与演示 | `ExampleApp/ExampleApp/` |

### 5) Naming Conventions (directories / files)

- 目录：英文、PascalCase 或语义文件夹名（`AttributedString`、`Components`）
- 库类型文件：`Ink` 前缀 + PascalCase（`InkAppearance.swift`）
- 测试文件：功能域 + `Tests` / `Scaffold` 后缀
- 文档：kebab 或序号前缀（`docs/contributor-guide/02-architecture.md`）

### 6) Evidence

- `Package.swift`
- `Sources/InkMarkdown/**`
- `Tests/InkMarkdownTests/**`
- `docs/codebase/.codebase-scan.txt`（DIRECTORY TREE）
- `find Sources -name '*.swift'` 清单（21 个库文件）
