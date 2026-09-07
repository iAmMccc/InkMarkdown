# 执行、验证与证据指南

本指南供后续实施模型使用。本轮没有运行下面的构建/测试命令；只核对了当前源码、CI 配置与本机 `xcodebuild -help` 支持的参数。

## 1. 每次接票的固定动作

1. 确认用户对本票/范围有实施授权。规划文件的 ready 状态不能代替授权。
2. 在 `/Users/shizihan/DailyUse/Github/InkMarkdown` 阅读根 AGENTS.md、本票、对应详细 spec；无需重新阅读全部 27 票。
3. 查看 `git status --short`、branch、HEAD 和本票涉及文件的差异。不要 checkout、reset、stash 或清理其他人的变更。
4. 读取 `Blocked by` 票的完成记录，核对 Acceptance 和 log/xcresult，不以“文件存在”视为前置完成。
5. 按符号核对本票入口。计划新建的文件先检查是否被前置票创建，禁止重复实现或覆盖。
6. 只实施本票 outcome。完成后输出证据与遗留过渡代码；没有后续范围授权时停止，不自动领下一票。

所有 tickets 的 `Status` 记录 triage readiness。这里不是 Wayfinder workflow，不要擅自使用 claimed/resolved 代替仓库 triage 状态。可在 Comments 记录开始/完成时间；完成判定为 Acceptance 全部满足且有证据。如果出现产品/契约缺口，则将受影响票改为 needs-info 并写清待决项。

## 2. 改动与兼容性原则

- 不按文件行数拆 module；以 caller 不必再维护来源/订阅/owner 顺序为结果。
- 新 module 默认 internal/private，保持现有 public/SPI 声明、默认参数、availability、actor isolation。公开类型的内部存储可以变，公开行为不能悄悄变。
- internal 测试 seam 不代表需要 public 协议；新测试不应反向要求生产代码暴露 token、字典或缓存 revision。
- 迁移期允许两个实现临时并存，只用于 expand→migrate；08/16/25 必须删除旧重复路径。
- 基线失败先分类：环境、既有代码、所选场景暴露的既有缺陷、本票引入回归。不能把每一种都标为 needs-info，也不能统一跳过。
- 只有有明确定义行为的范围内问题才随票修；涉及公开契约/ADR 的冲突记录后停受影响部分。

## 3. 工具选择与动态发现

按 [tooling](../../docs/agents/tooling.md)：符号优先 Serena；测试/Simulator 优先 XcodeBuildMCP。工具 schema 以当前加载版本为准，不能复制历史工具名。

XcodeBuildMCP 不可用时，先检查已安装 CLI；再使用 xcodebuild/xcrun。不要为了文档中的建议安装工具或升级 Xcode。

以下为 fallback 模板，执行时在仓库根目录：

```sh
git branch --show-current
git rev-parse HEAD
git status --short
xcodebuild -version
xcodebuild -list -json
xcodebuild -scheme InkMarkdown-Package -showdestinations
xcrun simctl list devices available
```

`InkMarkdown-Package` 和 `ExampleApp` 是当前 CI 核对过的 scheme；实施时仍需确认。选择当前可用的 iOS Simulator，记录 device name、runtime version 和 UDID。不要写死本规格中的历史设备标识。iOS 18 与 26 可用时作为不同运行时样本；没有某版本时写未验证，不将 deployment target 改低/改高来绕过。

依赖使用仓库 remote pin。网络解析失败时记录原因；仅按已授权环境准备范围建立临时本地覆盖，结果注明 local overlay。禁止提交 `Packages/Caches`、path manifest 或私有依赖内容。

## 4. 可复用的测试命令模板

先从发现结果填写 `INK_TEST_DESTINATION`，值形如 `platform=iOS Simulator,id=<实际发现的 UDID>`。尖括号占位符不能原样执行。每次运行使用全新的 result path，避免 xcodebuild 因路径已存在失败。

