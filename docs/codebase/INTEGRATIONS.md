# 外部集成

## 核心集成点

### 1) 编译期外部依赖库

| 依赖库 | 集成方式 | 授权 / 配置 | 验证依据 |
|-------------|-----------|---------------|----------|
| swift-markdown (`Markdown` Product) | 核心解析引擎 | SPM 远程 **Revision 锁定**（详见 `Package.swift` / `Package.resolved`） | `Package.swift` |
| swift-cmark (传递依赖) | cmark-gfm 解析基础 | 由 swift-markdown 传递引入分支 `gfm` | `Package.resolved` |
| UIKit / Foundation | 系统框架依赖 | 无 | 源码 `import` |

### 2) 宿主集成接口

InkMarkdown 不内置网络请求、身份验证或后端交互逻辑。宿主通过公开 API 进行集成：

| 接口 | 用途 | 验证依据 |
|---------|---------|----------|
| `InkAttributedRenderer.render` | 单次生成富文本字符串 | 公开 API |
| `InkBlockRenderer.render` → `makeView()` | 列表及滚动容器中的块级 View 渲染 | `InkRenderableBlock` |
| `InkStreamRenderer` + `bindTextView` | SSE / AI 对话流式渲染 | `InkStreamRenderer` |
| `InkStreamTableView` | 流式渲染场景下的表格处理 | `Components/InkStreamTableView.swift` |
| `InkConfiguration` 扩展配置 | 包含源码预处理、自定义行内语法扩展、块级路由与链接点击回调 | `InkConfiguration.swift` |
| `InkMarkdownLayoutManager` | 行内代码背景与引用竖线自定义绘制 | `Components/InkMarkdownLayoutManager.swift` |

集成示例见 `ExampleApp`（其中包含 Mock SSE 服务：`Detail/SSE/MockSSEService.swift`）。

### 3) 未引入的服务类型

| 服务类型 | 状态 | 验证依据 |
|----------|--------|----------|
| 数据库 | 未使用 | 无 ORM / SQL 依赖 |
| 身份认证 / OAuth | 未使用 | 无关联代码 |
| 性能监控 / 统计分析 | 未使用 | 无关联代码 |
| 消息队列 | 未使用 | 无关联代码 |
| 远程配置 | 未使用 | 无关联代码 |
| 图片下载 / CDN 缓存 | **未内置**（图片采用占位符处理） | `renderImage` 仅输出 `"[🖼 …]"` |

### 4) 本地工具链集成

| 工具 | 用途 | 验证依据 |
|------|------|----------|
| `Packages/scripts/fetch-packages.sh` | 依据 `packages.json` 克隆依赖至 `Packages/Caches/` | 脚本内容 |
| `packages.json` | 记录第三方依赖的 URL 与 Revision | `Packages/packages.json` |
| XcodeBuildMCP | 构建与测试环境 | `AGENTS.md` |
| codebase-memory | 本地代码库架构辅助查询 | `AGENTS.md` |

### 5) 凭证与安全配置

- 项目无依赖 API Key，无需包含 `.env` 配置文件。
- 网络代理环境变量仅影响本地依赖拉取过程。

### 6) 验证依据

- `Package.swift` / `Package.resolved`
- `Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift`
- `ExampleApp/ExampleApp/Detail/SSE/`
- `Packages/scripts/fetch-packages.sh`
