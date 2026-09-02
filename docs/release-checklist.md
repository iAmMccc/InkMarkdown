# InkMarkdown v0.0.2 发布清单

本清单用于维护者判断某个提交是否可以成为 v0.0.2 Release Candidate，以及后续是否可以发布。勾选清单不授权 push、创建 Pull Request、合并、创建 tag 或发布 GitHub Release；这些操作仍需维护者分别确认。

## 权威依据

- 产品、平台与依赖：[`Package.swift`](../Package.swift) 与 `Package.resolved`
- 当前交付事实与 blocker：[`current-status.md`](current-status.md)
- 发布范围与退出标准：[`roadmap.md`](roadmap.md)
- 用户可见变更：[`CHANGELOG.md`](../CHANGELOG.md)
- 本轮候选验证证据：[`.scratch/v0.0.2-library-readiness/evidence/`](../.scratch/v0.0.2-library-readiness/evidence/README.md)
- 交互 / 图片本地候选证据（工作树 atop `8fb1640`）：[`qa/InkMarkdown-interaction-acceptance-2026-09-02.md`](qa/InkMarkdown-interaction-acceptance-2026-09-02.md)
- 远端门禁：[`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

出现冲突时先按知识层级判断：产品边界与架构服从 `AGENTS.md`、ADR 和 roadmap；渲染语义服从 `docs/spec/`；当前已交付 API、平台与验证事实由 manifest、源码和最新可复现证据证明。实现不符合既定规范时必须修复实现，不能仅改文档消除差异。

## 1. 候选提交冻结

- [ ] 候选提交 SHA 已记录，工作树干净。
- [ ] 改动已按功能粒度提交；提交中不包含 `.build/`、`DerivedData/`、`Packages/Caches/`、`xcuserdata/`、凭据或本机绝对路径。
- [ ] 候选提交相对 `main` 的完整 diff 已审查，且无未解决 P1/P2。
- [ ] Release Candidate 验证开始后，不再修改候选提交；任何代码或文档提交都会产生新 SHA，并使旧 SHA 的验证失效。

## 2. 产品与平台边界

- [ ] `Package.swift` 仍只声明 iOS 14+；没有把未验证平台写成受支持平台。
- [ ] `InkMarkdown` 保持 UIKit-first rendering engine。
- [ ] `InkMarkdownSwiftUI` 仍是复用 UIKit 语义的独立 adapter，而非第二套 native SwiftUI renderer。
- [ ] 四个 product 均能由外部消费者独立导入和构建：`InkMarkdown`、`InkMarkdownSwiftUI`、`InkMarkdownLaTeX`、`InkMarkdownMermaid`。
- [ ] Core 消费者不被迫链接 iosMath 或 Mermaid 资源；optional addon 的依赖和资源没有泄漏到 Core。

## 3. 公开 API 与兼容性

- [ ] 已将候选公开 interface 与已发布 tag `0.0.1` 比较；没有删除或破坏任何 `0.0.1` 已发布源 API，必要的兼容 facade 仍保留。本门禁审计 source compatibility，不承诺 binary compatibility。
- [ ] v0.0.2 新增公开 API 只暴露消费者需要的入口；registry、scanner、provider 和 adapter 内部接缝保持 `package` 或 `internal`。
- [ ] 所有公开 API 均有完整中文文档注释，参数、返回值、失败和线程/生命周期约束与实现一致。
- [ ] 错误、长度上限、取消、重试和 addon 不可用等关键结果可观察，且 README、CHANGELOG 与实现一致。

## 4. 依赖、资源与许可证

- [ ] `swift-markdown` 使用固定 revision，`Package.resolved` 与 manifest 一致。
- [ ] iosMath 版本、许可证和字体许可记录仍准确。
- [ ] Mermaid 本地资源、第三方声明和打包方式已复核；发布产物不依赖未声明的远端运行资源。
- [ ] 依赖升级已在 iOS Simulator 上重跑受影响测试与四 product 消费者构建。
- [ ] 仓库与发布说明未包含三方缓存源码、构建产物或不应再分发的测试资源。

## 5. 自动化验证

优先使用 XcodeBuildMCP 发现可用 scheme 与 iOS Simulator destination。MCP 不可用时，先记录安装/注册排查，再使用原生 `xcodebuild`；不要把 macOS host 上 `swift test` 的 `no such module 'UIKit'` 当作库失败。

- [ ] `InkMarkdown-Package` 全量测试通过；只允许已记录且与候选范围无关的 skip。
- [ ] Core、SwiftUI adapter、addon contract/LaTeX 与确定性 Mermaid 关键路径分别通过。
- [ ] 已审计 Phase S2/S3 的必要语义矩阵：静态、流式、configuration、自定义扩展、opt-in capabilities（Core 图片加载、Store、取消、缓存与安全策略，以及 LaTeX/Mermaid addons），以及 session 结束、取消、重置、重新绑定和 promotion 生命周期关键契约均有数据、状态或语义证据；纯视觉、交互与非核心路径不扩张单测。
- [ ] ExampleApp app-hosted Mermaid PNG 关键链路通过；不在无 App 生命周期的 SwiftPM runner 中执行真实 WKWebView PNG 回归。
- [ ] 外部 consumer fixture 的四个单 product scheme 分别构建通过。
- [ ] ExampleApp 的 Debug 与 Release 配置均构建通过。
- [ ] 自动化只覆盖数据、状态、语义、调用次数、消费者接入和关键业务链路；没有为纯视觉或非核心路径扩张单测。
- [ ] 最新命令、scheme、destination、结果和失败/跳过原因已写入候选验证证据；不复制过期测试数量。

## 6. ExampleApp 人工验收

UI 与视觉行为通过 ExampleApp 手工验收，不以 UI 自动化或视觉快照代替。每轮记录入口、设备、系统、输入、结果和未验证项。

- [ ] iPhone 与 iPad 均覆盖静态 Markdown、configuration、组件和流式入口。
- [ ] Thought 卡片完整包裹 Thought 正文；闭标签后的普通 Markdown 位于卡片外；行内代码背景不被 Thought 背景吞并。
- [ ] Thought 折叠态在同文档更新、宽度变化、卸载/重挂和 streaming promotion 后保持正确。
- [ ] Dynamic Type、VoiceOver、链接交互、表格滚动、LaTeX、Mermaid 与 opt-in 网络图片完成适用的人工走查。
- [ ] 旋转、Split View 与无初始宽度协商在支持的 iPad 场景通过。
- [ ] 未验证路径明确记录为 blocker；不能用共享生产源码或相邻设备结果代替实际设备/入口证据。

## 7. 平台与性能发布门槛

- [ ] iOS 14 与 iPadOS 14 的实际 runtime 或设备验证通过；仅设置 deployment target 或编译成功不算最低版本运行证据。
- [ ] 当前 iOS 的 iPhone 与 iPad 验证通过。
- [ ] 真机性能基线覆盖滚动、流式长文、图片/生成图加载、WebKit 冷启动、内存峰值和长会话，并记录可复现输入与测量方法。
- [ ] 性能结论没有使用未经复现的 FPS、内存或竞品数字。
- [ ] 若最低版本环境仍不可用，由维护者明确选择获取验证环境或调整产品范围；不得自动提高 deployment target，也不得宣称对应支持已交付。

## 8. 文档与开源治理

- [ ] `README.md` 与 `README.zh-CN.md` 的产品范围、安装示例和公开 API 保持一致，并明确区分已发布 `0.0.1` 与未发布 `0.0.2`。
- [ ] `CHANGELOG.md`、`CONTRIBUTING.md`、`SUPPORT.md`、`CODE_OF_CONDUCT.md`、Issue 模板、PR 模板、Dependabot、`current-status.md` 和 roadmap 与候选状态一致。
- [ ] 新增文档已从 `docs/README.md` 或对应目录索引链接。
- [ ] 私密漏洞报告渠道已由维护者确认可用并持续有人处理；只有此后才创建或更新 `SECURITY.md`。公开 Issue 不接收凭据、个人数据或漏洞细节。
- [ ] 文档没有把本地测试、旧 SHA、计划或推断写成当前远端通过事实。

## 9. 远端 Release Candidate 门禁

以下步骤只在维护者明确授权 push 与 Pull Request 后执行。

- [ ] 将候选 SHA 推送到维护者授权的 PR head 分支，并记录实际分支名；远端分支头与本地候选 SHA 完全一致。
- [ ] 创建或更新指向 `main` 的 Pull Request；PR 描述包含范围、验证证据、blocker 与不在范围内的事项。
- [ ] 同一候选 SHA 上，`package-tests`、`consumer-builds`、`example-app` 与 `mermaid-hosted-integration` 的全部必要 GitHub Actions job 通过。
- [ ] 没有用 rerun、超时增加或测试删除掩盖真实失败；任何修复都会生成新候选 SHA 并重新执行全部必要门禁。
- [ ] 同一 SHA 的 Standards 与 Spec 复审无未解决 P1/P2。

## 10. 发布操作

以下步骤不属于 Release Candidate 构建任务，必须另获维护者明确授权。

- [ ] 合并策略和最终提交已确认；必要门禁仍对应将要发布的提交。
- [ ] `CHANGELOG.md` 的 `[Unreleased]` 内容已整理为 `0.0.2`，版本日期与实际发布日期一致。
- [ ] 创建并推送 `0.0.2` tag。
- [ ] 创建 GitHub Release，发布说明只陈述有证据的能力、平台和已知限制。
- [ ] 从干净环境按 tag 完成一次消费者解析/构建复核。
- [ ] 发布后核对 tag、Release、文档链接和 SPM 消费路径；发现问题时记录修复或撤回方案。

## 当前候选状态

本节不复制易漂移的测试计数或 blocker 清单。当前 v0.0.2 尚未满足全部发布门槛；未完成项以 [`current-status.md`](current-status.md)、[`roadmap.md`](roadmap.md) 和[本轮验证证据](../.scratch/v0.0.2-library-readiness/evidence/verification.md)为准。任何未勾选门禁都不能被基础契约通过替代。
