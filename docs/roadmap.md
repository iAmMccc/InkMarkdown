# 发展方向与路线

产品范围以根目录 `AGENTS.md` / `CLAUDE.md` 为准；已交付状态以 [current-status.md](current-status.md)、`Package.swift`、源码和测试为准。

本文记录目标形态、技术路线与版本规划。

分类定义：

- **承诺**：具备明确退出标准。
- **试探**：通过 PoC 验证，未达预期则移入「不做」。
- **本阶段不做**：明确排除的功能范围。

## 1. 目标形态

基于 swift-markdown 的 Apple 原生 Markdown 渲染库：

- **当前**：UIKit。富文本使用 `UITextView` 与列表；表格、代码块等采用 `UIView`；具备流式渲染验证测试。
- **v2**：解析结果生成中间模型 **InkIR**，支持挂载可选 Transformer。
- **后续**：持续完善 UIKit 渲染、扩展语义与平台验证，不增加 SwiftUI 后端。

### 适用场景

| 优先级 | 场景 | 核心需求 |
| --- | --- | --- |
| 高 | UIKit / 混合界面（IM、资讯、AI 对话） | 嵌套至现有气泡与 Cell，解耦 SwiftUI |
| 高 | 流式 Markdown 渲染 | 避免性能衰减与样式跳变，提供可测增量结果 |
| 中 | 业务语法扩展 | 支持 `@提及`、自定义代码块卡片、链接过滤 |
| 中 | 大型 UIKit 宿主应用 | 统一语义规范、可组合扩展能力、可控性能 |

### 核心特征

1. **UIKit 整合**：基于 `NSAttributedString` 与块级 `UIView`，使用固定行高，非 WebView 架构。
2. **流式渲染机制**：使用稳定前缀 / 活跃后缀与双缓冲结构，配置增量与全量测试基准。
3. **分层扩展能力**
   - 轻量层（已有）：`sourceFilter`、`InkInlineSyntax`、`InkBlockHandler`、`linkTapHandler`
   - 进阶层（v2）：InkIR + Transformer（用于复杂规则与多级语义转换）

### 目标管线

```text
Markdown
  → sourceFilter? 
  → swift-markdown Document
  → Lowering → InkIR
  → Transformer 链（可空）
  → UIKit 后端（富文本 + 块 + 流式）
```

| 阶段 | 接口形态 |
| --- | --- |
| v1 | 支持直接通过 Markup 渲染，无需公开 IR |
| v2 | IR 作为中端，UIKit 渲染基于 IR |

### 功能边界

| 包含 | 不包含 |
| --- | --- |
| CommonMark + 实用 GFM | 完整 HTML 浏览器、编辑器、独立高亮引擎 |
| UIKit 渲染 + 流式支持 | WebView 渲染主路径 |
| 基础扩展点（v2 引入 IR/Transformer） | 将 TED 作为默认流式引擎 |
| UIKit 渲染 + 可组合扩展 | SwiftUI 渲染器及 Theme 主题生态 |
| **TextKit 1** 库内绘制默认 | 仅依赖 TextKit 2 或长文编辑器架构 |
| 补全图片与删除线契约 | 强制渲染所有解析节点 |

### 文本引擎选型：TextKit 1 为默认，TextKit 2 保持试探

| 维度 | TextKit 1 | TextKit 2 |
| --- | --- | --- |
| 定位 | UIKit 原生文本排版引擎 | 新一代排版引擎（非 UI 框架） |
| 库内状态 | 使用中：`InkMarkdownLayoutManager` 绘制代码背景与引用竖线 | 未使用 |
| 场景契合 | 满足对话气泡与中短文需求 | 无需作为默认引擎 |
| 极端长文 | 性能上限受限 | 理论更适合超长文本（属于不同产品定位） |

**v1–v2 默认路径为 TextKit 1。**

库内 text view 与 block 使用 TextKit 1。宿主仅将 `NSAttributedString` 传入自带 `UITextView` 时可显示基础属性；若需圆角代码背景等自定义绘制，需使用库提供的 text view / block。

TextKit 2 仅作为远期试探（验证 Fragment 机制是否满足自定义绘制及长文收益）；若不可行将移入「不做」。

### 版本划分

| 版本 | 定义 |
| --- | --- |
| **v1.0** | 可靠的 UIKit 渲染库：包含契约测试、CI、规范 API 与完整文档；**不强制公开 IR** |
| **v2.0** | 引入 InkIR + Transformer + 扩展决策树 + 删除线/图片策略；渲染依赖 IR |
| **v2.x** | 补全图片与删除线语义，完善可访问性与性能 |
| **v3+** | 多平台兼容落地；TextKit 2 试探；TED 机制研究 |

## 2. 路线规划

已交付能力、限制与配置项保持在 [current-status.md](current-status.md) 维护。

```text
v1 发布  →  v2 InkIR + Transformer  →  UIKit 能力补全  →  TK2 / 平台验证 / TED 试探
```

依赖关系：缺乏 v1 快照护栏时不引入 IR；缺乏稳定 IR 时不扩展复杂语义转换。

### Phase A → v1.0.0（承诺）