```sh
# 在仓库根目录执行。先把此值替换成实际发现结果。
INK_TEST_DESTINATION='platform=iOS Simulator,id=REPLACE_WITH_DISCOVERED_UDID'
INK_EVIDENCE_ROOT="$PWD/.scratch/architecture-deepening-2026-09-07/evidence"
INK_RUN_DIR="$INK_EVIDENCE_ROOT/$(date +%Y%m%d-%H%M%S)-ticket-NN"
mkdir -p "$INK_RUN_DIR"
set -o pipefail
xcodebuild test \
  -scheme InkMarkdown-Package \
  -destination "$INK_TEST_DESTINATION" \
  -only-testing:InkMarkdownTests/InkAuditSemanticRegressionTests \
  -resultBundlePath "$INK_RUN_DIR/tests.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$INK_RUN_DIR/test.log"
```

`ticket-NN`、destination 和 test selection 均需按当前票替换。若使用 MCP，记录其等价参数及返回的真实结果路径，不必再执行 fallback 命令。

### 测试选择器不能猜

本机 help 已确认支持 `-enumerate-tests`、`-test-enumeration-format` 与 `-test-enumeration-output-path`。可在同样的 scheme/destination 下枚举：

```sh
xcodebuild test \
  -scheme InkMarkdown-Package \
  -destination "$INK_TEST_DESTINATION" \
  -enumerate-tests \
  -test-enumeration-format json \
  -test-enumeration-output-path "$INK_RUN_DIR/discovered-tests.json" \
  CODE_SIGNING_ALLOWED=NO
```

枚举可能需要构建/依赖解析，不能把它当成零成本文件扫描。已有准确选择器时直接使用；新 suite/全局函数选择不清楚时再枚举。退出码 0 但运行 0 tests 不算通过。`ImageRenderingTests.swift` 包含多个全局 @Test 和 `InkImageStoreTests` suite；它不是名为 ImageRenderingTests 的单一 suite，禁止按文件名猜过滤器。

## 5. 验证组与选择范围

| 组 | 当前已核对入口 | 使用时机 |
| --- | --- | --- |
| baseline | InkAuditSemanticRegressionTests、InkCorpusTableTracerTests、InkImageStoreTests、InkMarkdownRenderSessionTests、InkBlockPresentationContinuityTests、InkMarkdownAdapterWorkloadTests | 01；只建立受影响关键链路基线 |
| table | 新 InkTablePresentationTests；既有 InkAuditSemanticRegressionTests、InkCorpusTableTracerTests；受影响的 AccessibilityAndDynamicTypeTests 场景 | 02–08，按票选最小子集 |
| image | 新 InkImagePresentationLoadTests/InkImagePreviewLoadTests；既有 InkImageStoreTests；ImageRenderingTests 中相关全局函数 | 10–16；actor/共享资源改动必要时扩至 InkMarkdownTests target |
| session | 新 InkStreamingPresentationHostTests；InkMarkdownRenderSessionTests、InkBlockPresentationContinuityTests、InkMarkdownLoopPreventionTests、InkMarkdownAdapterWorkloadTests、InkRenderSessionSourceLimitTests | 18–25，按调用链选子集 |
| direction exit | 方向完整组及相邻消费者：表格加 InkCorpusSwiftUIIntegrationTests/measurement，图片加 InkMarkdownAddonContractTests，宿主加真实 remount | 09、17、26 |
| final | InkMarkdownTests、InkMarkdownCoreContractTests、InkMarkdownSwiftUITests、InkMarkdownAddonContractTests、InkMarkdownLaTeXTests、InkMarkdownMermaidTests；四 consumer build；ExampleApp | 27，只在整合候选上一次完成必要门槛 |

新 suite 名称为规划名。实现者调整命名时同步本指南与票中记录，不能留下不存在的测试指令。direction exit/final 已由同一最终候选的有效证据覆盖时无需重复；修改重叠文件、失败或未解决风险才使旧证据失效。

