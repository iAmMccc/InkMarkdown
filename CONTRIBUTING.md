# 贡献者指南 (Contributing to InkMarkdown)

感谢你关注并参与 **InkMarkdown** 的建设！为了保持项目的架构一致性与代码质量，请在提交代码或 Issue 前仔细阅读本指南。

---

## 核心定位与原则

在开始贡献前，请确保理解 InkMarkdown 的核心原则（详见 [AGENTS.md](AGENTS.md)）：

1. **UIKit-first + SwiftUI adapter**：`InkMarkdown` 保持 UIKit rendering engine；v0.0.2 的 `InkMarkdownSwiftUI` 是独立 adapter product。实现必须遵守 [ADR-008](docs/decisions/ADR-008-swiftui-adapter-architecture.md)，不以 WebView/HTML 作为核心路径。
2. **纯粹依赖 `swift-markdown`**：解析层 100% 使用 Apple 官方 `swift-markdown` AST，不做自定义语法解析器替代方案。
3. **不做补丁式设计**：局部修改必须保持与全局架构与统一样式上下文（`InkAppearance` / `InkConfiguration`）的一致性。

---

## 开发与环境配置

- **Swift 工具链**：Swift 6.2+（Package 采用 Swift 5 语言模式）
- **目标平台**：iOS 14.0+
- **本地依赖**：`swift-markdown` 依赖采用 Git revision 锁定。离线开发可参阅 [ADR-001](docs/decisions/ADR-001-swift-markdown-dependency-pinning.md)。

### 构建与测试

因为源码直接依赖 UIKit，在 macOS 主机环境中使用 `swift build` 或 `swift test` 会因找不到 UIKit 模块而报错。

**请务必在 iOS Simulator 目标上进行构建与测试**：

```bash
xcodebuild test \
  -scheme InkMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```

详细本地开发与排坑说明见 [docs/contributor-guide/04-development.md](docs/contributor-guide/04-development.md)。

---

## 贡献流程

### 1. 提交 Issue

在提交 Issue 前：
- 检索既有 Issue、[FAQ](docs/contributor-guide/06-faq.md) 与 [ExampleApp 走查 SSOT](docs/qa/example-app-walkthrough-issues.md)，确认是否为已有已知问题或系统控制台噪声；
- 明确描述重现步骤、使用的 Markdown 输入、期望输出与实际行为；
- 如涉及崩溃或渲染错乱，请附带样例工程或单元测试用例。

### 2. 提交 Pull Request (PR)

- **分支管理**：基于 `main` 分支拉取功能分支开发（如 `feature/xxx` 或 `fix/yyy`）；
- **代码规范**：代码结构清晰，公共 API 须附带完整的中文 Markdown 文档注释，说明参数、逻辑与返回值；
- **测试覆盖**：新增功能或修复 Bug 必须包含对应的单元测试（位于 `Tests/InkMarkdownTests/`）；
- **文档同步**：如果修改涉及公开 API、配置项或 Markdown 语法支持情况，必须同时更新 `README.md` 与 `README.zh-CN.md`。

---

## 进一步阅读

关于整体架构、渲染管线设计及核心原理，请深入阅读：

- 📖 [贡献者手册目录](docs/contributor-guide/README.md)
- 🏗️ [架构设计](docs/contributor-guide/02-architecture.md)
- 💡 [渲染原理](docs/contributor-guide/03-principles.md)
- 📐 [渲染语义规范](docs/spec/README.md)
- 📝 [架构决策记录 (ADR)](docs/decisions/README.md)