| ID | 事项 | 退出标准 |
| --- | --- | --- |
| A1 | 建立知识基线 | README、当前状态、roadmap 与贡献者指南内容一致 |
| A2 | 快照测试补全 | CommonMark 与支持的 GFM 元素均包含语义断言 |
| A3 | 公开 API 审计 | 内部符号标记 `internal`/`@_spi`，公开 API 补充中文注释 |
| A4 | CI 建设 | PR 需通过 iOS Simulator 测试 |
| A5 | 发布 준비 | 补充 CHANGELOG，明确 API 与限制（图片/删除线/iOS/TK1） |
| A6 | ExampleApp 补全 | 提供富文本、块、流式及自定义 handler 示例 |

**v1 阶段不包含：** 公开 InkIR、Transformer、TextKit 2、TED、多平台正式支持、Theme 协议。SwiftUI 不在此路线中。

### Phase B → v2.0.0（架构跃迁）

| ID | 事项 | 退出标准 |
| --- | --- | --- |
| B1 | 基础 `InkBlock` / `InkInline` | 覆盖现有渲染节点，采用值类型 |
| B2 | Markup → InkIR Lowering | 实现 1:1 转换并提供单测 |
| B3 | 基于 IR 的 UIKit 渲染 | 与 v1 快照测试保持零回归 |
| B4 | `InkTransformer` 配置挂载 | 空配置保持原有渲染行为 |
| B5 | 示例扩充 | 提供 Mention 与自定义 Fence/LaTeX 示例 |
| B6 | 扩展决策指南 | 明确 sourceFilter / Transformer / InlineSyntax / BlockHandler 的适用场景 |
| B7 | 补全删除线与图片策略 | 提供契约文档与示例代码 |
| B8 | 流式接入 IR | 通过流式一致性测试 |
| B9 | `InkTextContext` 样式容器化 | 实现样式收集容器化重构 |

**B9 说明**：v1 的上下文下传范式要求每个叶子节点显式读取样式标志，漏掉节点会导致样式丢失。MarkdownUI 与 Apple Foundation 采用 `TextStyle` 协议 + `_collectAttributes(inout:)` 将离散标志收敛为可收集容器，叶子节点直接应用已收集容器。

**B9 退出标准**：`InkTextContext` 的离散标志替换为可合并样式容器；新增样式只需实现协议，无需修改叶子节点；语义测试零回归。设计对比详见 [03-principles §3.2](contributor-guide/03-principles.md)。v1 维持现有实现。

适用建议：存在复杂且可测试的语义变换需求时使用 Transformer；轻量扩展继续使用现有扩展接口。

### Phase C → UIKit 能力补全

| ID | 事项 | 退出标准 |
| --- | --- | --- |
| C1 | 图片 opt-in 稳定性与契约测试 | ADR-006 已落地实现；补全测试矩阵并收敛流式/异步边界（实现已落地，稳定性修复进行中） |
| C2 | 可访问性适配 | 完成 Dynamic Type、VoiceOver 及链接交互验证 |
| C3 | 大文档性能基线 | 给出适用长度、内存开销与滚动性能边界 |
| C4 | UIKit 集成示例 | 提供 `UITextView`、列表 Cell 与聊天气泡使用示例 |

### Phase D → 可选试探

| ID | 事项 | 规则 |
| --- | --- | --- |
| D1 | TextKit 2 | 非默认方案；PoC 未达成预期则移入「不做」 |
| D2 | 目标平台验证 | 逐项解决条件编译并输出验证报告 |
| D3 | 树编辑距离算法 | 对比现有边界，性能/准确度无 >10% 提升则归档 |
| D4 | `maxParseLength` 配置项 | 可并入 v2 实施 |

## 3. 验收标准

| 里程碑 | 标准 |
| --- | --- |
| v1 | 可运行 attributed / blocks / stream 示例；CI 通过；明确已知限制；支持 UIKit 聊天气泡集成 |
| v2 | 无需修改库源码即可通过 Transformer 实现 mention 与自定义块；快照零回归 |
| 长期 | UIKit 集成、流式渲染与语义扩展提供稳定契约 |

## 4. 风险控制

| 风险点 | 规避方案 |
| --- | --- |
| 快照字体跨平台/设备漂移 | 使用语义属性断言验证 |
| IR 重构引发渲染回归 | 先完成 A2 快照全集覆盖，再进行 B3 |
| 中端与 Handler 职责重叠 | 遵循 B6 扩展决策指南 |
| TextKit 2 无法兼容自定义绘制 | 执行 D1 试探，保留 TextKit 1 为主线 |
| 平台支持与声明不符 | 在完成 D2 逐项验证前，仅声明支持 iOS |

## 5. 变更历史

- **2026-07-09**：确定 v1 目标为发布 1.0。
- **2026-07-09**：完成快照测试基建与流式渲染比例阈值设置。
- **2026-07-13**：确认纯 UIKit 定位；明确不包含 SwiftUI 后端；将 IR 移至 v2。
- **2026-07-09**：确定文本引擎默认采用 TextKit 1，TextKit 2 仅作为试探。
- **2026-07-13**：当前状态转移至 `current-status.md`；本文仅维护路线方向与验收标准。
