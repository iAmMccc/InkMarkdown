# SwiftUI adapter 数据流收敛验证（2026-09-09）

## 范围与结果

基线为 `feat/swiftUI` 的 `a7452e0abf9c500d898817dedead3a568804773a`。修改版指基于该提交的未提交工作树；本次没有提交或推送。

- 静态 Coordinator 将语义输入收敛为 `StaticPresentation`。Markdown 或语义配置变化时解析；测量、宽度变化、折叠交互只消费现有 blocks。
- 删除静态挂载镜像标记、重复的最近输入/已渲染配置字段，以及恒为成功的挂载 helper 和纯转发释放 helper。
- session 删除 `remainderText`、`streamingThoughtText`、`hadStreamingThought`、`publishGeneration`。正文从 renderer 读取，思考正文从当前 block 追加，延迟任务由 `PublishHopper` 统一替换/取消。
- 删除 PREFIX 确认时的 renderer reset：scanner 在标签未决期间不放行正文，无需撤回推测内容。
- 保留 source-limit、后台解析代次、attachment/grant 所有权、延迟发布以及 reset 时重新安装完成回调。renderer 在完成时会消费 `onFinishDisplay`，该重新安装不可删除。
- 公开接口、UIKit-first / Markup 直渲染与 continuity 所有权不变。

两个生产文件从 814 行变为 723 行，净减 91 行；两个主类顶层可变属性声明净减 10 个。没有删除生产文件，没有新增网络请求，也没有引入新的缓存失效机制。结构化呈现输入保留当前 blocks，仍由 continuity 管理视图和测量。

## 验证环境

- Scheme：`InkMarkdown-Package`。
- Destination：iPhone 17 Pro，iOS 26.5，arm64，`17F14464-87ED-4C51-9CBD-C2DC1F6D5F66`。
- 构建与测试：XcodeBuildMCP；基线对照使用相同 Xcode 的 `xcodebuild`。
- 使用 `.build/index-build` 中的既有依赖 checkout；四个 checkout 的 HEAD 均匹配 `Package.resolved`，工作树干净。远程 manifest 和 resolved 文件未修改。
- 默认依赖获取失败，指定已有 checkout 后解析和编译成功。这证明固定源码的本地构建，不证明全新远程下载或远端 CI。

共同参数：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme InkMarkdown-Package \
  -destination 'platform=iOS Simulator,id=17F14464-87ED-4C51-9CBD-C2DC1F6D5F66' \
  -clonedSourcePackagesDirPath /Users/shizihan/DailyUse/Github/InkMarkdown/.build/index-build \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -only-testing:InkMarkdownSwiftUITests \
  -skip-testing:InkMarkdownSwiftUITests/InkMarkdownAdapterWorkloadTests test
```

工作负载套件单独运行，改为 `-only-testing:InkMarkdownSwiftUITests/InkMarkdownAdapterWorkloadTests` 并移除 skip 参数。

## 结果与基线对照

| 检查 | 修改版 | 原始 HEAD |
| --- | --- | --- |
| SwiftUI 契约与集成测试，工作负载套件除外 | 84 通过 / 4 失败 / 0 跳过 | 84 通过 / 相同 4 失败 / 0 跳过 |
| 工作负载套件（含新增用例） | 4 通过 / 0 失败 / 0 跳过 | 新增用例单独运行失败，暴露重复解析 |
| 首次渲染、折叠与 360 → 744 → 360 测量的文档解析次数 | 1 | 5 |
| 内容、配置变化以及 blocks → Markdown 切换 | 按输入变化重新解析，断言通过 | 存在前述多余解析 |
| `git diff --check` | 通过 | 不适用 |

基线通过 `git archive HEAD` 导出到临时目录，不切换当前分支，不覆盖用户工作树。只复制新增工作负载测试用于验证它能识别旧行为。

同样失败的现有用例：

1. `InkCorpusSwiftUIIntegrationTests/staticIntegration_matchesCorpusSemantics(fixture:)`
2. `InkCorpusSwiftUIIntegrationTests/streamingPromotion_matchesCorpusSemantics(fixture:)`
3. `InkPartialBlockReuseTests/tableLayout_changesUpdateRenderedStructure()`
4. `InkPartialBlockReuseTests/imageBlock_replacingCancelsOldSubscriptionAndShowsNewImage()`

前三项在没有有效测量宽度时读取表格单元格，当前表格延迟到有效宽度才构建该层级。图片用例在两版同范围运行时均未在期限内观察到完成，原始 HEAD 的局部套件运行通过；具体调度原因未进一步定论。本次保留这些失败，不通过删除断言掩盖它们，也不将其报告为已修复。

首轮删除 reset 回调重装引入的失败已修复；最终重置、取消、终态发布、宿主接管、重挂载和思考折叠相关测试通过。

本地结果包：

- `/tmp/inkmarkdown-refactor-final-20260909.xcresult`
- `/tmp/inkmarkdown-refactor-final-workload-20260909.xcresult`
- `/tmp/inkmarkdown-refactor-baseline-full-20260909.xcresult`
- `/tmp/inkmarkdown-refactor-baseline-workload-20260909.xcresult`

## 未验证范围

没有执行独立 lint/typecheck 命令；Swift 类型检查包含在 Simulator 测试构建中。未执行 ExampleApp 手工操作、真机性能、iOS 15 runtime 或远端 CI。文档解析次数下降是确定性工作量证据，不等同于 FPS、峰值内存或整库性能提升的测量。
