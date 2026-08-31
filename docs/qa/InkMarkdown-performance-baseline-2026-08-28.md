# InkMarkdown v0.0.2 性能基线

> 日期：2026-08-28。本文记录可复现的代码级门槛与本机证据，不把 Simulator 数据冒充真机结论。

## 范围与结论

本轮覆盖 SwiftUI adapter 的静态长文测量、流式追加、终态 promotion、Thought 视图身份、Dynamic Type 重测，以及 UIKit core 的增量渲染比例与大文档 block 吞吐。

代码级走查未发现新的全树更新风暴：

- 静态入口按 Markdown、配置语义、内容尺寸类别和文档 epoch 幂等去重。
- 容器按 block identity 复用视图，只使内容变化的 slot 失效。
- 测量缓存以 block identity、宽度和环境为边界；`layoutSubviews()` 只消费测量结果，不递归失效 intrinsic size。
- 流式入口只在 display update 时更新 Thought / 文本 dirty slot；SwiftUI 不观察高频 session state。
- promotion 直接消费 session 已生成的 blocks，不重新解析终态 Markdown。

这些结论证明更新边界合理，不等于真机 FPS、hitch、内存峰值或 WebKit 冷启动已达标。

## 自动化门槛

| 场景 | 契约 | 测试入口 |
| --- | --- | --- |
| 增量结果一致性 | 流式结果等于全量渲染结果 | `StreamingPerformanceTests.incremental_renderOutputMatchesFullRender` |
| 增量成本 | 增量解析耗时低于全量循环的 30% | `StreamingPerformanceTests.incremental_renderIsFasterThanFullRender` |
| 大文档 block 吞吐 | 既有固定样本在 500 ms 内完成 | `StreamingPerformanceTests.largeDocument_blockRenderThroughput` |
| 静态长文测量 | 超过 60 个 block；同宽第二次测量不再调用子视图测量 | `InkMarkdownAdapterWorkloadTests.staticLongDocumentMeasurementBudget` |
| 100 分片追加 | 追加期间不提前 promotion，display update 有界 | `InkMarkdownAdapterWorkloadTests.streamingChunkAppendWorkloadBudget` |
| promotion 身份 | Thought 从流式切终态后保留视图身份 | `InkMarkdownAdapterWorkloadTests.promotionWorkloadPreservesThoughtIdentity` |
| 静态更新复用 | 等价输入不重建 block view | `InkMarkdownPerformanceBaselineTests.staticUpdateReusesBlockViews` |
| Dynamic Type | 内容尺寸类别改变后触发重新测量 | `InkMarkdownPerformanceBaselineTests.dynamicTypeChangeTriggersRemeasure` |

## 本轮运行证据

- 工具：XcodeBuildMCP。
- Scheme：`InkMarkdown-Package`。
- Destination：iPhone 17 / iOS 26.5 Simulator。
- 聚焦门禁：语义矩阵、source limit、UIKit 增量性能、SwiftUI adapter workload 与 performance baseline，共 37 项，37 通过、0 失败、0 跳过；耗时约 26.3 秒。
- 全量门禁（最终 checkout）：共 340 项，339 通过、0 失败、1 跳过；跳过项为本机缺少 iOS 14 runtime 的兼容性检查；耗时约 37.5 秒。
- ExampleApp：同一 iPhone destination 在最终代码上重新构建并启动成功。

结果 bundle：

- 聚焦：`/Users/shizihan/Library/Developer/XcodeBuildMCP/workspaces/InkMarkdown-124472009cd9/result-bundles/test_sim_2026-08-28T02-59-30-631Z_pid7839_405c7589.xcresult`
- 全量：`/Users/shizihan/Library/Developer/XcodeBuildMCP/workspaces/InkMarkdown-124472009cd9/result-bundles/test_sim_2026-08-28T03-05-57-511Z_pid7839_c5d1f3a2.xcresult`

本轮数据只证明 Simulator 上的自动化门槛通过。没有把整个 suite 的 wall-clock 时间拆成单项产品性能，也没有将其作为用户侧延迟指标。

## 真机基线协议

发布前必须在至少一台真实 iPhone 与一台真实 iPad 上记录：

1. 静态长文：首次呈现时间、快速滚动 hitch、内存峰值。
2. 长会话流式：100、1,000 与接近 source limit 的 chunk 序列；记录 CPU、hitch、峰值内存和 promotion 延迟。
3. 图片 / ReservedHeight：缓存冷启动、命中、取消、快速复用与尺寸回填。
4. LaTeX / Mermaid：WKWebView 冷启动、连续生成、页面进程终止后的单次重试。
5. Dynamic Type、旋转、iPad Split View：宽度变化后的重测次数和视觉稳定性。

采样时保留 Instruments trace、设备型号、系统版本、构建配置、样本 Markdown 与操作步骤。未同时具备这些元数据的数据不能进入发布宣传。

## 当前阻塞

- 本机已连接的物理 iPhone / iPad 均处于不可用状态，不能采集真实设备数据。
- ETTrace runner/framework 未安装；本机只有 Instruments Time Profiler、Allocations、Leaks 与 SwiftUI 模板。
- 因此本轮最多形成 Simulator 自动化与代码级门槛，真机 FPS、hitch、内存峰值、WebKit 冷启动和长会话基线仍是 release blocker。
