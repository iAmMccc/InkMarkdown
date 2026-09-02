# InkMarkdown 当前任务摘要

> 摘要日期：2026-09-01。本文是本任务的唯一当前摘要。后续执行先读取本文，再核对 `docs/current-status.md`、源码和最新测试证据。旧聊天打印、原始审查快照、已完成参考和失败的代理状态不作为当前事实。

## 当前目标

- 完成 v0.0.2 SwiftUI adapter 审查缺陷的根因修复与重构，保持 UIKit rendering engine 与 SwiftUI adapter 共享同一渲染语义。
- 解决公开 API、Block 复用、配置差异检测、流式生命周期、图片/公式/图表 addon、Dynamic Type、并发边界和 ExampleApp 编译问题。
- 以可验证证据收口文档：当前事实、已解决项、剩余 blocker 和踩坑规则必须彼此一致。
- 后续变更必须从本摘要定义的范围出发，不恢复已否决的方案或重复输出历史过程。

## 核心约束

- UIKit-first：`InkMarkdown` 保持 UIKit rendering engine；SwiftUI 只能通过独立 `InkMarkdownSwiftUI` adapter 接入。本任务不引入 native SwiftUI renderer、InkIR 或第二套 Theme。
- 目标平台为 iOS 14+ / iPadOS 14+，不承诺其他 Apple 平台；部署声明不等于最低版本运行验证。
- Swift tools 6.2，包内保持 Swift 5 language mode；构建/测试优先使用 XcodeBuildMCP，并使用 iOS Simulator destination。
- 方案必须修复共享边界上的根因，不增加只覆盖当前症状的补丁逻辑；保留 0.0.1 已发布 API 的源兼容性。
- 不透明闭包、loader、Store 和回调不能通过 nil 性或哈希猜测相等；未知扩展必须保守处理。
- 公开 API 需要中文文档注释；README 改动必须同步中英文；不提交依赖缓存、DerivedData 或凭据。
- 需要委派时，子代理不继承主代理上下文；执行代理使用 `gpt-5.6-luna` / `max`，审查代理使用 `gpt-5.6-sol` / `max`。子代理状态不等同于工程验证。

## 已确认决策

- 以 `InkSemanticIdentity` + `InkSemanticComparator` 作为配置、回调、loader 和扩展的统一语义身份 seam。显式 setter 允许稳定 identity；直接重新赋值保守地产生新 identity。
- `InkRenderableBlock` 保持普通消费者可实现的最小接口；可复用内置/第三方块通过可选 `InkReusableBlock` 提供完整比较和显式更新，未知类型不得 fatal。
- Block 复用必须比较完整 presentation state：富文本属性/附件、代码与表格样式、Thought 完成/折叠态、图片 source/rendering/Store identity；无法证明安全更新则重建。
- SwiftUI Coordinator 只在 Markdown 或配置语义真正变化时重建；布局生命周期保持纯粹，`layoutSubviews()` 不触发递归 intrinsic-size 更新。
- 空 Session 绑定必须覆盖旧 text storage；同一批流式输入的多个 dirty slot 必须可组合；Thought 的完成态和折叠态属于 presentation state。
- 图片 attachment 的 nonisolated 测量回调保持纯函数；addon registry 通过单一加锁状态容器管理。
- LaTeX/Mermaid 必须显式链接 product、import、register，再开启渲染；核心未注册时明确失败，不依赖反射或隐式 Bundle 回退。
- 历史审查快照仅供追溯；2026-09-02 当前候选门禁以 [interaction acceptance 2026-09-02](InkMarkdown-interaction-acceptance-2026-09-02.md) 为 SSOT，再由 `docs/current-status.md` 摘要引用。

## 当前进度

- 原审查 12 项缺陷已完成代码收口；另完成表格重配清理、图片缓存完成边界、统一语义 identity、Mermaid runtime seam 和新增回归测试等系统性补强。
- 2026-08-28 历史候选曾恢复 ExampleApp 编译；该结果不充当 2026-09-02 当前工作树证据。公开 Block API、配置比较、流式生命周期、图片旧订阅取消、新结果展示和 addon 注册边界已有回归覆盖。
- 文档已同步：中英文 README、当前状态、架构/风险基线、FAQ、SwiftUI/UIKit 踩坑指南和审查修复记录。旧审查文件已标记为历史快照；ADR-002 已标记为被 ADR-008 supersede。
- 已新增 19 项 CommonMark/GFM 语义矩阵测试，并在共享 `InkTextContext` seam 修复多级列表累计缩进；标准 `<URL>` 与当前不支持的 GFM 裸 URL 回退边界已与固定版 `swift-markdown` 保持一致。
- `maximumSourceLength` 已通过 renderer/session initializer 开放配置：默认 50,000，创建时固化不可变 snapshot，append、reset、finish 与 promotion 共用同一 canonical source。
- 已建立代码级性能门槛与可复现基线文档；聚焦语义、长度与性能测试 37/37 通过。
- 本轮 review remediation 已收口：internal `InkPreparedMarkdownSource` 保证一次顶层 source filter 覆盖 Block 构造、Thought view 创建/复用与 suffix；promotion 后环境变化经 session-to-host display seam 刷新；复用 Thought 会完整协调折叠能力；Thought 富文本 fallback 只补缺失背景；公开 API 文档、DEBUG-only Unified Logging、import、测试命名与 Swift 2-space 格式规范已对齐。
- Tickets 01–05（canonical corpus / 列表 / 表格 / 链接 / 测量）已在 `8fb1640` 提交。Tickets 06–07（图片业务策略默认开放、相对 URL、有界可取消网络加载、loader identity）实现与测试已在工作树完成，**尚未 commit**。
- 2026-09-02 本地候选：`InkMarkdown-Package` @ iPhone 17 Pro / iOS 26.5 由 XcodeBuildMCP 验证 333 通过、0 失败、1 跳过（iOS 14 ICS）；有效 diff 的 `git diff --check` 通过。证据见 [interaction acceptance 2026-09-02](InkMarkdown-interaction-acceptance-2026-09-02.md)。
- FAQ / README / current-status / CHANGELOG 已去掉「开启真图后仍 fail-closed」的过时表述，改为 ADR-006 业务策略默认开放。

## 未解决问题

- ExampleApp Debug 本轮在编译前 **BLOCKED**（`gitconfig` github 代理 `127.0.0.1:6152` 失效，依赖无法解析）；Release 因相同前置条件未重复执行。真网 `placehold.co` / `picsum.photos`、旋转、Split View 人工矩阵未执行。
- iOS/iPadOS 14–15 runtime、真机性能、完整 VoiceOver 仍为独立 release blocker。
- 远端 CI / push / PR 未授权，不得写成已通过。

## 下一步计划

1. 修复本机 git github 代理或改用可用网络后，完成 ExampleApp Debug/Release 构建与 ticket 08 真网/旋转/Split View 走查，更新同一证据文件。
2. 维护者授权后再 push / 更新 PR，并以同一候选 SHA 跑远端 CI。
3. 获取 iOS/iPadOS 14–15 runtime 与真机性能基线。
4. 图片与交互改动经维护者确认后再按功能粒度本地 commit（当前明确要求暂不 commit）。
