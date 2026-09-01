# CI 与工具链排坑

本文说明 CI 固定工具链配置、本地 Xcode 与 CI 的关系、常见 failure 原因以及版本升级流程。

配置文件：`.github/workflows/ci.yml` 顶部的 `env:` 块。  
镜像参考：[actions/runner-images macos-26-arm64-Readme](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)。

## 1. CI 工具链配置

| 维度 | 固定配置（以 workflow `env` 为准） | 作用 |
| --- | --- | --- |
| Runner | `macos-26` | 指定托管镜像版本 |
| Xcode | `26.6` → `/Applications/Xcode_26.6.app` | 指定编译器与 SDK |
| Xcode Build | `17F113` | 校对具体 Build 版本 |
| 模拟器 | `iPhone 17 Pro` + **OS=`26.5`** | 固定模拟器 Runtime |
| 依赖 | `Package.swift` revision + `Package.resolved` | 固定 swift-markdown 等依赖 |

CI 不会使用：

- 贡献者本机的 Xcode / `xcode-select`
- 本机 `DerivedData`、`.build`、`Packages/Caches`
- 本机已安装的模拟器列表

项目需符合：`swift-tools-version: 6.2`、UIKit、`iOS 14+`。PR 合并门禁以 CI 固定的环境为准。

## 2. 本地与 CI 环境差异

| 场景 | 现象与影响 | 处理建议 |
| --- | --- | --- |
| 本地与 CI 版本一致（如 26.6） | 构建和测试结果一致 | 推荐配置 |
| 本地 Xcode 版本更新（如 27.x） | 本地正常但 CI 失败（使用了新 API 或新的 Swift 语法要求） | 以 CI 报错为准修复；若需使用新 API 需评估升级 CI 版本 |
| 本地 Xcode 版本旧于最低要求 | 无法解析 tools 6.2 或缺少 SDK | 升级本地 Xcode 至符合文档要求的最低版本 |
| 本地使用 `Packages/Caches` 离线覆盖 | 仅影响本地，CI 仍然读取 `Package.resolved` | 勿提交本地 path 修改 |

协作规范：

1. CI 构建测试通过是代码合并的唯一依据。
2. 开发者可使用更新版本的 Xcode 进行开发，但必须保证 PR 能在 CI 固定版本中通过。
3. 若 CI 报红，需在固定对应的 Xcode 版本中复现排查。
4. 升级 CI 的 Xcode 版本属于显式变更，需要同步更新 `.github/workflows/ci.yml` 与相关文档。

## 3. 未固定环境的影响与对策

| 风险 | 原因 | 仓库对策 |
| --- | --- | --- |
| 本地通过但 CI 失败 | 本地与 CI 工具链版本不一致 | 在 CI 中固定 Xcode 与模拟器版本 |
| 新 API 误引入主分支 | 开发者本地 Xcode 版本过新 | CI 使用固定旧版本环境拦截 |
| CI 间歇性失败 | 选用了动态最新 Xcode 或未指定 OS | 固定 Xcode 路径、Build 号及 `OS=` 参数 |
| 贡献门槛过高 | 要求开发者本地版本与 CI 完全一致 | 允许本地使用符合最低要求的不同版本 |

若不固定 CI 版本，Runner 镜像更新时可能带来不预期的构建变化。

## 4. 常见配置模式

