# InkMarkdown agent guidance

回复遵循用户全局偏好；本文件只维护仓库约束。


## 产品边界

- UIKit-first Markdown 库：swift-markdown 解析，`NSAttributedString` 与可路由 `UIView` block 渲染。
- `InkMarkdownSwiftUI` 是独立 presentation adapter，与 UIKit 共享渲染语义。v0.0.2 保持 Markup 直渲染，InkIR 留待 v2；修改此边界前核对 [ADR-008](docs/decisions/ADR-008-swiftui-adapter-architecture.md)。
- v0.0.2 发布目标仅 iOS / iPadOS 15+；目标不代表已经验收。Swift 工具链 6.2+，language mode 和依赖版本读取 `Package.swift`。
- swift-markdown 默认固定远程 revision；本地 `Packages/Caches/` 与 `path:` 仅为临时离线覆盖。发布 manifest 保持远程 pin，缓存源码不提交。依赖改动查 [ADR-001](docs/decisions/ADR-001-swift-markdown-dependency-pinning.md)。

## 执行与完成

围绕请求涉及的调用链、状态所有者和共享边界解决根因；改动范围由实际影响决定。常规实现选择自行处理，若方案改变公共契约或与 ADR 冲突，先说明冲突及影响。

“分析并修改”包含实施、适用验证和修复本次引入的失败。已有授权持续有效；仅需讨论、出 spec 或拆 tickets 时，以相应文档为交付物。`needs-info` 保留未决问题，不自动视为实现授权。

遵守用户指定的 checkout 和交付范围。保留无关工作树变更；提交按功能边界拆分。创建 PR、push 或对外发消息依照当前授权，skill 不自行扩大权限。

## 按任务读取

| 任务 | 入口 |
| --- | --- |
| 当前交付、发布验收 | [current-status](docs/current-status.md)；用当前源码与执行结果核验历史证据 |
| 架构或模块契约 | [领域规则](docs/agents/domain.md)，只读相关术语与 ADR |
| SwiftUI adapter | [总体设计](docs/contributor-guide/08-swiftui-adapter-architecture.md) |
| Markdown 渲染语义 | [语义规范](docs/spec/) |
| 开发环境或依赖准备 | [开发指南](docs/contributor-guide/04-development.md) |
| 本地 spec / ticket | [issue tracker](docs/agents/issue-tracker.md)；状态查 [triage labels](docs/agents/triage-labels.md) |

目录结构、版本和测试数量从当前文件读取；不把历史状态复制进常驻指令。

## 工具与验证

符号与引用优先 Serena；文档、配置和字符串用 `rg`。Apple 官方 API 优先 apple-docs；其他三方库文档优先 Context7。构建、测试与 Simulator 优先 XcodeBuildMCP。按当前暴露的工具 schema 调用；具体任务需要这些工具时才读 [工具与验证规则](docs/agents/tooling.md)。

验证按影响选取：文档改动检查链接与差异；UI 改动检查受影响的构建和交互；解析、流式状态或公共契约改动运行相关契约测试。新增测试应能区分正确行为与回归，遵守用户指定的测试范围。适用检查通过即交付；仅新改动、失败或未解决风险触发重跑或扩大范围。

Swift Package 测试选择 iOS Simulator，不能用 macOS host 的 UIKit 缺失判定库失败。报告实际 scheme、destination、测试结果及未验证项；构建、安装启动、交互验收与远程 CI 分别陈述。本地依赖覆盖成功不证明远程依赖可解析。

## 文档与 skills

公开 API 使用完整中文文档注释；内部注释解释原因。README 核心信息改动同时同步 `README.md` 与 `README.zh-CN.md`。个人学习教程保留在个人知识库，不引入开源仓。

复用用户全局 skills，不复制到仓库。按任务选最少的相关 skill，支持文档按分支读取。用户已经要求实施时，讨论或规划 skill 不添加第二道批准门槛。

批量资料提取可利用 Cursor；用户要求转交时提供含输入、产出路径和验收标准的完整 prompt。文件数量本身不构成停止条件。只有存在独立、有边界的子任务且宿主允许时才考虑子代理；避免多个代理同时编辑同一文件，整合者核验关键证据。
