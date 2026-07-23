# 发展方向与路线

产品范围以根目录 `AGENTS.md` / `CLAUDE.md` 为准；已交付状态以
[current-status.md](current-status.md)、`Package.swift`、源码和测试为证据。

本文只答三件事：库最终长什么样、地基在哪、接下来做什么。

标注：

- **承诺**：有退出标准
- **试探**：先做验证，失败就写进「不做」
- **本阶段不做**：刻意砍掉的范围

## 1. 目标形态

基于 swift-markdown 的 Apple 原生 Markdown **渲染**库：

- **现在**：UIKit。富文本塞进 `UITextView` / 列表；表格、代码块等走 `UIView`；AI 流式有测试兜着
- **v2**：解析结果先落到中间模型 **InkIR**，可挂可选 Transformer
- **更后**：继续完善 UIKit 渲染、扩展语义与平台验证，不增加 SwiftUI 后端

### 给谁用

| 优先级 | 场景 | 需要什么 |
| --- | --- | --- |
| 高 | UIKit / 混合（IM、资讯、AI 对话） | 嵌进现有气泡和 Cell，不绑死 SwiftUI |
| 高 | 流式 Markdown | 不越聊越卡、样式别乱跳、增量结果可测 |
| 中 | 业务扩展 | @提及、特殊 fence 出卡片、链接消毒 |
| 中 | 大型 UIKit 宿主 | 统一语义、可组合扩展、可控的性能与兼容性 |

### 和别人比，靠什么

1. **嵌进 UIKit**：`NSAttributedString` + 块级 `UIView`；固定行高；主路径不是 WebView
2. **流式有规矩**：稳定前缀 / 活跃后缀 + 双缓冲；增量和全量有基准与一致性测试
3. **扩展分两档**
   - 轻量（已有）：`sourceFilter`、`InkInlineSyntax`、`InkBlockHandler`、`linkTapHandler`
   - 进阶（v2）：InkIR + Transformer——规则多、需要稳定语义变换时再上，不是「没中端就不能用」

### 目标管线

```text
Markdown
  → sourceFilter? 
  → swift-markdown Document
  → Lowering → InkIR
  → Transformer 链（可空）
  → UIKit 后端（富文本 + 块 + 流式）
```

| 阶段 | 对外形态 |
| --- | --- |
| v1 | 仍可直接 Markup → 渲染；不强制公开 IR |
| v2 | IR 成为中端；UIKit 渲染吃 IR |

### 做 / 不做

| 做 | 不做 |
| --- | --- |
| CommonMark + 实用 GFM | 完整 HTML 浏览器、编辑器、高亮引擎本体 |
| UIKit 渲染 + 流式 | WebView 主路径 |
| 扩展点；v2 再上 IR/Transformer | 把 TED 当默认流式引擎；对外吹 O(1) |
| UIKit 渲染 + 可组合语义扩展 | SwiftUI 渲染器；和 MarkdownUI 抢主题生态 |
| **TextKit 1** 为库内绘制默认 | 短期只交 TextKit 2 / 承诺 Bear 级长文 |
| 图片、删除线按版本补 | 「解析器能 parse 的全都渲」 |

### 文本引擎：TextKit 1 默认，TextKit 2 只试探

| | TextKit 1 | TextKit 2 |
| --- | --- | --- |
| 是什么 | UIKit 旧文本排版机 | 新排版机；不是另一套 UI 框架 |
| 本库 | 在用：`InkMarkdownLayoutManager` 画代码底、引用竖线 | 未用 |
| 聊天气泡 / 中短文 | 够用 | 没必要当默认 |
| 万行长文档编辑 | 上限弱 | 理论上更合适（另一类产品） |

**v1–v2 正式路径 = TextKit 1。**

库内 text view / block 走 TK1。宿主只把 `NSAttributedString` 塞进自己的 `UITextView`，基础属性两边都能显示；圆角代码底等自定义绘制，要用库提供的 text view / block。

TextKit 2 只做远期试探（fragment 能否复现代码底/竖线、长文是否真有收益）；失败就公开写进「不做」。

### 版本怎么切

| 版本 | 定义 |
| --- | --- |
| **v1.0** | 能信的 UIKit 库：契约测试、CI、API 干净、文档诚实；**不强制公开 IR** |
| **v2.0** | InkIR + Transformer + 扩展决策树 + 删除线/图片策略；渲染吃 IR |
| **v2.x** | 图片 / 删除线等语义补全、可访问性与性能完善 |
| **v3+** | 平台兼容落地；TextKit 2 试探；TED 仅研究，没收益就归档 |

## 2. 路线

当前已经交付的能力、限制和配置漂移只在 [current-status.md](current-status.md) 维护。本页从该基线向后安排版本，不复制现状表。

```text
v1 发布可信  →  v2 InkIR + Transformer  →  UIKit 能力补全  →  TK2 / 平台验证 / TED 试探
```

依赖关系：没有 v1 快照护栏，不上 IR；没有稳定 IR，不扩展复杂语义变换。

### Phase A → v1.0.0（承诺）

