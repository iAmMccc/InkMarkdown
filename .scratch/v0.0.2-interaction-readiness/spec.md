# v0.0.2 语义、交互、响应式布局与网络图片收口

Status: ready-for-agent

## Problem Statement

InkMarkdown 已具备 UIKit-first 渲染引擎、SwiftUI adapter、流式会话、Block Presentation Continuity、表格、链接和 opt-in 图片子系统，但 v0.0.2 仍缺少一组能够证明这些能力在真实宿主中一致工作的发布证据。

从使用者视角看，当前问题不是“有没有相应类型”，而是同一份 Markdown 在 UIKit 富文本、UIKit 块、流式终态与 SwiftUI adapter 中仍可能出现语义、回调或布局差异：引用链接尚未形成跨通道证据；loose list 续段的列表样式不完整；复杂表格单元格与表格链接缺少闭环；SwiftUI streaming 阶段尚未统一使用宿主的链接回调；旋转、Split View 与初始零宽度没有完整验收；网络图片虽然已有加载、Store、缓存与布局模块，却仍采用空 host 列表默认拒绝、缺少真实 URLSession 验收、底层取消和相对 URL 闭环。

本项目需要把这些分散缺口收敛成可实现、可验证的 v0.0.2 语义对齐矩阵，同时保持既有产品边界：UIKit rendering engine 是唯一语义实现，SwiftUI 只是 adapter；图片真图渲染继续 opt-in；自动化只覆盖关键数据、状态、回调与渲染语义，视觉和交互通过 ExampleApp 手工验收。

## Solution

建立一套共享的 v0.0.2 语义对齐矩阵，以单一 canonical corpus 描述 Markdown 输入、预期语义和适用呈现通道。Attributed、Block、streaming 与 SwiftUI 测试消费同一批 fixture，并在最高现有 seam 上比较语义投影，而不是复制四套测试或比较像素级 frame。

修复共享 UIKit rendering engine 中的列表、链接和表格语义缺口；让 SwiftUI streaming 阶段与静态和 promotion 后路径使用同一个 `linkTapHandler` 契约；在现有 container reconciliation 与 measurement seam 上补齐初始零宽度、旋转和 Split View 连续宽度变化。网络图片继续由现有 opt-in 子系统承担，但将图片业务策略与图片资源安全边界分离：开启真图后默认不限制 HTTP(S) host，宿主可选注入 allowlist；库始终执行协议、响应、图片数据、大小、重定向和取消保护。

ExampleApp 提供表格链接、复制、网络图片和响应式布局的可操作验收入口。每轮人工验收留下候选 SHA、设备、系统、方向、宽度、输入、步骤、预期、实际和结果。完整 VoiceOver 工作不属于本轮；所有已有 VoiceOver 行为与关键测试必须保留，不得产生 `0.0.1` 行为回退。

## User Stories