| 项目 | 配置特点 |
| --- | --- |
| [Alamofire](https://github.com/Alamofire/Alamofire/blob/master/.github/workflows/ci.yml) | 显式指定 `DEVELOPER_DIR`，在 matrix 中配置多 Xcode，`destination` 指定 OS 和设备 |
| [Kingfisher](https://github.com/onevcat/Kingfisher/blob/master/.github/workflows/test.yaml) | matrix 中指定 Xcode 版本，`destination` 中包含 OS 版本 |
| [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture/blob/main/.github/workflows/ci.yml) | 通过 `xcode-select` 切换 Xcode 应用路径 |

本仓库目前使用**单一固定环境门禁**；后续如果需要支持多个 Xcode 大版本，再增加 matrix 配置。

## 5. CI 失败问题排查

### A. 工具链与镜像问题

| 现象 | 原因 | 排查与修复 |
| --- | --- | --- |
| `Pinned Xcode not found` | Runner 镜像删除了对应版本的 Xcode | 查看 runner-images 说明，更新 `XCODE_VERSION`、`XCODE_APP` 与 `XCODE_BUILD` |
| `Xcode version/build mismatch` | 相同路径下的 Build 号有更新 | 校验并更新 `XCODE_BUILD` |
| `macos-26` 队列失败或 label 无效 | GitHub 更改了 Runner 命名 | 修改 `runs-on` 并同步更新文档 |

### B. 模拟器问题

| 现象 | 原因 | 排查与修复 |
| --- | --- | --- |
| `Pinned simulator not available` | 镜像移除了对应 OS 或机型 | 查看 runner-images 中的模拟器列表，调整 `IOS_SIM_NAME` / `IOS_SIM_OS` |
| `Unable to find a device matching…` | 未提供 OS 参数，或 OS 与 Xcode 版本不兼容 | 需同时指定 `name` 和 `OS` |
| 测试超时或模拟器启动失败 | 系统冷启动或资源不足 | 重新运行 Workflow，若持续失败需查看日志 artifact |

### C. 依赖与 Package 问题

| 现象 | 原因 | 排查与修复 |
| --- | --- | --- |
| Dependency resolve 失败 | 网络异常、revision 不存在或 `Package.resolved` 冲突 | 确认 revision 存在，在本地运行 `swift package resolve` 后提交 `Package.resolved` |
| Markdown 或 cmark 报编译错误 | 依赖升版后接口发生变更 | 锁定旧 revision，或修改代码适配新接口 |
| 报 `no such module 'UIKit'` | 测试跑在了 macOS 目标上 | 需指定为 iOS Simulator 目标 |

### D. 测试用例问题

| 现象 | 原因 | 排查与修复 |
| --- | --- | --- |
| 性能断言失败（incremental/full ≥ 0.30） | Runner 运行变慢或代码有性能回归 | 排查代码逻辑，确认无回归后重新测算基线 |
| 语义测试失败 | 代码修改导致回归，或依赖版本变更 | 在同大版本的 Xcode 环境中复现调试 |
| 仅在 CI 上测试失败 | 本地与 CI 的 Xcode 版本不同，或本地启用了 Caches path 覆盖 | 参考第 2 节，在对应 Xcode 环境下排查 |
| Mermaid PNG 在 CI 两次超时，日志出现无 `UIApplication` / WebContent unresponsive | 真实 WKWebView 被放进无 App 生命周期的 SwiftPM runner；增加 timeout 不能恢复被冻结的 event loop | 保留 Package 内确定性 addon/bridge 测试；真实 PNG 只放在 `ExampleAppMermaidIntegrationTests`，显式 boot Simulator 后用 ExampleApp scheme 运行 |

### E. 流程与权限

| 现象 | 原因 | 排查与修复 |
| --- | --- | --- |
| Workflow 未触发 | 未提交 Push、Fork PR 权限不足或配置了路径过滤 | 检查 `.github/workflows/ci.yml` 中的触发条件 |
| Artifact 体积过大 | 包含了过多的测试产物 | 仅在失败时上传 artifact（`if: failure()`） |

## 6. 升级 CI 固定版本步骤

1. 查看 runner-images 中 **macos-26** 的 Readme，确认可用 Xcode 路径、Build 号以及 iOS 模拟器版本。
2. 修改 `.github/workflows/ci.yml` 中 `env` 的 `XCODE_*`、`IOS_SIM_*` 与 `DEVELOPER_DIR`。
3. 在本地使用相同 Xcode 版本进行验证：

   ```bash
   sudo xcode-select -s /Applications/Xcode_26.6.app/Contents/Developer  # 切换到对应路径
   xcodebuild test -scheme InkMarkdown-Package \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
   ```

4. 更新本文第 1 节表格与 `docs/current-status.md` 中的 CI 版本说明。
5. 提交 PR，确认 CI 构建通过。

## 7. 本地环境建议

| 层级 | 要求 |
| --- | --- |
| 最低要求 | 能解析 `swift-tools-version: 6.2`，且能在 iOS 模拟器上运行 `xcodebuild test` |
| 推荐要求 | 使用与 CI 同一主版本的 Xcode（目前为 Xcode 26.x） |
| 权威要求 | 使用 CI 固定的 Xcode 26.6 + iPhone 17 Pro / iOS 26.5 模拟器 |

遇到“本地测试通过但 CI 失败”的问题时，优先使用 CI 固定的 Xcode 版本在本地复现测试。

## 8. ExampleAppPolicyTests（SPM testTarget）

`Tests/ExampleAppPolicyTests` 是 **Swift Package 测试 target**，不是 Xcode `ExampleApp.xcodeproj` 内的 test target：

| 项 | 说明 |
| --- | --- |
| 被测代码 | `ExampleAppChatPolicy` **target**（仅 `ChatScrollPolicy.swift`） |
| 公开 product | **无** — `ExampleAppChatPolicy` 不是 SPM library product，避免双根编译 / 发布泄漏 |
| ExampleApp 编译 | `ChatScrollPolicy.swift` 直接编入 ExampleApp app target |
| 运行方式 | `xcodebuild -scheme InkMarkdown-Package -destination 'platform=iOS Simulator,...' test`，或 Xcode 选择 `InkMarkdown-Package` scheme 跑全量测试 |

本地只开 ExampleApp Xcode 工程**不会**自动运行 `ChatScrollPolicyTests`；需在 Package scheme 下执行。

## 9. Mermaid 真实 PNG（app-hosted test target）

`Tests/InkMarkdownMermaidTests` 只承载 fence、cache、limits、bridge resource 等确定性契约。唯一真实 WebKit → PNG 与右缘裁切用例位于 `ExampleApp/ExampleAppMermaidIntegrationTests`，原因是 WKWebView 需要真实 `UIApplication`、window 与 WebContent 生命周期。

```bash
xcrun simctl bootstatus <SIMULATOR_UDID> -b
xcodebuild test \
  -project ExampleApp/ExampleApp.xcodeproj \
  -scheme ExampleApp \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  -only-testing:ExampleAppMermaidIntegrationTests
```

不得用增大 timeout、额外 sleep 或删除宽图用例掩盖 hostless runner 问题。CI 的 app-hosted job 先显式 boot 并等待 Simulator ready，再执行该 target。

## 10. 相关链接

- CI 配置文件：`.github/workflows/ci.yml`  
- 依赖策略：[ADR-001](../decisions/ADR-001-swift-markdown-dependency-pinning.md)  
- 项目当前状态：[current-status.md](../current-status.md)  
- 开发构建命令：[04-development.md](04-development.md)  
