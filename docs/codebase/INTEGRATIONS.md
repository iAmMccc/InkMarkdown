# Integrations

## Core Sections (Required)

### 1) External Libraries (build-time)

| Integration | Direction | Auth / config | Evidence |
|-------------|-----------|---------------|----------|
| swift-markdown (`Markdown` product) | 库依赖解析器 | SPM remote **revision pin**（见 `Package.swift` / `Package.resolved`） | `Package.swift` |
| swift-cmark (transitive) | GFM cmark 实现 | 经 swift-markdown 拉取 `branch: gfm` | `Package.resolved` |
| UIKit / Foundation | 系统框架 | 无密钥 | 源码 import |

### 2) Host Application Integration Surface

InkMarkdown **不**内置网络、鉴权或后端。宿主通过 public API 集成：

| Surface | Purpose | Evidence |
|---------|---------|----------|
| `InkAttributedRenderer.render` | 一次性富文本 | public API |
| `InkBlockRenderer.render` → `makeView()` | 列表/滚动容器中的块 UI | `InkRenderableBlock` |
| `InkStreamRenderer` + `bindTextView` | SSE / 聊天流式 | `InkStreamRenderer` |
| `InkStreamTableView` | 流式场景表格 | `Components/InkStreamTableView.swift` |
| `InkConfiguration` 自定义扩展点 | 预处理、自定义行内语法扩展、块路由、链接点击回调 | `InkConfiguration.swift` |
| `InkMarkdownLayoutManager` | 行内代码背景 / 引用竖线绘制 | `Components/InkMarkdownLayoutManager.swift` |

示例宿主：`ExampleApp`（含 Mock SSE：`Detail/SSE/MockSSEService.swift`）。

### 3) Services Not Present

| Category | Status | Evidence |
|----------|--------|----------|
| Database | 无 | 无 ORM / SQL 依赖 |
| Auth / OAuth | 无 | 无 |
| Analytics / APM | 无 | 无 |
| Message queue | 无 | 无 |
| Remote config | 无 | 无 |
| Image CDN / download | **不做**；图片仅文本占位 | `renderImage` 输出 `"[🖼 …]"` |

### 4) Local Tooling Integrations

| Tool | Role | Evidence |
|------|------|----------|
| `Packages/scripts/fetch-packages.sh` | 按 `packages.json` clone 到 `Packages/Caches/` | 脚本内容 |
| `packages.json` | 记录依赖 URL / revision | `Packages/packages.json` |
| XcodeBuildMCP | 推荐构建测试入口 | `AGENTS.md` |
| codebase-memory（可选 MCP） | 代码结构查询 | `AGENTS.md`；`.codebase-memory/` 可能存在于本地 |

### 5) Credentials and Secrets

- 无 `.env.example`；库本身不需要 API key。
- 代理仅影响开发者拉取 git 依赖的环境变量。

### 6) Evidence

- `Package.swift` / `Package.resolved`
- `Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift`（`renderImage`）
- `ExampleApp/ExampleApp/Detail/SSE/`
- `Packages/scripts/fetch-packages.sh`