1. 作为 UIKit 宿主开发者，我希望同一份 Markdown 在富文本与块渲染入口中遵守同一份语义规范，从而不必针对不同入口维护内容补丁。
2. 作为 SwiftUI 宿主开发者，我希望 adapter 复用 UIKit rendering engine 的语义，从而不会形成第二套 Markdown renderer。
3. 作为流式聊天使用者，我希望消息完成后看到的内容与静态渲染结果语义一致，从而不会在 promotion 时丢失文本、链接或列表结构。
4. 作为库维护者，我希望所有呈现通道消费同一套 canonical corpus，从而避免四套 fixture 漂移。
5. 作为测试维护者，我希望语义矩阵比较文本、属性、链接目标、段落样式、Block 类型和表格结构，从而验证用户可观察行为而不是内部实现。
6. 作为阅读引用链接的用户，我希望 reference link 正确显示并保持目标 URL，从而获得与普通 inline link 一致的行为。
7. 作为阅读标准自动链接的用户，我希望 `<URL>` 继续成为可点击链接，从而保持现有 CommonMark 契约。
8. 作为阅读裸 URL 的用户，我希望当前不支持的 GFM bare URL 继续按普通文本显示，从而不会出现未经规范确认的隐式识别。
9. 作为阅读相对链接的用户，我希望现有相对链接语义不因本轮修复回退，从而可以由宿主按现有策略处理目标。
10. 作为处理链接的宿主开发者，我希望 `linkTapHandler` 返回 `true` 时阻止系统默认行为，从而由业务方完全接管导航。
11. 作为不接管链接的宿主开发者，我希望 handler 未配置或返回 `false` 时保留系统默认行为，从而不必重复实现基础链接交互。
12. 作为查看流式内容的用户，我希望链接在消息尚未完成时就能使用与终态相同的回调，从而不会出现前后行为切换。
13. 作为查看 loose list 的用户，我希望同一列表项中的续段保持列表缩进、悬挂缩进和固定行高，从而不会看起来脱离原列表项。
14. 作为查看混合列表的用户，我希望无序列表、有序列表和更深层子列表正确累计缩进，从而能理解层级关系。
15. 作为查看列表内引用的用户，我希望引用仍属于对应列表项，从而不会被错误提升为根级内容。
16. 作为查看任务列表的用户，我希望既有 marker 与嵌套行为保持不变，从而不会因矩阵重构产生回归。
17. 作为查看表格的用户，我希望表头、数据行和对齐信息正确，从而能理解列含义。
18. 作为查看复杂表格单元格的用户，我希望强调、粗体、行内代码和链接组合保持各自语义，从而不会被降级为错误的纯文本。
19. 作为查看 escaped pipe 的用户，我希望转义竖线留在单元格内容中，从而不会被误拆成新列。
20. 作为查看空单元格或不齐行的用户，我希望 renderer 按 parser 产生的表格结构稳定呈现，从而不会崩溃、越界或静默错位。
21. 作为点击表格链接的用户，我希望表格单元格使用与正文相同的链接回调契约，从而获得一致交互。
22. 作为窄屏用户，我希望表格可以横向滚动且单元格按既有模式换行，从而不会被裁切到不可读。
23. 作为需要复制表格的用户，我希望在 ExampleApp 中能够使用现有长按复制能力，从而验证复制内容和交互入口。
24. 作为流式表格用户，我希望未闭合阶段继续看到稳定的 pipe 文本，并在完成后提升为真实表格，从而避免引入另一套增量网格引擎。
25. 作为旋转设备的用户，我希望 Markdown 在横竖屏切换后重新测量，从而不出现旧宽度、零高度或裁切。
26. 作为 iPad Split View 用户，我希望拖动分隔线时内容跟随连续宽度变化，从而可以在不同窗口宽度下稳定阅读。
27. 作为 SwiftUI 宿主开发者，我希望 adapter 在初始宽度为零时不猜测屏幕宽度，从而避免使用错误 geometry。
28. 作为 SwiftUI 宿主开发者，我希望首次有效宽度到达后 container 完成 reconcile，从而让延迟建立约束的宿主正常显示内容。
29. 作为 Thought 卡片用户，我希望旋转和 Split View 后折叠状态保持不变，从而不因重测丢失块呈现状态。
30. 作为查看代码、长链接、表格和图片的用户，我希望这些宽度敏感内容在窄宽与全宽间切换时不产生布局循环，从而保持滚动稳定。
31. 作为默认使用 InkMarkdown 的开发者，我希望图片真图渲染继续关闭，从而保持 `0.0.1` 文本占位契约。
32. 作为主动开启图片的开发者，我希望有效 HTTP(S) 图片无需先配置 host allowlist 即可加载，从而获得开箱可用的图片能力。
33. 作为有业务来源限制的开发者，我希望仍可注入 host allowlist，从而执行自己的产品策略。
34. 作为处理签名 URL 的开发者，我希望 query 默认保留，从而不会破坏鉴权或尺寸参数。
35. 作为图片加载使用者，我希望 fragment 默认不参与请求与缓存身份，从而避免无意义的重复缓存。
36. 作为使用重定向图片源的开发者，我希望库最多跟随有限次数的安全重定向，从而支持常见 CDN 又避免无限跳转。
37. 作为配置 host 策略的开发者，我希望每次重定向都重新校验业务 host 规则，从而不能通过 redirect 绕过限制。
38. 作为加载大图片的用户，我希望网络响应受到可配置大小上限保护，从而避免异常响应耗尽内存。
39. 作为图片加载失败的用户，我希望看到稳定 fallback，从而不会得到空白或崩溃。
40. 作为控制重试策略的宿主开发者，我希望库不执行隐藏自动重试，从而可以由重新渲染、reset 或自定义 loader 决定重试时机。
41. 作为滚动离开图片的用户，我希望最后一个订阅取消时底层网络任务被取消，从而不浪费网络和解码资源。
42. 作为多个视图共享图片的用户，我希望仍有订阅者时共享 inflight 请求继续执行，从而保留请求合并收益。
43. 作为更换图片 loader 的开发者，我希望缓存语义包含 loader identity，从而不会错误复用旧 loader 的图片。
44. 作为需要相对图片 URL 的开发者，我希望提供 `baseURL` 后正确解析图片地址，从而支持常见 Markdown 文档资源。
45. 作为没有提供 `baseURL` 的开发者，我希望相对图片 URL 返回明确失败，从而不会由库猜测来源。
46. 作为库使用者，我希望 v0.0.2 只提供内存缓存，从而不会在未定义生命周期和磁盘治理前引入持久化副作用。
47. 作为 ExampleApp 使用者，我希望通过 `placehold.co` 验证固定内容图片，从而获得可重复的真实网络成功路径。
48. 作为 ExampleApp 使用者，我希望通过 `picsum.photos` 验证重定向和真实网络链路，从而覆盖常见外部图片服务行为。
49. 作为维护者，我希望真实网络证据记录时间、最终 URL、设备、系统和网络结果，从而区分产品缺陷与第三方服务故障。
50. 作为现有 VoiceOver 使用者，我希望已有 Thought、代码块、分割线和图片交互语义不被删除，从而避免 `0.0.1` 行为回退。
51. 作为维护者，我希望本轮不扩张完整 VoiceOver 或表格朗读体系，从而优先完成已确认的语义、交互、布局和网络图片缺口。
52. 作为维护者，我希望 UI 和视觉通过 ExampleApp 人工验收，从而避免脆弱 UI automation 与 snapshot 测试。
53. 作为维护者，我希望自动化只覆盖关键数据、状态、调用次数、回调和语义链路，从而控制测试维护成本。
54. 作为审查者，我希望每个完成声明都关联当前候选 SHA 与可复核证据，从而不会把历史结果当作当前 checkout 证明。
55. 作为开源贡献者，我希望公开 API 的行为、默认值、失败和生命周期有中文文档注释，从而可以正确集成能力。
56. 作为项目维护者，我希望实现按功能粒度本地提交，从而可以独立审查、回滚和后续推送。

