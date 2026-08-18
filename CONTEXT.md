# InkMarkdown — Domain Glossary

> 仅收录跨文档/跨模块复用的领域术语。不含实现细节、API 清单或路线图。

## 公式与图表

用户可见总称：涵盖 LaTeX 数学公式与 Mermaid 图表两类本地生成内容。ExampleApp 入口文案统一使用本词。

## 生成内容

库与代码层用语，对应 `ImageSource(generated:)` / generated image：由 LaTeX 或 Mermaid renderer 产出位图，经统一 `InkImageStore` 管理，而非网络 URL 图片。

## 开启态 / 关闭态

opt-in 对照。开启态：`latexRendering.isEnabled` / `mermaidRendering.isEnabled` 为真，公式与图表渲染为位图。关闭态：保持默认关闭，围栏/公式源码按普通 Markdown 展示，用于对照演示。

## 单块闭合即渲染

流式场景下，块级围栏（如 ` ```mermaid `）或块级公式（`$$` / `\[...\]`）一旦在源文本中闭合，该块立即进入异步生图，无需等待整条 SSE 流结束（`[DONE]`）。允许后文仍在吐字、前文已出图。

## 渲染会话

流式 Markdown 从接收分片开始，到取消、重置或终态块可交互为止的一次呈现生命周期。会话拥有该次呈现的内容真相和阶段语义；网络传输与应用业务状态不属于会话。
