# 技术栈

## 核心配置

### 1) 运行时摘要

| 维度 | 配置/状态 | 验证依据 |
|------|-------|----------|
| 主要语言 | Swift（包内语言模式 **v5**） | `Package.swift`：`swiftSettings: [.swiftLanguageMode(.v5)]` |
| 工具链版本 | Swift tools **6.2+** | `Package.swift` 首行 `// swift-tools-version: 6.2` |
| 包管理器 | Swift Package Manager (SPM) | `Package.swift`、`Package.resolved` |
| 模块与构建系统 | SPM library target `InkMarkdown` + Xcode ExampleApp | `Package.swift`；`ExampleApp/ExampleApp.xcodeproj` |
| 声明平台 | **仅 iOS 14+** | `Package.swift`：`platforms: [.iOS(.v14)]` |
| 产品定位 | 纯 UIKit Markdown 渲染 → `NSAttributedString` / 块级 `UIView` | `AGENTS.md`、`README.md`、`docs/current-status.md` |

### 2) 依赖项

| 依赖库 | 版本 / Revision 锁定 | 职责 | 验证依据 |
|------------|---------------|----------------|----------|
| UIKit | 系统框架（iOS） | 富文本、视图块、TextKit 1 布局 | 库源码统一 `import UIKit` |
| Foundation | 系统框架 | 解析辅助、正则匹配 | `Parser/InkLineClassifier.swift` 等 |
| `Markdown`（swift-markdown） | **锁定 revision** `07ebc9c071b22a5d021031b798c3a84b76281213`（ADR-001） | 解析 Markdown → `Document` / `Markup` | `Package.swift` 依赖段；`Package.resolved` |
| `swift-cmark` | 由 swift-markdown 传递；上游声明分支 `gfm`，resolved revision `0101bf2c6ff6a218f93150f340fe5ccf76d9f3aa` | cmark-gfm 底层解析 | `Package.resolved` |
| SmartCodable | **未使用** | 早期规划提及，无实际代码依赖 | `docs/current-status.md` |

`InkMarkdown.swift` 声明 `@_exported import Markdown`，宿主引入 `import InkMarkdown` 后可直接使用 Markup 类型。

### 3) 开发工具链

| 工具 | 用途 | 验证依据 |
|------|---------|----------|
| Xcode / `xcodebuild` | iOS Simulator 构建与测试（macOS host 执行 `swift test` 会缺少 UIKit） | `docs/current-status.md`；`AGENTS.md` |
| XcodeBuildMCP | Scheme / Destination 发现、构建与测试 | `AGENTS.md` 工具规则 |
| Swift Testing | 单元测试、契约测试与性能断言 | `Tests/**/*.swift`：`import Testing`、`@Test`、`@Suite` |
| 本地 SPM 缓存脚本 | 可选：克隆依赖至 `Packages/Caches/` | `Packages/scripts/fetch-packages.sh`、`Packages/packages.json` |
| 代码检查 / 格式化 | 无根目录 SwiftLint / SwiftFormat 配置文件 | 项目扫描结果 |
| CI/CD | GitHub Actions：固定 Xcode 26.6 + iPhone 17 Pro / iOS 26.5 | `.github/workflows/ci.yml`；详见 `docs/contributor-guide/07-ci-and-toolchain-pitfalls.md` |

### 4) 构建命令

```bash
# 准备本地依赖缓存（可选，离线开发）
./Packages/scripts/fetch-packages.sh

# 构建（iOS Simulator）
xcodebuild -scheme InkMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  build

# 测试
xcodebuild -scheme InkMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  test

# 打开示例工程
open ExampleApp/ExampleApp.xcodeproj

# 清理构建产物
swift package clean
rm -rf .build
```

优先使用 XcodeBuildMCP 执行构建与测试；MCP 不可用时回退至命令行（详见 `AGENTS.md`）。

### 5) 环境与配置

- **配置来源**：`Package.swift`、`Package.resolved`、`Packages/packages.json`、`ExampleApp` 工程配置
- **环境变量**：无需应用级 `.env`；可继承 Git 代理环境变量（`http_proxy` / `https_proxy`）
- **部署与运行约束**：
  - 依赖 UIKit，仅支持 iOS Target
  - 外部库声明仅支持 iOS 14+
  - 直接依赖项已锁定 revision；传递依赖项 `swift-cmark` 遵循 `Package.resolved` 锁定的 revision

### 6) 验证依据

- `Package.swift`
- `Package.resolved`
- `docs/current-status.md`
- `Packages/scripts/fetch-packages.sh`
- `docs/codebase/.codebase-scan.txt`

## 目标与现状对比

| 主题 | 规划目标 | 仓库现状 |
|-------|-------------------|--------------------|
| 多平台支持 | iOS 14+、macOS 11+、tvOS 14+、watchOS 7+（`AGENTS.md` 路线） | Manifest 仅声明 iOS 14+；源码依赖 UIKit；v1 对外仅支持 iOS（ADR-002） |
| 本地 SPM 缓存 | 支持 `path: Packages/Caches/...` | 默认 Manifest 锁定远程 Revision；缓存脚本可选 |
| SmartCodable | 早期依赖列表项 | 未引用 |

## 补充说明

- 扫描报告中的 “Total files 2741 / LOC 116025” 包含 `.build/` 及 `Packages/Caches/` 中的第三方依赖代码。
- 本库实际代码库 `Sources/InkMarkdown` 包含 **21 个 Swift 文件，约 3,000 行代码**。
