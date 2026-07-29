# 架构设计

## 核心架构

### 1) 架构风格与模式

- **分层渲染管线**：解析（parse） → 样式配置（style config） → 双通道渲染（dual-channel render），配合策略扩展点（block handlers / inline syntax）。
- **分层逻辑**：
  - 解析与渲染解耦：解析由 `swift-markdown` 处理（`InkParser` 作为轻量包装）。
  - 渲染通道分离：根据元素能否构建为 `NSAttributedString`，划分为富文本通道与 `UIView` 块级通道。
  - 流式增量渲染：作为双通道上的控制编排机制（解析缓冲与显示缓冲），不新增第三套语义后端。
- **架构约束**：
  - **纯 UIKit 架构**：不提供 SwiftUI 渲染器。
  - **固定行高机制**：固定行高结合 baseline 居中对齐，保证混排字体排版一致。
  - **v1 阶段直接渲染**：直接由 `Markup` 渲染，无独立 IR 中端（`InkIR` 规划于 v2）。

### 2) 系统数据流

```text
Markdown 源码
  → sourceFilter (可选预处理)
  → InkParser.parse → Document / Markup 语法树 (swift-markdown)
  → 路径 A: InkAttributedRenderer (+ InkTextContext) → NSAttributedString
  → 路径 B: InkBlockRenderer + blockHandlers → [InkRenderableBlock] → UIView
  → 路径 C: InkStreamRenderer (append/finish) → 后台解析队列
             → preloadContent → CADisplayLink 刷新 → UITextView.textStorage
```

**执行流程说明：**

1. **配置组装**：`InkConfiguration` 聚合 `appearance`、`inlineSyntaxes`、`blockHandlers`、`sourceFilter` 与 `linkTapHandler`（`Configuration/InkConfiguration.swift`）。
2. **文本解析**：`InkParser.parse` 转换为 `Document(parsing:)`（`Parser/InkParser.swift`）。
3. **富文本渲染**：`InkAttributedRenderer` 递归遍历 `Markup` 语法树。样式通过 `InkTextContext` 向下传递，叶子节点直接生成属性区块，后处理统一应用 `paragraphStyle` 与 `baselineOffset`。
4. **块级路由**：`InkBlockRenderer` 遍历文档子节点；命中自定义 Handler 时冲刷待渲染 Markup 为富文本块，并追加自定义 `UIView` 块（`Block/InkBlockRenderer.swift`）。
5. **流式渲染**：`append` 积累缓存（硬上限 50,000 字符）；后台 `InkIncrementalMarkdownRenderer` 执行增量解析；主线程使用 `CADisplayLink` 逐帧更新视图（`InkStreamRenderer.swift`）。

### 3) 模块职责界定

| 模块 | 职责范围 | 排除职责 | 验证依据 |
|-----------------|------|--------------|----------|
| Parser | Markup 语法树构建与行分类 | 样式计算与 UIKit 布局 | `Parser/` |
| Configuration | 外观默认值及渲染可扩展项 | 解析语义与网络资源加载 | `Configuration/` |
| AttributedString render | 固定行高计算及富文本映射 | 表格网格绘制；图片下载由 opt-in 子系统承担（`Rendering/Image/`） | `InkAttributedRenderer.swift` |
| Block routing | 路由特定 Markup 至 UIView 块 | 重写解析规则 | `Block/*` |
| Components | 代码块、表格与分割线视图组件 | 业务逻辑与导航控制 | `Components/` |
| Stream | 增量边界划分、双缓冲与主线程同步 | 数据持久化与网络请求 | `InkStreamRenderer.swift` |
| ExampleApp | 功能演示与交互验证 | 库核心语义实现 | `ExampleApp/` |

### 4) 复用设计模式

| 模式 | 应用位置 | 作用 |
|---------|-------------|---------------|
| 外观模式 (Facade) | `InkParser` | 提供统一解析入口 |
| 策略模式 (Strategy) | `InkBlockHandler` 及默认块（代码/表格/分割线） | 支持宿主扩展块级视图类型 |
| 上下文下传 (Context Object) | `InkTextContext` | 解决覆盖二次遍历导致的样式覆盖问题 |
| 双缓冲 (Dual-buffer) | 解析队列 + CADisplayLink 显示 | 解耦解析计算与渲染刷新 |
| SPI 隔离 | `@_spi(Performance) InkStreamingPerformanceBenchmark` | 隔离性能基准测试与公共 API |
| 重新导出 | `@_exported import Markdown` | 避免宿主二次依赖 Markup 模块 |

### 5) 潜在架构风险

- **平台声明与范围**：底层与 Manifest 绑定 UIKit/iOS。
- **依赖更新机制**：已锁定 Revision（ADR-001），升级需同步验证 CI 与测试集。
- **核心文件体量**：`InkStreamRenderer`（约 632 行）与 `InkAttributedRenderer`（约 583 行）属于核心维护点。
- **流式长度限制**：`maxParseLength = 50_000`，超限停止解析或截断处理。
- **v1 中端缺失**：复杂语义变换需借由 Renderer 或 `sourceFilter` 处理（中端架构规划于 v2）。

### 6) 验证依据

- `Sources/InkMarkdown/InkMarkdown.swift`
- `Sources/InkMarkdown/Configuration/InkConfiguration.swift`
- `Sources/InkMarkdown/Rendering/AttributedString/InkAttributedRenderer.swift`
- `Sources/InkMarkdown/Rendering/Block/InkBlockRenderer.swift`
- `Sources/InkMarkdown/Rendering/InkStreamRenderer.swift`
- `docs/contributor-guide/02-architecture.md`
