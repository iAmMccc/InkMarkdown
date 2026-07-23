# 编码规范

## 约定与标准

### 1) 命名规范

| 类别 | 命名规则 | 验证依据 |
|------|------------|----------|
| 类型 / 文件 | `Ink` 前缀 + PascalCase | `InkAttributedRenderer.swift`、`InkAppearance` |
| 协议 | `Ink` 前缀 + 名词/能力 | `InkBlockHandler`、`InkRenderableBlock`、`InkInlineSyntax` |
| 公开 API | 使用中文文档注释（`///`）标注作用与约束 | `InkConfiguration`、`InkStreamRenderer`、`InkAttributedRenderer` |
| 内部 Helper | 无 `Ink` 前缀限制，使用 PascalCase / camelCase | `InkRenderer`、`InkRenderConstants`（private/internal） |
| 枚举命名空间 | `public enum` + static 方法（无实例状态） | `InkParser`、`InkBlockRenderer`、`InkLineClassifier` |
| 测试方法 | `domain_behavior` 或 `component_expectation` 命名 | `fixedLineHeight_plainParagraph`、`streamRenderer_…` |

### 2) 作用域与模块边界

- 库主模块为 `InkMarkdown`；测试使用 `@testable import InkMarkdown` 或 `@_spi(Performance)` 导入。
- 性能基准接口置于 `@_spi(Performance)`，避免暴露至标准 public API。
- Markdown 说明文档使用 `Package.swift` 的 `exclude` 选项，不参与编译。

### 3) 代码格式与风格

| 项目 | 配置/状态 | 验证依据 |
|------|--------|----------|
| 缩进规范 | 2 个空格 | `InkParser.swift`、`InkConfiguration.swift` 等源码 |
| SwiftLint / SwiftFormat | 未在根目录配置 | 项目扫描结果 |
| Swift 语言模式 | **v5**（非 Swift 6 严格并发模式） | `Package.swift` |
| Import 顺序 | 系统框架 → `Markdown` 模块 | `Rendering` 相关源文件 |

### 4) 错误处理与日志

| 环节 | 处理策略 | 验证依据 |
|-------|---------|----------|
| 文本解析 | 不抛出异常；依赖 swift-markdown 的容错解析机制 | `InkParser` 同步返回 `Document` |
| 内容渲染 | 未知的 inline 语法回退至默认子树；未知的 HTML 文本返回空字符串 | `renderInline` / `renderInlineHTML` |
| 流式 `append` | 字符数超过 `maxParseLength` 时直接 `return` | `InkStreamRenderer.append` |
| 流式 `finish` | 超过限制时截断缓存区后执行最终解析 | `finish()` 分支逻辑 |
| 日志输出 | 未使用统一日志框架 | 源码中无 os.Logger 或 print 机制 |

### 5) 文档注释规范

- 公开 API 统一配置中文 `///` 注释；包含代码示例时使用 Markdown 代码块。
- 内部注释侧重说明设计原因（如固定行高计算逻辑、双缓冲机制、TextKit 1 排版理由）。
- 产品与平台决策维护于 `AGENTS.md` / `CLAUDE.md` 及 `docs/current-status.md` 的目标与现状对比表中。
- 保持中英文 README 同步更新（遵循 `docs/README.md` 规则）。

### 6) 扩展点实现约定

| 扩展点 | 扩展方式 | 默认配置 |
|-----------------|---------------|---------|
| `InkAppearance` | 修改 `shared` 属性或传入自定义 `InkConfiguration` | 内置字号、行高与颜色 |
| `inlineSyntaxes` | 实现 `InkInlineSyntax` 协议，按顺序匹配 | `[]` |
| `blockHandlers` | 实现 `InkBlockHandler` 协议；可覆盖默认列表 | code + table + thematic break |
| `sourceFilter` | 解析前对原始 Markdown 字符串进行预处理 | `nil` |
| `linkTapHandler` | 自定义表格等 `UITextView` 内的链接点击回调 | `nil`（系统默认行为） |

### 7) 线程与并发规则

- `InkStreamRenderer` 公共 API（`append` / `finish` / `bindTextView` 等）必须在主线程调用。
- 解析线程分配在 `DispatchQueue(label: "InkStreamRenderer.parse", qos: .userInitiated)`；通过 `NSLock` 及 Generation 标志管理主线程与后台线程的状态同步。

### 8) 验证依据

- `Sources/InkMarkdown/**/*.swift`
- `Package.swift`
- `Tests/InkMarkdownTests/**/*.swift`
- `AGENTS.md`
