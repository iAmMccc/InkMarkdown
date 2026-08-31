# InkMarkdown 当前任务摘要

> 摘要日期：2026-08-31。本文是本任务的唯一当前摘要。后续执行先读取本文，再核对 `docs/current-status.md`、源码和最新测试证据。旧聊天打印、原始审查快照、已完成参考和失败的代理状态不作为当前事实。

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
- 历史审查快照仅供追溯；当前事实以本摘要、`docs/current-status.md`、源码和最新结构化测试结果为准。

## 当前进度

- 原审查 12 项缺陷已完成代码收口；另完成表格重配清理、图片缓存完成边界、统一语义 identity、Mermaid runtime seam 和新增回归测试等系统性补强。
- ExampleApp 已恢复编译；公开 Block API、配置比较、流式生命周期、图片旧订阅取消、新结果展示和 addon 注册边界已有回归覆盖。
- 文档已同步：中英文 README、当前状态、架构/风险基线、FAQ、SwiftUI/UIKit 踩坑指南和审查修复记录。旧审查文件已标记为历史快照；ADR-002 已标记为被 ADR-008 supersede。
- 已新增 19 项 CommonMark/GFM 语义矩阵测试，并在共享 `InkTextContext` seam 修复多级列表累计缩进；标准 `<URL>` 与当前不支持的 GFM 裸 URL 回退边界已与固定版 `swift-markdown` 保持一致。
- `maximumSourceLength` 已通过 renderer/session initializer 开放配置：默认 50,000，创建时固化不可变 snapshot，append、reset、finish 与 promotion 共用同一 canonical source。
- 已建立代码级性能门槛与可复现基线文档；聚焦语义、长度与性能测试 37/37 通过。
- 本轮 review remediation 已收口：顶层 source filter 只执行一次；promotion 后环境变化经 session-to-host display seam 刷新；复用 Thought 会完整协调折叠能力；Thought 富文本 fallback 只补缺失背景；公开 API 文档、DEBUG-only Unified Logging、测试命名与 Swift 2-space 格式规范已对齐。
- XcodeBuildMCP 全量验证：iPhone 16 Pro / iOS 18.5，共 336 项，335 通过、0 失败、1 跳过（本机无 iOS 14 runtime）。聚焦关键链路另有 60/60 通过；ExampleApp 同目的地构建、安装并启动成功，deployment target 为 iOS 14.0。
- ExampleApp 手工验收已覆盖 Thought 卡片范围、inline code 背景、suffix 边界、可折叠能力 false↔true、流式折叠/追加/宽度/卸载重挂、promotion 后特大字号即时刷新与折叠态保留。
- `git diff --check` 已通过。当前分支为 `feat/swiftUI`；实现、测试与格式已按功能拆为 `6727f84`、`c1c607c`、`c2fa371`、`8002432`、`9984baf`，本文与本地票据归入最终证据 commit。全部本轮改动提交后工作树 clean；本任务未执行远端 push。

## 未解决问题

- iOS/iPadOS 14–15 runtime、旋转、Split View、无初始宽度协商尚未验证。
- ExampleApp 的 Mermaid 已在 iPhone SwiftUI 组件页可见；LaTeX Demo 输入根因已修正并重建，但块公式修正后的可见复核、图片 ReservedHeight、表格横向交互、链接、系统级 Dynamic Type 与 VoiceOver 仍缺完整走查。本轮只完成 Thought 与 promotion 环境刷新的关键手工链路。
- 真机 FPS、hitch、内存峰值、WebKit 冷启动和长会话性能基线尚未建立。
- 首批 CommonMark/GFM 语义矩阵已落地；引用链接、列表续段/混合嵌套、复杂表格单元格、跨富文本/Block/流式通道完整矩阵仍未完成。自定义 inline syntax 的删除线继承仍是已知契约限制。
- 当前证据不足以宣布 v0.0.2 已发布或已完成最低版本支持。

## 下一步计划

1. 以本摘要为入口，先核对当前源码、`current-status.md` 和最新 XcodeBuildMCP 结果；跳过旧聊天、历史快照和已完成的重复打印。
2. 获取可用的 iOS/iPadOS 14–15 runtime 或设备，完成最低版本、旋转、Split View 与宽度协商验证。
3. 按 ExampleApp 走查报告复核块公式修正，完成图片、表格横向交互、链接、系统级 Dynamic Type 和可访问性人工验收，并记录复现证据；保留本轮已完成的 Thought/promotion 关键链路证据。
4. 建立真机性能基线，覆盖滚动、流式长文、图片/生成图加载、WebKit 冷启动、内存峰值和长会话。
5. 扩充 CommonMark/GFM 语义矩阵至引用链接、混合嵌套、复杂表格与跨渲染通道；保持 GFM 裸 URL 的当前回退边界，除非上游解析层正式提供 autolink 扩展。
6. 每个后续阶段完成后，只更新本摘要、`current-status.md` 与对应证据文档；达到所有 blocker 退出标准后再讨论发布与提交拆分。
