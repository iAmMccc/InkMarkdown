# 发展方向与路线

以源码和 `Package.swift` 为准。

本文只答三件事：库最终长什么样、地基在哪、接下来做什么。

标注：

- **承诺**：有退出标准
- **试探**：先做验证，失败就写进「不做」
- **本阶段不做**：刻意砍掉的范围

---

## 1. 目标形态

基于 swift-markdown 的 Apple 原生 Markdown **渲染**库：

- **现在**：UIKit。富文本塞进 `UITextView` / 列表；表格、代码块等走 `UIView`；AI 流式有测试兜着
- **v2**：解析结果先落到中间模型 **InkIR**，可挂可选 Transformer
- **更后**：SwiftUI 作为第二个渲染后端，吃同一份 IR——不是第一天交付

### 给谁用

| 优先级 | 场景 | 需要什么 |
| --- | --- | --- |
| 高 | UIKit / 混合（IM、资讯、AI 对话） | 嵌进现有气泡和 Cell，不绑死 SwiftUI |
| 高 | 流式 Markdown | 不越聊越卡、样式别乱跳、增量结果可测 |
| 中 | 业务扩展 | @提及、特殊 fence 出卡片、链接消毒 |
| 低 | 双 UI 栈 | 同一语义，UIKit 和 SwiftUI 不各写一套规则 |

### 和别人比，靠什么

1. **嵌进 UIKit**：`NSAttributedString` + 块级 `UIView`；固定行高；主路径不是 WebView
2. **流式有规矩**：稳定前缀 / 活跃后缀 + 双缓冲；增量和全量有基准与一致性测试
3. **扩展分两档**
   - 轻量（已有）：`sourceFilter`、`InkInlineSyntax`、`InkBlockHandler`、`linkTapHandler`
   - 进阶（v2）：InkIR + Transformer——规则多、或要双端共用时再上，不是「没中端就不能用」

### 目标管线

```text
Markdown
  → sourceFilter? 
  → swift-markdown Document
  → Lowering → InkIR
  → Transformer 链（可空）
  → UIKit 后端（富文本 + 块 + 流式）
  → 以后：SwiftUI 后端
```

| 阶段 | 对外形态 |
| --- | --- |
| v1 | 仍可直接 Markup → 渲染；不强制公开 IR |
| v2 | IR 成为中端；UIKit 渲染吃 IR |
| 以后 | SwiftUI 只消费 IR，不复制业务分支 |

### 做 / 不做

| 做 | 不做 |
| --- | --- |
| CommonMark + 实用 GFM | 完整 HTML 浏览器、编辑器、高亮引擎本体 |
| UIKit 渲染 + 流式 | WebView 主路径 |
| 扩展点；v2 再上 IR/Transformer | 把 TED 当默认流式引擎；对外吹 O(1) |
| SwiftUI 第二后端（路线图） | 和 MarkdownUI 抢主题生态 |
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
| **v2.x / v3** | SwiftUI 后端（同 IR）；可选多平台试探 |
| **v3+** | TextKit 2 试探；TED 仅研究，没收益就归档 |

---

## 2. 现状

### 已有

| 域 | 状态 | 证据 |
| --- | --- | --- |
| 解析 | 有 | `InkParser` |
| CommonMark 富文本 | 有 | `InkAttributedRenderer` + `InkTextContext` |
| 固定行高 | 有 + 测 | `applyFixedLineHeight` |
| 块路由 | 有 | 代码块 / 表 / 分割线 handler |
| 表 / 流式表 | 有 | `InkTable*` / `InkStreamTableView` |
| 行内 / 块扩展 | 有 | `InkInlineSyntax` / `InkBlockHandler` |
| 流式 | 有 | `InkStreamRenderer`；增量/全量 ≤ 0.30 已标定 |
| 快照基建 | 骨架 | `RenderSnapshot` |
| ExampleApp | 有 | 含 SSE 等 |
| 平台 | 仅 iOS 14+ | `Package.swift` |
| 依赖 | 远程 swift-markdown | `branch: main` |

### 缺口

| 项 | 状态 |
| --- | --- |
| InkIR / Transformer | 无 |
| 快照全集 | 基建有，覆盖不全 |
| 删除线样式 | 有字，无删除线 |
| 图片 | 占位 |
| CI / CHANGELOG / 1.0 tag | 无 |
| 公开 API 审计 | 未完成 |
| SwiftUI | 路线图 |
| TextKit 2 | 非默认 |

**结论：** 不是从 0 搭。v1 雏形已经在，要补测试、CI、文档诚实度，再发 1.0。

### 竞品位置

