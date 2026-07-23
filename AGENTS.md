# InkMarkdown

基于 Apple [swift-markdown](https://github.com/apple/swift-markdown) 的 **UIKit 专用** Markdown 解析与渲染库。核心差异化：把 Markup 树渲染为 `NSAttributedString`，填补三代库（swift-markdown / MarkdownUI / Textual）均不支持 UIKit 的能力空缺。

> 📌 **明确不做 SwiftUI**：InkMarkdown 定位是 UIKit 库。SwiftUI 场景已有 MarkdownUI / Textual 覆盖，不重复造轮。

## 项目结构

```
InkMarkdown/
├── Package.swift              # SPM 包定义（swift-tools-version: 6.2）
├── Sources/InkMarkdown/       # Parser / Configuration / Rendering
├── Tests/InkMarkdownTests/    # 语义、快照骨架与流式性能测试
├── ExampleApp/                # 示例 App（UIKit）
│   ├── ExampleApp.xcodeproj
│   └── ExampleApp/            # AppDelegate / SceneDelegate / ViewController
├── Packages/                  # 本地依赖拉取脚本；Caches/ 不提交 Git
├── docs/                      # 状态、路线、贡献者指南、规范、参考
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
xcodebuild -scheme InkMarkdown -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' test
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

## 当前状态

项目已越过初始化阶段，当前处于 **v1.0 前的实现完善与发布准备阶段**：

- ✅ `InkAttributedRenderer`、`InkBlockRenderer`、`InkStreamRenderer` 已实现
- ✅ `InkAppearance` / `InkConfiguration` 与行内、块级扩展点已实现
- ✅ 代码块、表格、分割线 UIKit 组件与 ExampleApp 已实现
- ✅ 32 个 iOS Simulator 测试覆盖行高、样式上下文、流式边界、性能一致性与快照骨架
- ✅ contributor guide、渲染语义规范和 swift-markdown API 参考已建立
- ⏳ 完整语义测试矩阵、公开 API 审计、CI、CHANGELOG 与稳定版本待补
- ⚠️ 当前 manifest / 平台声明与目标依赖策略、目标平台矩阵仍有差异

完整且可维护的状态基线见 [docs/current-status.md](docs/current-status.md)。