## Implementation Decisions

- 使用领域术语“v0.0.2 语义对齐矩阵”“图片业务策略”和“图片资源安全边界”。不得把“完整语义”解释为实现全部 CommonMark/GFM，也不得把宿主域名规则与库资源保护混称为同一策略。
- UIKit rendering engine 仍是唯一 Markdown 语义实现；SwiftUI adapter 只负责 UIKit view、配置、生命周期和测量接入，不实现第二套 native SwiftUI renderer。
- 建立单一 canonical corpus。每个 fixture 包含 Markdown 输入、预期语义投影、适用呈现通道和明确的不支持边界。
- 语义投影至少覆盖纯文本、inline traits、链接 destination、段落样式与缩进、Block 类型、表格 headers/rows/alignments 和链接回调行为。原始 UIView frame 不属于跨通道语义相等条件。
- `docs/spec/` 是渲染语义来源；实现不一致时修复共享 renderer seam。固定版 `swift-markdown` 不产生相应 AST 时，记录为不支持，不用字符串正则伪造语法。
- reference link 纳入支持矩阵；标准 `<URL>`、相对链接和危险 scheme fallback 保持既有契约；GFM bare URL 继续按普通文本处理。
- `linkTapHandler` 契约统一为：返回 `true` 表示宿主已处理并阻止默认行为；未配置或返回 `false` 时保留系统默认行为。
- SwiftUI streaming text view 在未 finish 时也必须连接当前 configuration 的 `linkTapHandler`。finish 与 promotion 不得改变 handler 语义或保留陈旧 callback。
- loose list 续段必须继承所属列表项的累计缩进、悬挂缩进和固定行高；混合有序/无序嵌套和列表内引用沿现有递归渲染路径处理。
- 表格继续由 Block renderer 提供真实网格；Attributed renderer 的文本 fallback 不承诺网格布局。复杂单元格按 parser 产生的 table/cell 结构与现有 inline renderer 呈现。
- streaming 表格不新增增量网格引擎。未闭合和增量阶段保留 pipe 文本，`finish()` 后由既有 promotion 路径产生真实表格。
- 表格链接使用正文相同的 handler 契约；ExampleApp 当前主导航增加表格链接 fixture，并在该入口启用既有长按复制能力。不恢复旧的顶层组件 Pager。
- 响应式布局沿用 Block Presentation Continuity 和 container measurement seam。宽度变化只失效受影响的 measurement，不重建无关 presentation state。
- 初始有效宽度不存在时，adapter 不使用屏幕宽度或固定常量兜底；暂不布局，等待宿主提供横向约束。首次有效宽度到达后必须完成 reconcile。
- iOS/iPadOS 16+ 继续使用可用的 proposal sizing seam；更低系统继续使用既有 intrinsic-size 兼容路径。本轮不改变 iOS/iPadOS 14+ 产品目标。
- 旋转和 Split View 必须保留同一呈现周期内的块呈现状态，并重新测量表格、代码块、Thought、图片和长链接。
- `InkImageRendering.isEnabled` 继续默认 `false`。关闭时保持文本占位且不加载网络或磁盘资源。
- 开启图片真图渲染后，空 host allowlist 默认允许所有 host。域名 allowlist 和业务 URL 规则由宿主可选配置，不作为使用图片能力的必填前置条件。
- 图片资源安全边界始终生效：只接受配置允许的 scheme；HTTP(S) 要求 2xx 与有效图片数据；默认最多 3 次重定向；配置 host 业务策略时，每次重定向重新校验。
- 增加可配置网络响应大小上限，默认 20 MiB。该限制是资源安全边界，不是图片业务策略。
- query 默认保留，fragment 默认剥离。相同规范化规则同时用于实际请求和 canonical cache identity。
- `InkImageStore` 继续只提供内存缓存、inflight 合并、并发和等待队列控制，不增加磁盘缓存。
- 图片 cache identity 必须包含 source、display parameters 与 loader semantic identity。更换 loader 后不得复用旧 loader 的缓存结果。
- 最后一个订阅取消时，取消必须传播到底层加载任务；其他订阅仍存在时，共享 inflight 请求继续运行。
- 网络失败使用既有 fallback，不写入成功缓存，不执行隐藏自动重试。重新渲染、reset 或自定义 loader 可明确发起新尝试。
- 宿主提供 `baseURL` 时，relative image source 解析为确定请求 URL；未提供时返回明确的 unsupported/no-base-URL 结果。
- block 图片预览保留现有行为；本轮不新增 inline 图片点击协议。
- 所有已有 VoiceOver source、行为和关键测试保留。本轮不新增表格无障碍树、系统级焦点编排或完整朗读矩阵，也不主动屏蔽 UIKit 自动可访问性。
- ADR-006 记录图片业务策略默认开放与资源安全边界；实现完成前，当前状态文档仍须把代码现状与目标决策区分开。
- 公开 API 新增或默认值变化须补充完整中文文档注释，并同步 README 双语核心信息、规范、FAQ、CHANGELOG、当前状态和发布清单。
- 实施顺序优先处理共享语义根因，再统一链接/表格交互，再收口宽度协商，最后完成网络图片底层与真实验收，避免在多个呈现通道分别打补丁。