| ID | 事项 | 退出标准 |
| --- | --- | --- |
| A1 | 建立可信知识基线 | README、当前状态、roadmap 与 contributor guide 分层清楚且相互一致 |
| A2 | CommonMark + 已支持 GFM 快照补全 | 每类元素至少 1 条语义断言 |
| A3 | 公开 API 审计 | 有清单；内部用 `internal`/`@_spi`；核心 API 有中文 `///` |
| A4 | CI | PR 上 iOS Simulator 测试不过不能合 |
| A5 | CHANGELOG + `1.0.0` | 写清 API 与限制（图片/删除线/仅 iOS/TK1） |
| A6 | ExampleApp | 富文本 / 块表 / 流式 / 自定义 handler 各有入口 |

**v1 本阶段不做：** 公开 InkIR、Transformer、TextKit 2、TED、多平台正式支持、Theme 协议。SwiftUI 不属于任何阶段。

### Phase B → v2.0.0（架构跃迁）

| ID | 事项 | 退出标准 |
| --- | --- | --- |
| B1 | 最小 `InkBlock` / `InkInline` | 覆盖已渲节点；值类型 |
| B2 | Markup → InkIR | 1:1 + 单测 |
| B3 | UIKit 渲染吃 IR | 与 v1 快照零回归 |
| B4 | `InkTransformer` + 配置挂载 | 空列表 = 旧行为 |
| B5 | 两个真 demo | ① Mention ② LaTeX / 业务 fence |
| B6 | 扩展点决策树 | sourceFilter / Transformer / InlineSyntax / BlockHandler 何时用哪个 |
| B7 | 删除线；图片策略 | 契约 + 示例 |
| B8 | 流式接 IR 或证明兼容 | 一致性测试绿 |
| B9 | `InkTextContext` → TextStyle 容器化 | 见下 |

**B9 背景**：v1 的 context 下传（范式 A）要求每个叶子显式读取每个样式标志，漏一个叶子就丢样式（删除线初版遗漏 `renderInlineCode` 即此症状）。这是范式 A 的结构性维护税，不是逻辑 bug。主流库（[MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)、苹果 Foundation）同选范式 A，但用 `TextStyle` 协议 + `_collectAttributes(inout:)` 把离散标志收敛成可收集容器，叶子接收已收集好的容器直接 apply，从根本上消除「逐叶子补 if」。

**B9 退出标准**：`InkTextContext` 的离散标志（`isStrikethrough` / `linkURL` / `obliqueness` 等）被一个可合并的样式容器取代；新增样式只需实现协议，无需改任何叶子；现有语义测试零回归。详细权衡见 [03-principles §3.2](contributor-guide/03-principles.md)。v1 维持现状 + 人工补齐叶子即可，不提前重构。

对外说法：规则多、需要可测试的语义变换时再挂 transformers；轻量场景继续用现有扩展点。

### Phase C → UIKit 能力补全

| ID | 事项 | 退出标准 |
| --- | --- | --- |
| C1 | 图片策略落地 | 明确异步加载、缓存与附件 / 独立块边界 |
| C2 | 可访问性 | Dynamic Type、VoiceOver 与链接交互有验证 |
| C3 | 大文档性能基线 | 给出适用长度、内存与滚动性能边界 |
| C4 | UIKit 集成模板 | `UITextView`、列表 Cell、聊天气泡各有可运行示例 |

### Phase D → 可选试探

| ID | 事项 | 规则 |
| --- | --- | --- |
| D1 | TextKit 2 | 非默认；PoC 失败 → 写入「不做」 |
| D2 | 目标平台验证 | 按既定平台矩阵逐项解决条件编译并给出验证报告 |
| D3 | 树编辑距离 | 对比现有稳定边界；无 >10% 收益则归档 |
| D4 | `maxParseLength` 可配 + 截断回调 | 可并进 v2 |

## 3. 怎样算做成

| 里程碑 | 标准 |
| --- | --- |
| v1 | 30 秒能跑通 attributed / blocks / stream；CI 绿；限制写清楚；UIKit 聊天气泡能进生产 |
| v2 | 1～2 个 Transformer 完成 mention + 特殊块，不改库源码；快照零回归 |
| 长期 | UIKit 集成、流式渲染与语义扩展形成稳定契约，不扩张为 SwiftUI 主题库 |

## 4. 风险

| 风险 | 怎么挡 |
| --- | --- |
| 快照跨机字体漂移 | 语义属性断言（已定） |
| IR 重构回归 | 先 A2 快照全集，再 B3 |
| 中端与 handler 职责重叠 | B6 决策树 |
| TK2 迁不动自定义绘制 | D1 试探，主线 TK1 |
| 目标平台矩阵与当前 Package 不一致 | 当前状态明确只交付 iOS；按 D2 逐项验证后再宣称支持 |

## 5. 决策记录

- **2026-07-09**：确认 v1 雏形；当前目标是发 1.0，不是从零搭
- **2026-07-09**：快照基建 + 流式 ratio 门槛落地
- **2026-07-13**：恢复 UIKit-only 定位；SwiftUI 明确移出路线；中端与 IR 仍放 v2
- **2026-07-09**：文本引擎默认 TextKit 1；TextKit 2 仅试探
- **2026-07-13**：当前事实移到 `current-status.md`；本文只维护方向、优先级和退出标准