- 强于「只会行内 attributed」：有块路由、表、流式、固定行高
- 弱于 MarkdownUI / Textual：没有 SwiftUI 产品面（分阶段，有意为之）
- 和 Microsoft SwiftStreamingMarkdown 错开：对方偏 SwiftUI/产品功能；这边偏 UIKit 可嵌入 + 宿主扩展
- 中端（IR）：Web 生态常见 AST 插件；iOS 上当进阶能力，v2 再做

---

## 3. 路线

```text
v1 发布可信  →  v2 InkIR + Transformer  →  SwiftUI 后端  →  TK2 / 多平台 / TED 试探
```

依赖关系：没有 v1 快照护栏，不上 IR；没有 IR，不做真正的 SwiftUI 第二后端。

### Phase A → v1.0.0（承诺）

| ID | 事项 | 退出标准 |
| --- | --- | --- |
| A1 | 文档与源码一致 | 本文 + README；根目录 `AGENTS`/`Claude` 标过时或以源码为准 |
| A2 | CommonMark + 已支持 GFM 快照补全 | 每类元素至少 1 条语义断言 |
| A3 | 公开 API 审计 | 有清单；内部用 `internal`/`@_spi`；核心 API 有中文 `///` |
| A4 | CI | PR 上 `swift test` 不过不能合 |
| A5 | CHANGELOG + `1.0.0` | 写清 API 与限制（图片/删除线/仅 iOS/TK1） |
| A6 | ExampleApp | 富文本 / 块表 / 流式 / 自定义 handler 各有入口 |

**v1 本阶段不做：** 公开 InkIR、Transformer、SwiftUI、TextKit 2、TED、多平台正式支持、Theme 协议。

### Phase B → v2.0.0（架构跃迁）

| ID | 事项 | 退出标准 |
| --- | --- | --- |
| B1 | 最小 `InkBlock` / `InkInline` | 覆盖已渲节点；值类型 |
| B2 | Markup → InkIR | 1:1 + 单测 |
| B3 | UIKit 渲染吃 IR | 与 v1 快照零回归 |
| B4 | `InkTransformer` + 配置挂载 | 空列表 = 旧行为 |
| B5 | 两个真 demo | ① Mention ② latex/业务 fence |
| B6 | 扩展点决策树 | sourceFilter / Transformer / InlineSyntax / BlockHandler 何时用哪个 |
| B7 | 删除线；图片策略 | 契约 + 示例 |
| B8 | 流式接 IR 或证明兼容 | 一致性测试绿 |

对外说法：规则多、要双端一致时再挂 transformers；轻量场景继续用现有扩展点。

### Phase C → SwiftUI（第二后端）

| ID | 事项 | 退出标准 |
| --- | --- | --- |
| C1 | SwiftUI 后端只依赖 IR | 不复制业务 if |
| C2 | 与 UIKit 共用 Transformer 示例 | 同 MD → 同语义 |
| C3 | 文档定位 | 第二后端，不抢主题市场 |

### Phase D → 可选试探

| ID | 事项 | 规则 |
| --- | --- | --- |
| D1 | TextKit 2 | 非默认；PoC 失败 → 写入「不做」 |
| D2 | 多平台 | 出报告，不默认承诺 |
| D3 | 树编辑距离 | 对比现有稳定边界；无 >10% 收益则归档 |
| D4 | `maxParseLength` 可配 + 截断回调 | 可并进 v2 |

---

## 4. 怎样算做成

| 里程碑 | 标准 |
| --- | --- |
| v1 | 30 秒能跑通 attributed / blocks / stream；CI 绿；限制写清楚；UIKit 聊天气泡能进生产 |
| v2 | 1～2 个 Transformer 完成 mention + 特殊块，不改库源码；快照零回归 |
| 长期 | UIKit/SwiftUI 同 IR；被记住的是「可嵌入 + 流式规矩 + 语义可扩展」，不是「又一个 SwiftUI 主题库」 |

---

## 5. 风险

| 风险 | 怎么挡 |
| --- | --- |
| 快照跨机字体漂移 | 语义属性断言（已定） |
| IR 重构回归 | 先 A2 快照全集，再 B3 |
| 中端与 handler 职责重叠 | B6 决策树 |
| TK2 迁不动自定义绘制 | D1 试探，主线 TK1 |
| 旧文档写多平台、Package 只有 iOS | v1 只承诺 iOS；多平台走 D2 |

---

## 6. 决策记录

- **2026-07-09**：确认 v1 雏形；当前目标是发 1.0，不是从零搭
- **2026-07-09**：快照基建 + 流式 ratio 门槛落地
- **2026-07-09**：定位改为 UIKit 现在 / SwiftUI 以后；中端与 IR 放 v2；TED/范畴论不进对外卖点
- **2026-07-09**：文本引擎默认 TextKit 1；TextKit 2 仅试探
- **2026-07-09**：本文作为「方向 + 基线 + 路线」唯一主文档；战略不另存外部 plan
