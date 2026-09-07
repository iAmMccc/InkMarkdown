# 27：联合集成与交付证据

- 日期：2026-09-07
- Branch / HEAD：`feat/swiftUI` / `f71cc292a5708cf910f0e9a36ce73c7dedd7bd89`
- 锁定：`evidence/20260907-1415-ticket-27/lock-final.txt`
- 用户本轮明确排除：远程 CI、ExampleApp 手工交互、iOS 15 runtime

## 验证矩阵

| 门禁 | 结果 | 证据 |
| --- | --- | --- |
| Package 全量测试 | **288 passed / 0 failed / 0 skipped** | scheme `InkMarkdown-Package`；destination `iPhone 17 Pro` / `id=10F638E2-84FB-42AE-9BAE-0E246F463E8D`；log `…/package-tests-rerun.log`；xcresult `…/package-tests-rerun.xcresult` |
| 四 product consumer build | **4/4 BUILD SUCCEEDED** | Core / SwiftUI / LaTeX / Mermaid；`…/consumer/*.log`；`EXIT_*:0` |
| ExampleApp Debug/Release 构建 | **2/2 BUILD SUCCEEDED** | `…/exampleapp/Debug.log`、`Release.log`；临时 XCLocal overlay（Caches），构建后已恢复 remote `project.pbxproj` |
| ExampleApp 安装/启动/交互 | **未验证**（用户排除） | — |
| 远程 CI | **未执行**（用户排除；未 push） | — |
| iOS 15 runtime | **未验证**（用户排除） | deployment target 仍为 15.0 |

## 终检前修复（同候选）

首轮全量出现 2 红，已在同最终工作树修复并重跑：

1. `applyImage_preservesExistingParagraphGeometry`：`waitForImageLoads` 改为 `InkAsyncTestProbe` 抽干 MainActor，覆盖 PresentationLoad 延迟交付。
2. `bypassStoreTrue_loadsViaLoaderWithoutStoreCache`：用 `InkAsyncTestProbe.wait` 等待 `loadCount >= 1`，避免固定 requestID=1 竞态。

修复后：相关 suite 通过；全量 **288** 再跑通过。

## 依赖与契约

- 验证期使用 `Packages/Caches` path overlay；结束后 **`Package.swift` 已恢复 remote pin**（swift-markdown revision + iosMath exact）。本地 overlay 成功 ≠ 远程可解析。
- ExampleApp 因 GitHub checkout 损坏/不可达，构建期临时改用 `Packages/Caches/{JXSegmentedView,JXPagingView,SnapKit,SmartCodable}` local package；**`project.pbxproj` 已恢复 remote**。
- products 仍为 InkMarkdown / InkMarkdownSwiftUI / InkMarkdownLaTeX / InkMarkdownMermaid；deployment `.iOS(.v15)`；无 SwiftUI→UIKit product 反向 import。
- 过渡保留：Session `bindTextView` / `installPresentationDisplayUpdateObserver` 兼容转发（见 `contract-surface.txt`）。

## G-* / 方向出口映射

| ID | 结论 | 责任票 / 证据 |
| --- | --- | --- |
| G-01 | 通过（契约对照） | 01 + 本票 `contract-surface.txt` / `products.txt` |
| G-02 | 通过（无删 public/SPI 声明；过渡转发仍在） | 本票 + 方向票 |
| G-03 | 通过（manifest iOS 15；runtime 15 未测） | Package.swift；未验证项见上 |
| G-04–G-06 | 通过（方向验收） | 09 / 17 / 26 |
| G-07 | 遵守（无 commit/push/PR） | 本票 |
| G-08 | 通过（本文件记录命令与数量） | 本票 |
| G-09 | 通过（生产路径迁移完成；兼容转发待后续清理） | 08/16/25 + 本票 |
| G-10 | 遵守（不声称发布/性能/远程 CI） | 本票 |
| T-12 | 通过（契约）；手工未验 | 09 |
| I-12 | 通过（契约）；手工未验 | 17 |
| S-14 | 通过（契约）；手工未验 | 26 |

## 交付清单（生产路径，未 commit）

- 表格：`InkTablePresentation` + Block/Stream 迁入 Presentation
- 图片：`InkImagePresentationLoad` / Async；Block / Attachment / Preview 委托
- 宿主：`InkStreamingPresentationHost`；Coordinator 委托；Session binding grant + 兼容转发
- 测试等待加固：`ImageRenderingTests.waitForImageLoads`、`InkImagePreviewLoadTests`

## 未验证 / 后续

- 远程 CI（需授权 push/PR）
- ExampleApp 手工交互（表格 / 图片 / Thought / promotion）
- iOS 15（及可选 18.5）runtime 矩阵
- 删除 Session 旧 `bindTextView` 兼容转发（另票）
- `Package.resolved` 工作树删除态：恢复 pin 后未重新 resolve；远程解析仍待网络可用时核对
