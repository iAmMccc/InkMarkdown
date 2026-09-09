# ADR-007：本地生成图片复用所选图片后端

- 状态：Accepted
- 日期：2026-07-29

## 决策

LaTeX 与 Mermaid 只负责把受限输入生成 `UIImage`；它们不得建立自己的位图缓存、任务队列或订阅机制。接入层把输入表示为 `ImageSource(generated:)`，以内容哈希、renderer 版本和样式/主题构造稳定 identity；`DisplayKey` 再加入量化显示宽度、scale 和 content mode。命中、inflight 合并、并发上限与底层取消由所选 `InkImageBackend` 负责，核心 Store 处理呈现订阅、占位与刷新，见 [ADR-012](ADR-012-pluggable-image-management.md)。

LaTeX（iosMath 2.3.1）与 Mermaid（本地固定 `mermaid.min.js` 11.16.0）均为 opt-in：默认不改变普通代码围栏或 Markdown 文本。LaTeX 行内需要调用 `InkConfiguration.enableLaTeXRendering()`；块级 LaTeX/Mermaid 使用 `InkBlockRenderer`。attributed-string-only 通道不能承载块 UIView，因此块内容保留既有文本回退。

## 安全与许可

- Mermaid bridge 只加载 SwiftPM 打包的本地资源，CSP 禁止网络连接，导航委托阻断外部跳转；源码、尺寸和超时均有限制。
- iosMath 依赖：`https://github.com/kostub/iosMath.git`，精确版本 `2.3.1`，product `iosMath`，MIT。其随附数学字体仍受各自字体许可证约束，发布 App 时须一并保留上游 notices。
- Mermaid：`https://github.com/mermaid-js/mermaid`，固定 dist `11.16.0`，MIT；资源内保留许可证与 notice。

## 运行时边界与验收

- generated source 未注入对应 renderer 时必须得到明确的 `generatedLoaderUnavailable` 错误，绝不尝试把 `ink-generated://` 交给 URL loader。
- Kingfisher 后端等待队列有默认上限；满时返回 `ImageLoadError.queueFull`，且最后一个 queued subscription 取消后移除尚未开始的请求。
- 流式 append 会保留未闭合的 `$$`、`$...$`、`\\(...\\)` 和 Mermaid fence；转义分隔符及代码区域不触发该缓冲。`finish()` 始终按完整 Markdown 文本安全降级。
- generated identity 使用 SHA-256，包含 owner、renderer 版本、输入和样式；`DisplayKey` 仍负责显示尺寸维度。
- `DisplayContext` 在构造时规范化非有限、非正和过大宽度/scale，并将小于 1 的 scale 收紧为 1（UIKit display scale 语义）；有效的常规 1x/2x/3x 输入保持原值，后续 `DisplayKey` 不会对 NaN、无穷或危险范围执行 `Int` 转换。

## 后续

WebKit snapshot 在最低支持系统与实际 App 宿主上的稳定性仍需验收；磁盘缓存由所选后端配置，本决策不引入网络 Mermaid 插件。
