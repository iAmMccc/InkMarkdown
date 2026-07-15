# CI 与工具链排坑

本文说明：**CI 钉死了什么**、**和本机 Xcode 的关系**、**常见失败原因**，以及开源协作时多版本 Xcode 的影响。

权威实现：`.github/workflows/ci.yml` 顶部的 `env:` 块。  
镜像对照：[actions/runner-images macos-26-arm64-Readme](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)。

## 1. 当前钉死的 CI 工具链

| 维度 | 钉死值（以 workflow `env` 为准） | 作用 |
| --- | --- | --- |
| Runner | `macos-26` | 固定托管镜像代际 |
| Xcode | `26.6` → `/Applications/Xcode_26.6.app` | 固定编译器 / SDK |
| Xcode Build | `17F113` | 防止同路径被镜像原地替换而不察觉 |
| 模拟器 | `iPhone 17 Pro` + **OS=`26.5`** | 固定 runtime，避免只写 name 跨 OS 漂移 |
| 依赖 | `Package.swift` revision + `Package.resolved` | 固定 swift-markdown 等 |

CI **不会**使用：

- 贡献者本机的 Xcode / `xcode-select`
- 本机 `DerivedData`、`.build`、`Packages/Caches`
- 本机已装的模拟器列表

包契约仍须满足：`swift-tools-version: 6.2`、UIKit、`iOS 14+` 声明。本机与 CI 都要能处理该契约，但**合并门禁只认 CI 钉死环境**。

## 2. 本地 Xcode 和 CI 不一致会怎样？

| 场景 | 结果 | 建议 |
| --- | --- | --- |
| 本机 = CI（如都是 26.6） | 行为最接近 | 日常开发首选 |
| 本机更新（如 27.x），CI 仍 26.6 | 本地能编、CI 红：可能用了新 API / 新 Swift 诊断；或本地绿、CI 红：新工具链更严 | **以 CI 为准修**；新 API 需降级或抬高 CI 并更新文档 |
| 本机更旧（如 16.x） | 可能无法解析 tools 6.2 或缺少 SDK | 升级到 ≥ 文档最低要求；不必等于 CI 补丁号 |
| 本机用 `Packages/Caches` path 覆盖 | 仅本机；CI 仍走 resolved 远程 pin | 不要把 path 默认提交进 manifest |

**开源协作的核心约定：**

1. **CI 绿灯 = 可合并的权威信号**（知名库普遍如此）。  
2. 贡献者可用更新的 Xcode 开发，但 PR 必须在钉死 CI 上通过。  
3. 不要用「我本机 27 过了」否定 CI 红；应对照钉死版本复现。  
4. 抬高 CI Xcode 是**显式变更**（改 `env` + 文档 + 必要时兼容说明），不是默默跟着本机走。

## 3. 对多贡献者的坏影响（若不钉死 / 若误解本机）

| 坏影响 | 原因 | 本仓库对策 |
| --- | --- | --- |
| 「我这能过、CI 不过」拉锯 | 本机工具链当真相 | 钉死 CI + 本文约定 |
| 新 API 悄悄进主分支 | 维护者本机过新 | CI 钉旧一档；本地过新时编译期/CI 会拦 |
| 间歇性红（flaky green→red） | CI 选「最新 Xcode」或只写模拟器名 | 固定 app 路径 + Build 号 + `OS=` |
| 贡献门槛过高 | 要求每人 Xcode 补丁号完全一致 | **不要求**；只要求能开发 + PR 过 CI |
| 矩阵爆炸拖慢 PR | 一次测 10 个 Xcode（大型库才常做） | v1 单门禁；成熟后再加 matrix |

**不钉死**时：GitHub 镜像默认 Xcode 一变，全仓库无声换编译器。  
**过度要求本机 = CI** 时：劝退只装了 27 或只装了 16 的贡献者。平衡点是：**本机宽松、CI 严格且固定**。

## 4. 业界常见做法（参考）

