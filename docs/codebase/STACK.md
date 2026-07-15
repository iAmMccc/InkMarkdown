# Technology Stack

## Core Sections (Required)

### 1) Runtime Summary

| Area | Value | Evidence |
|------|-------|----------|
| Primary language | Swift（包内 language mode **v5**） | `Package.swift`：`swiftSettings: [.swiftLanguageMode(.v5)]` |
| Tools version | Swift tools **6.2+** | `Package.swift` 首行 `// swift-tools-version: 6.2` |
| Package manager | Swift Package Manager (SPM) | `Package.swift`、`Package.resolved` |
| Module/build system | SPM library target `InkMarkdown` + Xcode ExampleApp | `Package.swift`；`ExampleApp/ExampleApp.xcodeproj` |
| Declared platform (manifest) | **iOS 14+ only** | `Package.swift`：`platforms: [.iOS(.v14)]` |
| Stated product scope | UIKit-only Markdown → `NSAttributedString` / block `UIView` | `AGENTS.md`、`README.md`、`docs/current-status.md` |

### 2) Production Frameworks and Dependencies

| Dependency | Version / pin | Role in system | Evidence |
|------------|---------------|----------------|----------|
| UIKit | 系统框架（iOS） | 富文本、视图块、TextKit 1 布局 | 库源码普遍 `import UIKit` |
| Foundation | 系统框架 | 解析辅助、正则等 | e.g. `Parser/InkLineClassifier.swift` |
| `Markdown`（swift-markdown） | **固定 revision** `07ebc9c071b22a5d021031b798c3a84b76281213`（ADR-001） | 解析 Markdown → `Document` / `Markup` | `Package.swift` dependencies；`Package.resolved` |
| `swift-cmark` | 经 swift-markdown 传递；upstream 声明 branch `gfm`，resolved revision `0101bf2c6ff6a218f93150f340fe5ccf76d9f3aa` | cmark-gfm 底层 | `Package.resolved` |
| SmartCodable | **未使用** | 早期规划提及 | `docs/current-status.md`：manifest 与源码均未引用 |

`InkMarkdown.swift` 使用 `@_exported import Markdown`，宿主 `import InkMarkdown` 时可直接使用 Markup 类型。

### 3) Development Toolchain

| Tool | Purpose | Evidence |
|------|---------|----------|
| Xcode / `xcodebuild` | iOS Simulator 构建与测试（UIKit 不可在 macOS host `swift test`） | `docs/current-status.md`；`AGENTS.md` |
| XcodeBuildMCP（偏好） | 发现 scheme / destination、构建、测试 | `AGENTS.md` 工具规则 |
| Swift Testing | 单元 / 契约 / 性能闸门 | `Tests/**/*.swift`：`import Testing`、`@Test`、`@Suite` |
| 本地 SPM 缓存脚本 | 可选：clone 依赖到 `Packages/Caches/` | `Packages/scripts/fetch-packages.sh`、`Packages/packages.json` |
| Linter / formatter 配置 | **未发现** 根级 SwiftLint / SwiftFormat 配置 | scan：`No linting or formatting config files found` |
| CI/CD | GitHub Actions：钉死 Xcode 26.6 + iPhone 17 Pro / iOS 26.5 | `.github/workflows/ci.yml`；排坑见 `docs/contributor-guide/07-ci-and-toolchain-pitfalls.md` |

### 4) Key Commands

```bash
# 可选：准备本地依赖缓存（离线开发，非默认 manifest）
./Packages/scripts/fetch-packages.sh

# 构建（iOS Simulator；名称/OS 以本机可用 destination 为准）
xcodebuild -scheme InkMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  build

# 测试（同上；勿用 macOS host 上的 `swift test` 判定 UIKit 失败）
xcodebuild -scheme InkMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  test

# 示例 App
open ExampleApp/ExampleApp.xcodeproj

# 清理
swift package clean
rm -rf .build
```

优先使用 XcodeBuildMCP 完成发现与测试；仅在 MCP 不可用时回退到上述命令（见 `AGENTS.md`）。

### 5) Environment and Config

- Config sources: `Package.swift`、`Package.resolved`、`Packages/packages.json`、`ExampleApp` 工程设置
- Required env vars: **无** 应用级 `.env`；脚本可继承 shell 代理（`http_proxy` / `https_proxy`）用于 git clone
- Deployment/runtime constraints:
  - 库直接依赖 UIKit → **必须** iOS（或未来带 UIKit 的平台）目标
  - 当前对外可验证平台仅为 manifest 中的 iOS 14+
  - 直接依赖已 pin revision；传递依赖 `swift-cmark` 仍按上游 `gfm` 分支解析并由 `Package.resolved` 锁定

### 6) Evidence

- `Package.swift`
- `Package.resolved`
- `docs/current-status.md`
- `Packages/scripts/fetch-packages.sh`
- `docs/codebase/.codebase-scan.txt`（STACK DETECTION / CI 段）

## Intent vs Reality

| Topic | Documented intent | Repository reality |
|-------|-------------------|--------------------|
| Multi-platform | iOS 14+、macOS 11+、tvOS 14+、watchOS 7+（`AGENTS.md` 目标） | Manifest 仅 iOS 14+；源码 `import UIKit`；v1 对外仅 iOS（ADR-002） |
| Local SPM cache | 开发可用 `path: Packages/Caches/...`（可选） | 默认 manifest 为远程 **revision pin**；缓存脚本与 `Packages/Caches/` 仍可选 |
| SmartCodable | 早期依赖列表 | 未引入 |

## Extended Notes

- Scan 报告 “Total files 2741 / LOC 116025” **包含** `.build/` 与 `Packages/Caches/` 依赖源码；**本库自身** `Sources/InkMarkdown` 约 **21 个 Swift 文件、~3.0k LOC**（`wc -l` 汇总）。
