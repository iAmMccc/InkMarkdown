# InkMarkdown

基于 Apple [swift-markdown](https://github.com/apple/swift-markdown) 的 **UIKit 专用** Markdown 解析与渲染库。核心差异化：把 Markup 树渲染为 `NSAttributedString`，填补三代库（swift-markdown / MarkdownUI / Textual）均不支持 UIKit 的能力空缺。

> 📌 **明确不做 SwiftUI**：InkMarkdown 定位是 UIKit 库。SwiftUI 场景已有 MarkdownUI / Textual 覆盖，不重复造轮。

## 项目结构

```
InkMarkdown/
├── Package.swift              # SPM 包定义（swift-tools-version: 6.2）
├── Sources/InkMarkdown/       # 库源码主目录
│   └── InkMarkdown.swift
├── Tests/InkMarkdownTests/    # 单元测试
│   └── InkMarkdownTests.swift
├── ExampleApp/                # 示例 App（UIKit）
│   ├── ExampleApp.xcodeproj
│   └── ExampleApp/            # AppDelegate / SceneDelegate / ViewController
├── Packages/Caches/           # SPM 本地依赖缓存（不提交 Git）
│   ├── swift-markdown
│   ├── swift-cmark
│   └── SmartCodable
├── Package.resolved
└── .gitignore
```

## 平台与工具链

- **Swift 工具链**：6.2+
- **UI 框架**：**UIKit only**（不支持 SwiftUI）
- **支持平台**（已决策，不再讨论）：
  - iOS 14+
  - macOS 11+
  - tvOS 14+
  - watchOS 7+

> 📌 **平台决策记录**：项目定位为 UIKit 库，核心 API 是 `NSAttributedString`（iOS 6+ 就有），不依赖任何 iOS 15+ 的 SwiftUI 或 `AttributedString`（Swift 原生类型）。
>
> 在 UIKit 场景下 iOS 14 vs 15 能力差距 ≈ 0。降到 iOS 14 仅有的小损失：`HTMLFormatter` 的 `.parseInlineAttributeClass` 选项在 iOS 14 退回普通 JSON 解析（无 JSON5），但库本身已写好 fallback，且这是用户主动开启的边缘选项，几乎无影响。
>
> 收益：覆盖更多老设备、提升库的开源吸引力、企业市场友好。

## 依赖管理

本项目采用 **SPM 本地缓存**策略，所有三方库源码下载到 [Packages/Caches/](Packages/Caches/) 后通过 `path:` 方式引用，**绕过 Xcode 的网络限制**。

| 依赖 | 用途 | 引用方式 |
|------|------|---------|
| swift-markdown | Apple 官方 Markdown 解析器 | `path: "Packages/Caches/swift-markdown"` |
| SmartCodable | 增强型 Codable 编解码 | `path: "Packages/Caches/SmartCodable"` |

> ⚠️ `Packages/Caches/` 已在 [.gitignore](.gitignore) 中忽略，三方库源码**不提交到仓库**。新克隆仓库后需要重新拉取依赖到本地。

相关技能：使用 `spm-local` 技能管理本地依赖。

## 知识库（重要）

项目 [docs/](docs/) 已按性质分为两类，互不重复：

```
docs/
├── references/   # 三方库 API / 架构速查（实现时查 API 用）
│   ├── swift-markdown-api-guide.md
│   ├── swift-markdown-ui-guide.md
│   └── textual-guide.md
└── spec/         # Markdown 语法规范本身（设计渲染语义、对外文档用）
    ├── README.md
    └── common-syntax.md            # CommonMark 严格集（已完成）
    # extended-syntax.md / custom-syntax.md（待写）
```

**查阅原则**：
- 涉及"解析层 API / 三方库怎么用" → 查 [docs/references/](docs/references/)
- 涉及"Markdown 该渲染什么 / 各语法语义" → 查 [docs/spec/](docs/spec/)

### 📘 [docs/references/swift-markdown-api-guide.md](docs/references/swift-markdown-api-guide.md) — 底层解析引擎

**对象**：Apple swift-markdown（**InkMarkdown 的直接依赖**）

**包含**：
- 60+ public 类型 API 全景表（Block / Inline / Container / Visitor / Walker / Rewriter / Infrastructure）
- Markup 不可变树 + 写时复制（COW）架构
- 5 个典型用例完整代码（解析、遍历、链接提取、Rewriter 改写、HTML 渲染）
- ParseOptions（5 项）+ MarkupFormatter.Options（13 项）
- Visitor / Walker / Rewriter 决策流程
- **第 7 节明确给出 InkMarkdown 应封装 / 不应封装的 API 清单**

### 📗 [docs/references/swift-markdown-ui-guide.md](docs/references/swift-markdown-ui-guide.md) — SwiftUI 同类库参考

**对象**：swift-markdown-ui（MarkdownUI，**仅架构借鉴，不作依赖**）

**关键认知**：
- 已进入维护模式，作者迁移至 Textual
- SwiftUI 渲染管线参考价值有限（InkMarkdown 不做 SwiftUI），但**架构抽象层**值得学习
- **可借鉴**：Theme 分层（`TextStyle` + `BlockStyle`）、Block→自定义 UIView 路由、`MarkdownContent` 预解析缓存
- **不应照搬**：自定义 AST enum、直接调 cmark-gfm、SwiftUI View 实现细节

### 📙 [docs/references/textual-guide.md](docs/references/textual-guide.md) — SwiftUI 下一代参考

**对象**：Textual（MarkdownUI 作者新作，**仅架构借鉴，不作依赖**）

**关键认知**：
- 不是 MarkdownUI 的升级，而是**设计范式转变**——从"Markdown 渲染库"变成"SwiftUI 文本渲染引擎"
- 中间模型换成 Foundation `AttributedString` + `PresentationIntent`
- **可借鉴**：
  - `TextProperty` 组合式样式（比 MarkdownUI 的 TextStyle 更灵活）
  - `MarkupParser` 协议（解析与渲染彻底解耦，可插自定义格式）
  - 行内/块级双类型分离的渲染抽象
- **不应照搬**：放弃 Markup 树、绑死 SwiftUI、iOS 18+ 门槛

### 架构决策原则（三份文档综合结论）

```
解析：100% 用 swift-markdown（三代库中能力最强）
   ↓
适配：Markup 树 → 渲染中间表示（借鉴 Textual 的解耦思路，但基于 Markup 类型）
   ↓
样式：TextProperty + Theme 协议（借鉴 Textual 组合式 + MarkdownUI 分层）
   ↓
渲染：UIKit NSAttributedString（差异化主力，三代库均不支持）
      └─ 可选附加：自定义 UIView 路由（处理 Table / CodeBlock 等无法塞进 NSAttributedString 的元素）
```

## 协作偏好

### Cursor 优先用于大批量阅读 / 知识提取

用户是 **Cursor 订阅用户（composer 2.5 无限额度）**，遇到以下任务**主动把工作交给 Cursor**：
- 读取 >10 个文件做汇总分析
- 三方库源码扫描 + 结构化文档输出
- 多份资料对比、跨仓库架构调研

**协作流程**：
1. Codex 出**可直接复制的 Cursor prompt**（明确产出文件路径、章节结构、风格）
2. Cursor 执行后产出 markdown 文档到 `docs/`
3. 回到 Codex 时，**抽样核对** 2-3 个关键章节对照源码确认准确率
4. 基于已核对的文档做架构决策与代码实现

**已用此流程产出 3 份高质量文档**（`docs/swift-markdown-*.md` + `docs/textual-guide.md`），抽样验证准确率高。

### Codex 留给：
- 跨步骤连贯思考（架构决策、API 设计）
- 实际写代码 / 修改代码
- 需要 memory + 项目上下文的连续会话
- 单文件深度阅读与精准核对

## 工具使用

### 代码查询工具规则

- 优先使用 `codebase-memory-mcp` 进行代码查询、符号定位、调用关系追踪和架构概览。
- 如果本仓库尚未构建索引，先为当前仓库构建索引，再进行代码查询。
- 如果环境尚未安装 `codebase-memory-mcp`，从 https://github.com/DeusData/codebase-memory-mcp 安装并启用后再使用。
- 仅在 `codebase-memory-mcp` 不可用、索引结果不足，或需要搜索字符串字面量/配置/非代码文件时，回退到 `rg` / 文件读取。

## 常用命令

### 构建

```bash
swift build
```

### 测试

```bash
swift test
```

### 清理构建产物

```bash
swift package clean
rm -rf .build
```

### 打开示例 App

```bash
open ExampleApp/ExampleApp.xcodeproj
```

## 开发约定

### 代码风格

- **库源码**位于 [Sources/InkMarkdown/](Sources/InkMarkdown/)
- **测试代码**位于 [Tests/InkMarkdownTests/](Tests/InkMarkdownTests/)
- 公开 API 加完整中文文档注释
- 内部实现的注释聚焦于"为什么"，而非"是什么"

### Git 提交

- `.build/`、`Packages/Caches/`、`xcuserdata/`、`DerivedData/` 均已在 [.gitignore](.gitignore) 中忽略
- 不要提交 SPM 缓存目录中的三方库源码

## 当前状态

项目处于初始化阶段：
- ✅ SPM 包结构已搭建
- ✅ swift-markdown / SmartCodable 本地依赖已就绪
- ✅ ExampleApp 工程框架已创建
- ✅ 三方库参考文档已沉淀（[docs/references/](docs/references/)：swift-markdown / MarkdownUI / Textual 三份）
- ✅ Markdown 通用语法规范已沉淀（[docs/spec/common-syntax.md](docs/spec/common-syntax.md)，CommonMark 0.31 严格集）
- ⏳ [InkMarkdown.swift](Sources/InkMarkdown/InkMarkdown.swift) 主入口待实现
- ⏳ Style / Theme 配置体系待设计
- ⏳ AttributedString 渲染器待实现（核心差异化能力）
- ⏳ 单元测试待补充