## 6. ExampleApp 与独立 product

四 product consumer fixture 在 [consumer-smoke](../../.github/fixtures/consumer-smoke/Package.swift)。当前 CI 核对过的 scheme：InkMarkdownCoreConsumer、InkMarkdownSwiftUIConsumer、InkMarkdownLaTeXConsumer、InkMarkdownMermaidConsumer。

```sh
# 每次只构建所选 scheme，四个分别记录。
# 从仓库根目录进入，不复制或改写 consumer manifest。
cd .github/fixtures/consumer-smoke
xcodebuild build \
  -scheme InkMarkdownCoreConsumer \
  -destination "$INK_TEST_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO
```

ExampleApp 从仓库根目录使用：

```sh
xcodebuild build \
  -project ExampleApp/ExampleApp.xcodeproj \
  -scheme ExampleApp \
  -configuration Debug \
  -destination "$INK_TEST_DESTINATION" \
  CODE_SIGNING_ALLOWED=NO
```

Release 独立构建记录 configuration=Release。安装与启动优先 Simulator 工具动态发现 app 路径/bundle identifier；构建成功不能记成已启动。

Mermaid 真实 PNG 的 app-hosted suite 是 `ExampleAppMermaidIntegrationTests`，按当前 CI project/scheme 调用。Package 无宿主测试只验证确定性契约；不得用离屏 WebKit 失败重新设计 Mermaid renderer。若本次未触及实际生图，方向票用 addon contract，联合交互确认可用即可；只有相关回归才扩大真实 PNG 检查。

## 7. 最小交互脚本与观察

这些是验收步骤，不是扩展产品或强制新增 UI 自动化的需求。已有 Demo 无法直接表现某个异步竞态时，使用 controlled loader 契约测试证明竞态，Demo 只验证视觉/交互。

| 场景 | 操作 | 必须记录的结果 |
| --- | --- | --- |
| 表格静态/逐行 | 打开既有表格入口，窄宽切换；点击富文本链接，长按复制 | wrap 恢复、scroll viewport、复制只有实际行、链接触发原 handler |
| 图片 | 开启既有图片 Demo，观察 inline/block，旋转或改宿主宽 | 图片重测、段落几何、占位/失败状态无意外变化 |
| 预览 | 进入预览，高清加载中关闭，再进入 | 退出有效、新图不被旧任务替换、失败仍保留原图 |
| SwiftUI 流式 | 开启含 Thought/正文/表格/图片的既有输入，finish，切环境，退出再进入，reset/cancel | Thought 状态与终态内容连续、旧内容不复活、尺寸与链接可用 |
| 组合候选 | 同一运行中同时经过表格重建、图片异步到达、会话 promotion/remount | 三方向协作无串台、错图或丢失终态块 |

不默认添加 broad UI tests。S-13 的真实 UIHostingController 测试是例外的明确关键回归，范围只限 remount/promotion 生命周期。

## 8. 证据模板

每票将实际信息写入其指定 evidence 文件，不能提前填写“通过”：

```markdown
# NN 验证证据

- 日期：
- Branch / HEAD：
- 工作树范围与相关 diff 摘要：
- 依赖：remote pin / local overlay（具体范围）
- Toolchain / scheme / destination：
- 实际命令或 MCP 参数：
- 自动测试：通过 / 失败 / 跳过 / 未执行，各自数量：
- log / xcresult：
- App build：Debug / Release：
- 安装启动：
- 交互场景与观察：
- 公共 interface / ADR 核对：
- 验收编号到上述证据的映射：
- 未验证项、失败归因、阻塞的后续票：
- 仍需后续删除的过渡代码：
```

大体积 xcresult/log 可留本地并记录绝对路径，不默认提交二进制。票和规格是持续交接资料，路径应保持可访问。远程 CI 只有实际执行并取得结果才记通过；本轮没有 push/CI 授权。
