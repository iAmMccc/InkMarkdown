# ADR-008: v0.0.2 以独立 SwiftUI Adapter Product 正式支持 SwiftUI

## Status

Accepted（Amended by ADR-009、ADR-010）

## Date

2026-08-17

> 2026-08-28 amendment： [ADR-009](ADR-009-block-presentation-continuity.md) 将静态、流式与 promotion 的块呈现连续性收敛到 SwiftUI adapter 内部 module，并取代“`InkThoughtBlock` / render session 持有 live Thought 折叠态”的局部设计。2026-09-04 amendment：[ADR-010](ADR-010-v0.0.2-minimum-platform-ios-15.md) 将 v0.0.2 最低平台从 iOS / iPadOS 14 提升为 15；本文保留原始平台决策作为历史记录。

## Context

- `0.0.1` 是已发布的 UIKit-first public beta；其核心契约是 `NSAttributedString`、UIKit block 和流式 TextKit 渲染。
- 产品现在要求 SwiftUI 成为正式支持场景，并要求与 UIKit 完整渲染语义对齐。
- 现有 UIKit renderer、配置和 block 路由直接依赖 UIKit；在 v0.0.2 同时开发第二套 native SwiftUI renderer，会复制 Markdown 语义、布局、交互、可访问性与测试责任。
- iOS 14+ / iPadOS 14+ 是本版本唯一承诺的平台范围。`UIViewRepresentable` 可覆盖该范围，但部分 SwiftUI convenience capability 的可用性晚于 iOS 14。
- 先前的 SwiftUI spike 已被拒绝并移出仓库；它不构成稳定 interface 或架构承诺。

## Decision

1. 新增独立的 `InkMarkdownSwiftUI` SwiftPM product/target，单向依赖现有 `InkMarkdown` product。
2. v0.0.2 的 SwiftUI implementation 是 UIKit rendering engine 的 presentation adapter：它承载 UIKit view、配置传播、尺寸和生命周期；不开发 native SwiftUI Markdown renderer。
3. `InkMarkdown` 保持 UIKit-first，不能反向 import SwiftUI，也不以“抽取 Core”或 InkIR 为 v0.0.2 前置条件。
4. `InkConfiguration` / `InkAppearance` 是唯一渲染配置真相。SwiftUI Environment 仅是 injection seam；不新增第二套 SwiftUI Theme 模型。
5. 宿主拥有网络、SSE/LLM transport 和业务状态。库提供 render-session 语义来接收 delta、结束、取消与重置；基础 SwiftUI content view 不拥有滚动策略。
6. 完整语义对齐覆盖已有 Markdown 渲染行为、配置扩展、opt-in 图片/公式/图表和交互契约；不要求 UIKit 与 SwiftUI 公开相同的宿主类型。
7. 当前产品路线仅承诺 iOS 14+ 和 iPadOS 14+；不支持 macOS、tvOS、watchOS 或 visionOS。任何平台扩展都必须先通过新的 ADR，而非沿用旧路线图假设。
8. SwiftUI adapter 是 v0.0.2 的 release blocker。发布前必须有语义、生命周期、iPhone/iPad、性能基线、ExampleApp 和文档证据。
9. block presentation identity、live interaction state、promotion lineage、view reuse 与 measurement invalidation 由 adapter 内部 continuity module 统一协调；renderer 与 render session 不再各自维护一套 presentation 真相。具体契约见 ADR-009。

## Alternatives Considered

### 将 SwiftUI 条件编译进 `InkMarkdown` target

- 优点：一次 import 即可使用。
- 缺点：SwiftUI 依赖和 presentation lifecycle 泄漏进 UIKit core，未来替换 implementation 的 seam 变浅。
- 结论：拒绝。

### 在 v0.0.2 直接实现 native SwiftUI renderer

- 优点：更原生地参与 SwiftUI view composition。
- 缺点：需要第二套 renderer 或先引入 InkIR；会扩大语义、性能和可访问性回归面。
- 结论：延后到 InkIR 成熟且有真实第二 adapter 需求时再评估。

### 继续维持 UIKit-only

- 优点：不增加产品和测试范围。
- 缺点：不满足已确认的产品需求。
- 结论：拒绝。

