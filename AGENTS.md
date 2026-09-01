# InkMarkdown

基于 Apple [swift-markdown](https://github.com/apple/swift-markdown) 的 **UIKit-first** Markdown 解析与渲染库。核心差异化是将 Markup 树渲染为 `NSAttributedString` 与可路由的 `UIView` block；计划在 v0.0.2 通过独立 product 向 SwiftUI 宿主提供相同渲染语义。

> 📌 **产品范围**：`InkMarkdown` 保持 UIKit rendering engine；v0.0.2 交付后的 `InkMarkdownSwiftUI` 才是正式 SwiftUI adapter，而非第二套 native SwiftUI renderer。整体决策见 [ADR-008](docs/decisions/ADR-008-swiftui-adapter-architecture.md)。

## 项目结构

```
InkMarkdown/
├── Package.swift              # SPM 包定义（swift-tools-version: 6.2）
├── Sources/InkMarkdown/       # UIKit Parser / Configuration / Rendering engine
├── Sources/InkMarkdownSwiftUI/ # SwiftUI presentation adapter target
│   ├── InkMarkdownSwiftUI.swift  # 模块导出入口
│   ├── Views/                    # 声明式视图入口
│   ├── Bridge/                   # UIViewRepresentable 桥接
│   ├── Session/                  # 流式会话状态机
│   └── Modifiers/                # Environment 配置注入
├── Sources/InkMarkdownLaTeX/ # 可选 iosMath addon target
├── Sources/InkMarkdownMermaid/ # 可选 WebKit Mermaid addon target
├── Tests/InkMarkdownTests/    # UIKit 语义、快照骨架与流式性能测试
├── Tests/InkMarkdownCoreContractTests/ # Core-only product 边界测试
├── Tests/InkMarkdownAddonContractTests/ # Addon 注册边界测试
├── Tests/InkMarkdownLaTeXTests/ # LaTeX addon 关键路径测试
├── Tests/InkMarkdownMermaidTests/ # Mermaid addon 关键路径测试
├── Tests/InkMarkdownSwiftUITests/ # SwiftUI adapter 契约测试
├── Tests/ExampleAppPolicyTests/ # ExampleApp 业务策略测试
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

> 📌 已发布 `0.0.1` 的 iPad 验证尚未完成，不能将此目标描述为当前已交付支持。`UIViewRepresentable` 覆盖最低平台，但部分 SwiftUI convenience capability 晚于 iOS 14；兼容实现必须把可用性差异收敛在 adapter 内。

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
- 继续本轮审查修复任务 → 先查 [docs/qa/InkMarkdown-current-task-summary-2026-08-28.md](docs/qa/InkMarkdown-current-task-summary-2026-08-28.md)，再核对当前状态、源码和最新测试证据
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
1. Codex 出**可直接复制的 Cursor prompt**（明确产出文件路径、章节结构、风格）
2. Cursor 执行后产出 markdown 文档到 `docs/`
3. 回到 Codex 时，**抽样核对** 2-3 个关键章节对照源码确认准确率
4. 基于已核对的文档做架构决策与代码实现

### Codex 留给：
- 跨步骤连贯思考（架构决策、API 设计）
- 实际写代码 / 修改代码
- 需要 memory + 项目上下文的连续会话
- 单文件深度阅读与精准核对

## 工具使用

### 代码查询工具规则（强制）

**默认入口必须是 `serena` MCP**（[oraios/serena](https://github.com/oraios/serena)），基于 LSP 做符号导航与引用追踪。Grep / Glob / Task(explore) / 目录遍历只作补搜，不作首选。

编码任务开始前先调用 `initial_instructions`，再按任务需要走符号工具。

适用场景（一律先走 Serena）：
- 符号定位、定义与引用、调用链 / 影响面追踪
- 架构概览、模块边界、入口点与依赖关系
- “某某功能在哪实现 / 谁调用了谁 / 改动会影响什么”

推荐工具顺序：
1. `activate_project` — 确认当前仓库已激活（本仓库路径：仓库根目录）；未激活则先激活
2. `get_symbols_overview` / `find_symbol` — 定位文件内符号与结构
3. `find_referencing_symbols` / `find_implementations` / `find_declaration` — 引用链、实现与声明
4. `search_for_pattern` — 符号名或位置尚不确定时的模式搜索
5. `read_file`（或 Cursor `Read`）— 仅在需要阅读具体实现时读取

硬性约束：
- 摸清代码结构时，先走 Serena 符号工具，再决定是否补搜。
- 若当前调用环境未暴露 / 未安装 `serena`：
  1. **必须向用户明确推荐安装并启用**该 MCP（仓库：https://github.com/oraios/serena ；Cursor `~/.cursor/mcp.json` 示例：`"serena": { "command": "serena", "args": ["start-mcp-server", "--project-from-cwd"] }`），并说明安装后需重启 / 重载 Agent 会话；
  2. 在用户完成安装与会话重载前，可临时回退到 `Grep` / `rg` / `Glob` / 文件读取，但必须同时告知这是降级路径，并再次提醒安装 MCP。
- **仅允许回退**到 `Grep` / `rg` / `Glob` / 文件读取的情况：
  1. MCP 当前会话不可用（已向用户推荐安装 / 重载），且已说明回退原因；
  2. 符号查询结果明确不足（空结果 / 漏检），需要补搜；
  3. 目标是字符串字面量、配置文件、文档、非代码资源。

### Apple 官方知识查询规则（强制）

涉及 **Apple 平台官方知识**（UIKit / AppKit / Foundation / Swift / SwiftUI API、Developer Documentation、平台兼容性等）时，**必须优先使用 `apple-docs` MCP**（`apple-doc-mcp-server`），不要先靠训练记忆或通用网页搜索猜测。

推荐工具顺序：
1. `discover_technologies` → `choose_technology` — 选定框架（如 UIKit / SwiftUI / Foundation）
2. `search_symbols` — 符号优先检索；本项目可带 `platform: iOS`
3. `get_documentation` — 读取选定技术内的符号文档
4. `get_version` — 排查 MCP 版本与连通性

本项目硬边界：iOS 14+ / iPadOS 14+；不支持其他平台。查到的 API 可用性必须对照该边界。

硬性约束：
- 先查 `apple-docs`，再断言 Apple API 签名、可用性、废弃状态或推荐替代方案。
- 若当前调用环境未暴露 / 未安装 `apple-docs` MCP：
  1. **必须向用户明确推荐安装并启用**该 MCP（npm：`apple-doc-mcp-server`；Cursor `~/.cursor/mcp.json` 示例：`"apple-docs": { "command": "npx", "args": ["-y", "apple-doc-mcp-server@latest"] }`），并说明安装后需重启 / 重载 Agent 会话；
  2. 在用户完成安装与会话重载前，可临时回退到 Context7 / 官方文档网页，但必须同时告知这是降级路径，并再次提醒安装 `apple-docs` MCP。
- **仅允许回退**的情况：
  1. MCP 当前会话不可用（已向用户推荐安装 / 重载），且已说明回退原因；
  2. 查询目标明显不属于 Apple 官方文档范围（例如本仓库业务逻辑、第三方非 Apple SDK）。

### 三方库文档查询（Context7）

查询 **非 Apple** 的库 / SDK / 框架文档（例如 `swift-markdown`、SPM 依赖、CLI）时，优先使用 `context7` MCP，不要先靠训练记忆或通用网页搜索猜测。

推荐工具顺序：
1. `resolve-library-id` — 用官方库名解析 Context7 library ID（格式 `/org/project`）
2. `query-docs` — 针对单一概念查询文档与示例

硬性约束：
- Context7 只用于三方库文档，不用于本仓库代码结构探索（代码结构走 Serena）。
- Apple 平台官方知识仍走 `apple-docs`；Context7 是其降级路径，不是首选。
- 若当前调用环境未暴露 / 未安装 `context7` MCP：
  1. **必须向用户明确推荐安装并启用**该 MCP（npm：`@upstash/context7-mcp`；Cursor `~/.cursor/mcp.json` 示例：`"context7": { "command": "npx", "args": ["-y", "@upstash/context7-mcp@latest"] }`），并说明安装后需重启 / 重载 Agent 会话；
  2. 在用户完成安装与会话重载前，可临时回退到官方文档网页，但必须同时告知这是降级路径。

### Xcode 构建、测试与运行工具规则

- 编译、运行测试、选择或启动 Simulator、安装并启动 ExampleApp、采集构建日志时，**默认优先使用 [XcodeBuildMCP](https://www.xcodebuildmcp.com/)**，不要直接从原生 `xcodebuild` 命令开始。
- 开始前先确认当前会话已暴露 XcodeBuildMCP 工具，并用其项目发现能力确认 workspace / project、scheme 与可用 destination；不要在自动化流程中写死本机 Simulator UUID。
- Swift Package 测试必须选择 iOS Simulator destination。InkMarkdown 直接依赖 UIKit，不能把 macOS host 上 `swift build` / `swift test` 的 `no such module 'UIKit'` 当作库逻辑失败。
- 测试完成后记录实际 scheme、destination、测试数量和失败摘要；构建失败时优先使用 XcodeBuildMCP 返回的结构化诊断继续定位。
- 如果当前会话没有暴露 XcodeBuildMCP：
  1. 先运行 `command -v xcodebuildmcp` 和 `xcodebuildmcp --version`，区分“未安装”和“已安装但 MCP 客户端未注册 / 当前会话未加载”。
  2. 若本机未安装，从 [XcodeBuildMCP 官网](https://www.xcodebuildmcp.com/) 按官方说明下载安装，并完成 MCP 客户端配置。
  3. 若二进制已存在，不要重复安装；检查 MCP 客户端配置是否以 `xcodebuildmcp mcp` 启动服务，然后重载客户端或新建会话，直到工具可见。
  4. 只有在完成上述检查后仍不可用、或正在诊断 XcodeBuildMCP 本身时，才回退到原生 `xcodebuild` / `xcrun simctl`，并在结果中说明回退原因。

### 全局 skills

项目复用全局 `~/.agents/skills/` 中的开发 skill，不保留仓库级副本或 `skills-lock.json`。按任务触发需要的 skill，不要无差别加载全部参考资料。

| Skill | 使用场景 | 项目约束 |
| --- | --- | --- |
| `xcodebuildmcp` | Xcode 项目发现、构建、测试、Simulator、日志与 UI 自动化 | MCP 未在当前会话暴露时先修复注册 / 加载，再考虑原生命令回退 |
| `swift-testing-pro` | 新增、审查或重构 Swift Testing 测试 | 本项目使用 Swift 6.2 与 Swift Testing；UI 测试仍使用 XCTest |
| `swift-concurrency` | 流式渲染、后台解析、主线程 / actor 边界、Sendable 与竞态问题 | 先读取 `Package.swift` 的 Swift 5 language mode；不要为了“现代化”无关重写现有 GCD 状态机 |
| `swift-api-design-guidelines` | v1.0 public API 审计、命名、参数标签与中文文档注释 | 该 skill 面向更新工具链；以项目 Swift 6.2 与 iOS 14+ 可用性为硬边界，不引入 6.3-only API |
| `ios-accessibility` | UIKit 组件的 VoiceOver、Dynamic Type、交互与可访问性测试 | 只采用 UIKit / 通用章节；忽略与本项目无关的 SwiftUI 实现建议 |
| `changelog-automation` | CHANGELOG、SemVer、发布说明与提交约定 | 生成内容必须结合本仓库真实 Git 历史，不套用示例版本或虚构变更 |

安装或更新全局 skill 后，检查 `SKILL.md`、相对引用和安全扫描结果；全局版本由用户环境统一维护，不提交到本仓库。

## 文档规则

### 文档更新规则

- 更新 README 文档时，必须同时更新英文版 [README.md](README.md) 和中文版 [README.zh-CN.md](README.zh-CN.md)，保持核心信息一致。

## 原生命令回退参考

以下命令只用于 XcodeBuildMCP 暂时不可用或诊断 MCP 本身的场景；正常构建与测试优先使用 XcodeBuildMCP。

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

### 设计与编码规则

- 不做补丁式设计，不写只覆盖当前症状的补丁逻辑；先理解相关调用链、状态边界和复用点，再给出全局最优解。
- 局部修复与全局一致性冲突时，以全局一致性为准，在正确的共享边界解决根因。
- 最小实现不等于临时实现；少写代码的前提是方案完整、边界正确、后续维护成本最低。

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
- ✅ `InkAttributedRenderer`、`InkBlockRenderer`、`InkStreamRenderer`、`InkAppearance` / `InkConfiguration` 与 UIKit ExampleApp 已具备。
- ✅ 2026-08-27 通过 XcodeBuildMCP 在 iPhone 17 / iOS 26.5 验证 `InkMarkdown-Package` scheme：313 项总计，312 项通过，0 项失败，1 项跳过；具体证据以 [docs/current-status.md](docs/current-status.md) 为准。
- ⏳ `InkMarkdownSwiftUI` adapter 源码已按 ADR-008 实现（提供 `InkMarkdownView`、`InkStreamMarkdownView`、`InkMarkdownRenderSession`、`.inkConfiguration()` 等公开类型），基础契约测试与 ExampleApp 的静态、配置、流式示例入口已具备；完整语义对齐测试、iOS/iPadOS 14 验证、可访问性、性能基线和发布文档仍为 v0.0.2 release blocker。
- ⚠️ 此前被拒绝的 SwiftUI spike 已移出仓库；当前 v0.0.2 adapter 已按 ADR-008 作为独立 product 完整实现，基础契约测试与 ExampleApp 示例入口已验证，完整发布验收仍待完成。
