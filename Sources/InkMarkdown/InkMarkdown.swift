// InkMarkdown — Markdown 解析与 UIKit 渲染库的模块入口。
//
// 对外渲染入口分别位于 InkAttributedRenderer、InkBlockRenderer 与 InkStreamRenderer。
// 这里 re-export swift-markdown，让宿主使用 Markup 扩展点时无需单独链接 Markdown target。

@_exported import Markdown