## Testing Decisions

- **硬性测试约束**：禁止新增 UI 测试、UI automation 或视觉 snapshot。数据与业务逻辑只测试关键路径；新增测试必须证明其覆盖了无法由既有测试表达的独立回归风险。禁止按 UI 排列、非核心分支、内部实现细节或重复入口滥写测试；重复测试必须合并或删除。UI、视觉与真实交互统一通过 ExampleApp 手工验收。
- 自动化测试只断言外部可观察行为，不断言 private cache、内部 map、具体 UIView identity、精确 frame 或实现分支。
- 最高且主要语义 seam 是 canonical corpus 到语义投影的共享 harness。Attributed、Block、streaming finish 与 SwiftUI integration 使用同一 fixture，不复制测试数据。
- canonical corpus 的最小关键集合包括：inline/reference/autolink/relative/unsafe link；loose list 续段；有序/无序混合嵌套；列表内引用；rich table cell；escaped pipe；空与不齐表格行；表格单元格链接。
- streaming 只为关键边界增加测试：链接 handler 在 finish 前后保持一致；列表和表格 fixture 按 token、空行与表格边界拆分后不丢语义；finish 结果与静态语义投影等价。
- 链接测试覆盖 `.link` destination、安全 scheme、handler `true`/`false` 和 configuration 更新后的 callback；不通过 UIApplication、Safari 或 UI automation 判断成功。
- 表格测试覆盖 parser 结构到 headers/rows/alignments、inline cell semantics、链接 callback 和核心列宽输入；不为每种视觉排列新增测试。
- 列表测试覆盖续段 paragraph style、累计 indent 和混合嵌套归属；不复制每个 marker 与层级组合。
- 响应式自动化复用现有 measurement 与 continuity seams，覆盖初始零宽度、首次有效宽度、同宽 cache、宽度变化重测和状态保留。旋转与 Split View 视觉结果由 ExampleApp 手工检查。
- 图片自动化复用现有 `InkImageStore`、loader、redirect validator、attachment 和 block seams，覆盖默认 host 开放、可选 allowlist、20 MiB 上限、2xx、非图片、重定向、最后订阅取消、inflight 合并、loader identity、relative URL、失败 fallback 和不缓存失败。
- 真实 URLSession 成功路径通过 ExampleApp 使用 `placehold.co`；重定向和真实外部链路使用 `picsum.photos`。第三方服务故障记录为环境失败，不通过修改产品逻辑掩盖。
- 已有图片 Store、安全策略、取消、缓存、附件、Block 与失败 fallback 测试是图片测试先例；只补当前缺失的契约，不重写完整矩阵。
- 已有语义矩阵、render session、stream renderer、SwiftUI view、measurement 和 continuity 测试是跨通道测试先例；新测试应上移到共享 harness，删除因新 seam 产生的重复断言。
- 所有已有 VoiceOver 关键测试保留；本轮不新增 VoiceOver UI test、系统焦点 test 或表格朗读矩阵。
- UI、视觉和真实交互统一通过 ExampleApp 手工验收。矩阵覆盖 iPhone 横竖屏、iPad 全屏、约 1/2 和约 1/3 宽度、Split View 连续拖动、静态与 streaming/promotion、表格横滑与复制、正文/表格/streaming 链接、inline/block 网络图片和失败 fallback。
- 每条人工记录包含候选 commit SHA、ExampleApp 入口、设备、系统、方向、窗口宽度、输入 fixture、操作步骤、预期、实际、PASS/FAIL/BLOCKED，以及必要截图和控制台异常摘要。
- 自动化不新增 UI automation、视觉 snapshot、非核心路径排列测试或重复入口测试。纯视觉差异和手势表现不进入单元测试。
- 构建和测试优先使用 XcodeBuildMCP 与 iOS Simulator destination。记录实际 scheme、destination、逻辑测试数量、失败和跳过原因；历史结果不作为当前候选证据。
- 实现完成后使用 `gpt-5.6-sol` / `max` 且不继承主上下文的独立审查代理，分别复核规范一致性与 spec 一致性；代理结论不能替代当前 checkout 的构建、测试和人工证据。

