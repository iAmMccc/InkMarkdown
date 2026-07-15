# Coding Conventions

## Core Sections (Required)

### 1) Naming

| Kind | Convention | Evidence |
|------|------------|----------|
| Types / files | `Ink` 前缀 + PascalCase | `InkAttributedRenderer.swift`、`InkAppearance` |
| Protocols | `Ink` + 名词/能力 | `InkBlockHandler`、`InkRenderableBlock`、`InkInlineSyntax` |
| Public API | 中文文档注释（`///`）描述用途与约束 | `InkConfiguration`、`InkStreamRenderer`、`InkAttributedRenderer` |
| Internal helpers | 无 `Ink` 强制时仍用描述性 PascalCase / camelCase | 文件内 `InkRenderer`、`InkRenderConstants`（private/internal） |
| Enums as namespaces | `public enum` + static 方法（无实例状态） | `InkParser`、`InkBlockRenderer`、`InkLineClassifier` |
| Test names | `domain_behavior` 或 `component_expectation` | `fixedLineHeight_plainParagraph`、`streamRenderer_…` |

### 2) Visibility and Module Boundaries

- 库模块：`InkMarkdown`；测试 `@testable import InkMarkdown` 或 `@_spi(Performance)`。
- 性能基准 API 放在 `@_spi(Performance)`，避免成为默认 public 表面。
- 组件 markdown 指南文件从 target **exclude**，不进入编译。

### 3) Formatting and Style Tooling

| Item | Status | Evidence |
|------|--------|----------|
| Indentation observed | 2 spaces（源码抽样） | e.g. `InkParser.swift`、`InkConfiguration.swift` |
| SwiftLint / SwiftFormat | 未配置于仓库根 | scan lint 段 |
| Swift language mode | **v5**（非 Swift 6 严格并发默认） | `Package.swift` |
| Import grouping | 系统框架 → Markdown（模块） | 各 Rendering 文件 |

### 4) Error Handling and Logging

| Layer | Pattern | Evidence |
|-------|---------|----------|
| Parse | 不抛错；委托 swift-markdown 容错解析 | `InkParser` 同步返回 `Document` |
| Render | 未知 inline 走 default 子树；未知 HTML 可返回空串 | `renderInline` / `renderInlineHTML` |
| Stream `append` | 超 `maxParseLength` 时 **直接 return**（不抛） | `InkStreamRenderer.append` |
| Stream `finish` | 超长则截断 buffer 再最终解析 | `finish()` 分支 |
| Logging | **无** 统一日志框架 | 源码检索无 os.Logger / print 管线约定 |

### 5) Documentation Conventions

- 公开 API：完整中文 `///`，含使用片段时用代码块（`InkConfiguration`、`InkStreamRenderer`）。
- 内部注释侧重 **为什么**（如固定行高三原则、双缓冲、TextKit 1）。
- 产品 / 平台决策：`AGENTS.md` / `CLAUDE.md` + `docs/current-status.md` 的 Intent vs Reality 表。
- 中英 README 成对更新（`docs/README.md` 维护规则）。

### 6) Extension Conventions

| Extension point | How to extend | Default |
|-----------------|---------------|---------|
| `InkAppearance` | 改 shared 或传入 configuration | 内置字号/行高/颜色 |
| `inlineSyntaxes` | 实现 `InkInlineSyntax`，按序匹配 | `[]` |
| `blockHandlers` | 实现 `InkBlockHandler`；可替换默认列表 | code + table + thematic break |
| `sourceFilter` | 解析前变换源文本 | `nil` |
| `linkTapHandler` | 表格等 `UITextView` 链接点击 | `nil`（系统默认） |

### 7) Threading Conventions

- `InkStreamRenderer` 公开 API（`append` / `finish` / `bindTextView` / …）**必须主线程**（类型文档注释）。
- 解析在 `DispatchQueue(label: "InkStreamRenderer.parse", qos: .userInitiated)`；与主线程共享状态用 `NSLock` / generation 丢弃过期任务。

### 8) Evidence

- `Sources/InkMarkdown/**/*.swift`（命名与注释抽样）
- `Package.swift`（language mode、exclude）
- `Tests/InkMarkdownTests/**/*.swift`
- `AGENTS.md` 开发约定章节