### 把网络或 `AsyncSequence` 作为库的核心职责

- 优点：表面上缩短最简单示例。
- 缺点：把应用业务 transport 与 rendering 生命周期耦合，降低 caller 的选择空间。
- 结论：拒绝；未来可在核心 render-session 之上增加便利 adapter。

## Consequences

### Positive

- UIKit 与 SwiftUI 共享 parser、配置、富文本、block 和流式语义，避免双 renderer 漂移。
- 独立 product 建立清晰 module seam，保护 UIKit 调用者并给未来 implementation 演进留下空间。
- 复杂流式生命周期集中在 render session，改善 locality 与测试 surface。
- block presentation continuity 集中在 adapter 内部 module；render session 保持 canonical source 与阶段语义 owner。
- 明确 iOS/iPadOS 14 验证范围，替代 ADR-002 中的旧多平台路线预期，避免不实多平台承诺。

### Costs

- 需要维护独立 SwiftUI adapter、生命周期兼容层、测试和示例。
- SwiftUI 调用者需要显式依赖 `InkMarkdownSwiftUI` product。
- adapter 不会自动获得 native SwiftUI renderer 的所有组合能力。
- 性能、内存和流畅度必须用证据持续验证，不能以架构名称推断。

## 公开类型清单

以下类型是 `InkMarkdownSwiftUI` adapter 面向 SwiftUI 宿主公开的 API 表面（v0.0.2 实现基线，声明见 `Sources/InkMarkdownSwiftUI/`）。这些类型承载 UIKit 视图、配置与生命周期：宿主通过它们获得与 UIKit 渲染引擎一致的渲染语义，而无需直接接触 `UIViewRepresentable` 桥接细节。

| 类型 / 成员 | 声明 | 职责 |
| --- | --- | --- |
| `InkMarkdownView` | `public struct InkMarkdownView: View` | 静态 Markdown 渲染视图；`init(markdown: String, configuration: InkConfiguration? = nil)` 及省略参数名变体；未显式传入配置时读取环境注入的 `inkConfiguration`，回退至 `InkConfiguration.standard` |
| `InkStreamMarkdownView` | `public struct InkStreamMarkdownView: View` | 流式 Markdown 渲染视图；`init(session: InkMarkdownRenderSession)` 绑定流式会话，支持打字机式逐字渲染，并在显示完成后提升为终态块级组件 |
| `InkMarkdownRenderSession` | `public final class InkMarkdownRenderSession: ObservableObject` | 流式会话状态机，单条流式 Markdown 的唯一输入源与生命周期所有者；公开 `State: Sendable, Equatable` 枚举、`append(_:)` / `finish()` / `cancel()` / `reset()`、`onDisplayUpdate` 回调与 `isPromoted` 发布 |
| `.inkConfiguration(_:)` | `public extension View { func inkConfiguration(_ configuration: InkConfiguration) -> some View }` | 为视图层级注入统一渲染配置的环境修饰符；配套 `EnvironmentValues.inkConfiguration` 环境值 |

> 注：本清单是文档与源码之间可核对的 API 基线；类型名如有演进，以 `Sources/InkMarkdownSwiftUI/` 源码为准。`InkMarkdownSwiftUI` 不再 `@_exported import InkMarkdown`；调用方需显式 `import InkMarkdown` 以使用 `InkConfiguration` 等核心类型。

## Related Documents

- [SwiftUI Adapter 总体技术设计](../contributor-guide/08-swiftui-adapter-architecture.md)
- [ADR-009：块呈现连续性由 SwiftUI Adapter 持有](ADR-009-block-presentation-continuity.md)
- [ADR-010：v0.0.2 最低平台升级为 iOS / iPadOS 15](ADR-010-v0.0.2-minimum-platform-ios-15.md)
- [Block Presentation Continuity module 技术设计](../contributor-guide/11-block-presentation-continuity.md)
- [ADR-002: v1.0 对外平台范围仅 iOS 14+](ADR-002-v1-platform-scope-ios-only.md)（平台范围由本 ADR supersede）
- [SwiftUI Markdown 生态研究](../references/swiftui-markdown-ecosystem-research.md)
