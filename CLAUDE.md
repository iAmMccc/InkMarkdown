# InkMarkdown

基于 Apple [swift-markdown](https://github.com/apple/swift-markdown) 的 **UIKit-first** Markdown 解析与渲染库。它提供 `NSAttributedString` 与可路由的 `UIView` block，并计划在 v0.0.2 通过独立 SwiftUI adapter product 向 SwiftUI 宿主提供相同渲染语义。

> 📌 **产品范围**：`InkMarkdown` 是 UIKit rendering engine；v0.0.2 交付后的 `InkMarkdownSwiftUI` 才是正式 SwiftUI adapter，不是第二套 native SwiftUI renderer。以 [ADR-008](docs/decisions/ADR-008-swiftui-adapter-architecture.md) 为准。

## 项目结构

```
InkMarkdown/
├── Package.swift              # SPM 包定义（swift-tools-version: 6.2）
├── Sources/InkMarkdown/       # UIKit Parser / Configuration / Rendering engine
├── Sources/InkMarkdownSwiftUI/ # v0.0.2 独立 SwiftUI adapter target
├── Sources/InkMarkdownLaTeX/ # 可选 iosMath addon target
├── Sources/InkMarkdownMermaid/ # 可选 WebKit Mermaid addon target
├── Tests/InkMarkdownTests/    # UIKit 语义、快照骨架与流式性能测试
├── Tests/InkMarkdownLaTeXTests/ # LaTeX addon 关键路径测试
├── Tests/InkMarkdownMermaidTests/ # Mermaid addon 关键路径测试
├── Tests/InkMarkdownSwiftUITests/ # SwiftUI adapter 契约测试
├── ExampleApp/                # UIKit + SwiftUI adapter 示例 App
│   ├── ExampleApp.xcodeproj
│   └── ExampleApp/            # AppDelegate / SceneDelegate / ViewController
├── Packages/                  # 本地依赖拉取脚本；Caches/ 不提交 Git
├── docs/                      # 状态、路线、贡献者指南、规范、参考
├── Package.resolved
└── .gitignore
```

## 平台与工具链

- **Swift 工具链**：6.2+
- **UI 框架**：UIKit rendering engine；v0.0.2 独立 SwiftUI adapter
- **v0.0.2 目标平台 / 发布边界**：iOS 14+、iPadOS 14+；不支持其他平台

> 📌 已发布 `0.0.1` 的 iPad 验证尚未完成，不能将此目标描述为当前已交付支持。SwiftUI adapter 必须把 iOS 14–15 与 iOS 16+ 的可用性差异收敛在自身 implementation 中。

## 依赖管理

**默认依赖策略（ADR-001）**：`Package.swift` 以 **固定 git revision** 引用
`swift-markdown`（当前 revision 见 `Package.swift` / `Package.resolved`），保证可重复构建。

**可选离线策略**：本机网络受限时，可用 [Packages/scripts/fetch-packages.sh](Packages/scripts/fetch-packages.sh)
把源码拉到 [Packages/Caches/](Packages/Caches/)，再在本地临时 `path:` 覆盖；
**不要把 path 当作默认发布 manifest**。细节见 [docs/decisions/ADR-001-swift-markdown-dependency-pinning.md](docs/decisions/ADR-001-swift-markdown-dependency-pinning.md)。

| 依赖 | 用途 | 引用方式 |
|------|------|---------|
| swift-markdown | Apple 官方 Markdown 解析器 | 远程 **revision pin**（默认）；`Packages/Caches` 可选离线 |
| SmartCodable | 早期规划依赖 | 当前 manifest 与源码未使用；引入前需确认用途 |

> ⚠️ `Packages/Caches/` 已在 [.gitignore](.gitignore) 中忽略，三方库源码**不提交到仓库**。

本地依赖的准备方法见[开发指南](docs/contributor-guide/04-development.md#准备-swift-markdown-依赖)。

## 知识库（重要）

项目 [docs/](docs/) 按读者任务与知识性质分层：

```
docs/
├── README.md             # 文档入口、权威层级
├── current-status.md     # 可验证的当前交付状态与已知漂移
├── roadmap.md            # 未来优先级与退出标准
├── decisions/            # ADR 架构决策
├── codebase/             # 工程证据基线（短、可核验）
├── contributor-guide/    # 架构、原理、开发、模块与 FAQ
├── references/           # 三方依赖 API 速查
└── spec/                 # Markdown 渲染语义规范
```

> 零基础 Tutorial（Markdown / TextKit 跟练）已迁至个人知识库 `PersonalDocument/DocumentLibrary/iOS/InkMarkdown/learning-path/`，不进本开源仓。

**查阅原则**：
- 涉及"当前到底做到哪" → 查 [docs/current-status.md](docs/current-status.md)
- 涉及"架构为什么这样 / 怎么开发" → 查 [docs/contributor-guide/](docs/contributor-guide/README.md)
- 涉及"解析层 API / 三方库怎么用" → 查 [docs/references/](docs/references/)
- 涉及"Markdown 该渲染什么 / 各语法语义" → 查 [docs/spec/](docs/spec/)

### 目标架构原则

```
解析：100% 使用 swift-markdown
   ↓
语义与配置：Markup + InkConfiguration（v0.0.2 保持现有 Markup 直渲染；InkIR 留待 v2）
   ↓
UIKit rendering engine：NSAttributedString + 可选 UIView block 路由
   ↓
InkMarkdownSwiftUI：在独立 seam 承载 UIKit view、配置与生命周期
   ↓
UIKit / SwiftUI 宿主共享同一渲染语义
```

SwiftUI 的总体设计、范围和退出标准以 [SwiftUI Adapter 总体技术设计](docs/contributor-guide/08-swiftui-adapter-architecture.md) 为准。

## 协作偏好

### Cursor 优先用于大批量阅读 / 知识提取

用户是 **Cursor 订阅用户（composer 2.5 无限额度）**，遇到以下任务**主动把工作交给 Cursor**：
- 读取 >10 个文件做汇总分析
- 三方库源码扫描 + 结构化文档输出
- 多份资料对比、跨仓库架构调研

**协作流程**：
1. Claude Code 出**可直接复制的 Cursor prompt**（明确产出文件路径、章节结构、风格）
2. Cursor 执行后产出 markdown 文档到 `docs/`
3. 回到 Claude Code 时，**抽样核对** 2-3 个关键章节对照源码确认准确率
4. 基于已核对的文档做架构决策与代码实现

### Claude Code 留给：
- 跨步骤连贯思考（架构决策、API 设计）
- 实际写代码 / 修改代码
- 需要 memory + 项目上下文的连续会话
- 单文件深度阅读与精准核对

## 常用命令

### 构建

```bash
xcodebuild -scheme InkMarkdown -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' build
```

### 测试

```bash
xcodebuild -scheme InkMarkdown-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' test
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

## Agent skills

### Issue tracker

Issues 与 specs 以本地 Markdown 文件托管于 `.scratch/<feature-slug>/`。见 [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md)。

### Triage labels

使用 Matt 默认五角色 triage 标签。见 [docs/agents/triage-labels.md](docs/agents/triage-labels.md)。

### Domain docs

Single-context：根目录 [CONTEXT.md](CONTEXT.md) + [docs/decisions/](docs/decisions/) ADR。见 [docs/agents/domain.md](docs/agents/domain.md)。

## 当前状态

- ✅ `0.0.1` 已作为 UIKit-first public beta 发布。
- ✅ UIKit rendering engine、配置/扩展点与 ExampleApp 已具备。
- ⏳ v0.0.2 的 release blocker 是完整语义对齐、iOS/iPadOS 14 验证、可访问性、性能基线与发布文档；独立 `InkMarkdownSwiftUI` product、基础契约测试和 ExampleApp 的静态/配置/流式示例入口已具备。
- ⚠️ 已拒绝的 SwiftUI spike 已移出仓库；SwiftUI source 保持在独立 `InkMarkdownSwiftUI` product，ExampleApp 通过 `UIHostingController` 接入，不改变 UIKit rendering engine 边界。

完整且可维护的状态基线见 [docs/current-status.md](docs/current-status.md)。