| 项目 | 做法摘要 |
| --- | --- |
| [Alamofire](https://github.com/Alamofire/Alamofire/blob/master/.github/workflows/ci.yml) | `DEVELOPER_DIR=/Applications/Xcode_*.app/...`；matrix 多 Xcode；destination 写 `OS=…,name=iPhone …` |
| [Kingfisher](https://github.com/onevcat/Kingfisher/blob/master/.github/workflows/test.yaml) | matrix 钉 `xcode: '26.2'/'26.5'` + `destination` 含 `OS=26.x` |
| [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture/blob/main/.github/workflows/ci.yml) | `xcode-select` 到 `/Applications/Xcode_${{ matrix.xcode }}.app`，如 `16.4` |

共同模式：

1. **路径钉死**，不 “pick newest”。  
2. **模拟器带 OS**。  
3. 大型库用 **matrix** 扩兼容面；小库/早期先 **单权威门禁**。  
4. 文档写清最低开发工具链与 CI 权威版本可以不同。

本仓库 v1 采用 **单门禁钉死**（成本低、信号清晰）；若日后要兼容多 Xcode 代际，再仿 Alamofire 加 matrix，而不是放宽「选最新」。

## 5. 可能导致 CI 失败的点

### A. 工具链 / 镜像

| 症状 | 可能原因 | 处理 |
| --- | --- | --- |
| `Pinned Xcode not found` | runner-images 移除了 `Xcode_26.6.app` | 查 Readme Xcode 表，改 `XCODE_VERSION` / `XCODE_APP` / `XCODE_BUILD` |
| `Xcode version/build mismatch` | 同路径下 Build 号被镜像更新 | 确认后更新 `XCODE_BUILD`（或改钉另一路径） |
| `macos-26` 队列失败 / label 不可用 | GitHub 调整 runner | 改 `runs-on`，并同步改文档 |

### B. 模拟器

| 症状 | 可能原因 | 处理 |
| --- | --- | --- |
| `Pinned simulator not available` | 镜像去掉某 OS 或改机型名 | 按 Readme「Installed Simulators」改 `IOS_SIM_NAME` / `IOS_SIM_OS` |
| `Unable to find a device matching…` | 只写了 name 或 OS 与 Xcode 不匹配 | 必须 `name` + `OS` 且属于该 Xcode 自带 runtime |
| 测试超时 / 模拟器启动失败 | 冷启动、资源争用 | 重跑 workflow；仍失败再查日志 artifact |

### C. 依赖 / 包

| 症状 | 可能原因 | 处理 |
| --- | --- | --- |
| resolve 失败 | 网络、revision 不可达、`Package.resolved` 冲突 | 确认 revision 仍存在；本地 `swift package resolve` 后提交 resolved |
| 编译错误在 Markdown / cmark | pin 升级后上游 API 变 | 固定旧 revision 或适配代码 + 测试 |
| `no such module 'UIKit'` | 误在 macOS destination 上测 | 本库必须 iOS Simulator（workflow 已强制） |

### D. 测试本身

| 症状 | 可能原因 | 处理 |
| --- | --- | --- |
| 性能闸门失败（incremental/full ≥ 0.30） | runner 更慢或增量路径回归 | 先查是否逻辑回归；再考虑分桶 baseline（roadmap） |
| 32 测中个别语义失败 | 代码回归或依赖 pin 变更 | 本地用**同一 Xcode 大版本**复现 |
| 仅 PR 失败、本地全绿 | 本机 Xcode 更新 / 用了 Caches path | 对照本节 §2；用 CI 日志为准 |

### E. 流程 / 权限

| 症状 | 可能原因 | 处理 |
| --- | --- | --- |
| 没有 Actions 运行 | 未 push；fork PR 权限；workflow 路径过滤 | 确认 `.github/workflows/ci.yml` 已进默认分支策略 |
| artifact 太大 | xcresult 体积 | 仅 `if: failure()` 上传（已如此） |

## 6. 如何升级钉死的 CI 版本

1. 打开 runner-images **macos-26** Readme，确认目标 Xcode 路径、Build、自带 iOS Simulator 表。  
2. 改 `.github/workflows/ci.yml` 的 `env`：`XCODE_*`、`IOS_SIM_*`、`DEVELOPER_DIR`。  
3. 本机安装同代 Xcode，跑：

   ```bash
   sudo xcode-select -s /Applications/Xcode_26.6.app/Contents/Developer  # 换成新路径
   xcodebuild test -scheme InkMarkdown \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
   ```

4. 更新本文 §1 表格与 `docs/current-status.md` 中 CI 一行。  
5. 合并后看 Actions 是否仍 `version/build` 校验通过。

## 7. 本地推荐（非强制等于 CI）

| 级别 | 要求 |
| --- | --- |
| 最低 | 能处理 `swift-tools-version: 6.2`，能在 **iOS Simulator** 上 `xcodebuild test` |
| 推荐 | 与 CI 同主版本线（当前 **Xcode 26.x**） |
| 权威 | **CI 钉死的 26.6 + iPhone 17 Pro / iOS 26.5** |

调试「CI 红本地绿」时，优先切换到与 CI 相同的 Xcode 应用再测一遍。

## 8. 相关链接

- Workflow：`.github/workflows/ci.yml`  
- 依赖策略：[ADR-001](../decisions/ADR-001-swift-markdown-dependency-pinning.md)  
- 当前状态：[current-status.md](../current-status.md)  
- 开发命令：[04-development.md](04-development.md)  