## Out of Scope

- 删除或重写已有 VoiceOver 行为；
- 新增完整 VoiceOver 朗读体系、表格 accessibility row/column/header tree、系统焦点编排或无障碍 UI automation；
- iOS/iPadOS 14–15 runtime 获取与最低版本实际运行验收；
- 真机 FPS、hitch、内存峰值、WebKit 冷启动和长会话性能基线；
- footnote、directive、GFM bare URL 或完整 HTML renderer；
- 修复 custom inline syntax 在删除线中的已知继承限制；
- streaming 未完成阶段的真实增量网格表格；
- native SwiftUI Markdown renderer、InkIR、Transformer 或第二套 Theme；
- 默认开启图片真图渲染；
- 图片磁盘缓存、持久化缓存治理、隐藏自动重试或 inline 图片点击协议；
- 由库默认制定域名 allowlist 或业务 URL 规则；
- 猜测未提供的图片 `baseURL`；
- 大规模 UI automation、视觉 snapshot 或 exhaustive unit-test matrix；
- 修改 Swift tools、Swift language mode、最低平台声明或其他 Apple 平台范围；
- push、创建或更新 Pull Request、merge、tag 或发布 GitHub Release。

## Further Notes

- 本 spec 服从 ADR-004、ADR-006、ADR-008 与 ADR-009；图片默认占位、opt-in 真图、UIKit-first adapter 和 Block Presentation Continuity 决策保持有效。
- 完整 VoiceOver 已从本轮交付目标移除，但不是宣称“不支持可访问性”。已有行为必须保留，未完成能力进入后续可访问性工作。
- iOS/iPadOS 14–15 runtime 和真机性能仍是 v0.0.2 独立 release blocker；本 spec 完成不代表整个版本可以发布。
- 当前已知实现缺口包括 loose list 续段样式、SwiftUI streaming 链接回调、默认图片 host fail-closed、底层网络取消、网络响应上限和 relative image URL；实现 agent 必须先核对当前源码，不把本 spec 的目标状态误写成已交付事实。
- 当前知识基线中的测试数量存在文档漂移。任何实现完成后的状态更新必须使用当前候选 checkout 的实际结果，不复制旧数量。
- 测试 seam 已由维护者确认：单一 canonical corpus 为主要语义 seam；图片、measurement 和 callback 复用既有最高层 seam；UI 只在 ExampleApp 手工验收，不需要再次访谈。
- 后续使用 `/to-tickets` 将本 spec 拆为依赖清晰、按功能粒度提交的本地 tickets。不得创建 GitHub Issue。
- delegated subagent 不得继承主 agent 上下文。实现代理使用 `gpt-5.6-luna` / `max`；审查代理使用 `gpt-5.6-sol` / `max`。每个 brief 必须自包含仓库路径、约束、spec/ADR 来源、写入范围、证据要求和输出合同。
- 本 effort 只允许本地 commit；未经维护者后续明确授权，不得 push 或创建 Pull Request。
