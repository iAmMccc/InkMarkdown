# InkMarkdown 综合渲染样例

**InkMarkdown** 基于 Apple [swift-markdown](https://github.com/swiftlang/swift-markdown)，将 Markdown 渲染为 UIKit 原生 `NSAttributedString` 与块级 `UIView`。

> 此样例用于验证长文中的标题、强调、链接、引用、列表、删除线、代码块和表格。已发布的 `0.0.1` 是 UIKit-first public beta；计划中的 `0.0.2` 将以独立 adapter product 支持 SwiftUI 宿主，复用同一套渲染语义。

## 行内语法

这是 **粗体**、*斜体*、`inline code`、~~删除线~~ 与 [InkMarkdown 仓库](https://github.com/iAmMccc/InkMarkdown) 链接的组合。

## 列表与引用

1. 解析层使用 `swift-markdown` 生成 Markup。
2. 富文本元素进入 `NSAttributedString` 通道。
3. 表格、代码块与分割线等内容由 block router 创建 UIKit 视图。

- `InkConfiguration` 聚合一次渲染的配置与扩展点。
- `InkAppearance` 定义可复用的视觉属性。
- 流式内容由渲染器增量呈现，宿主负责业务传输。

> UIKit 与计划中的 SwiftUI adapter 共享 Markdown 语义；SwiftUI adapter 不会复制 parser 或 renderer。

## 代码块

```swift
let markdown = "# Hello, InkMarkdown"
let blocks = InkBlockRenderer.render(markdown)
```

## 表格

| 能力 | 当前 UIKit engine | v0.0.2 目标 |
| --- | --- | --- |
| 富文本 | `NSAttributedString` | 由 SwiftUI adapter 托管 |
| 块级组件 | 代码块、表格、分割线 | 复用现有 UIKit block |
| 流式渲染 | 增量 renderer | 通过 render session 绑定 |

---

*此页仅是渲染样例，不替代公开 interface 文档或性能基线。完整状态见 `docs/current-status.md`。*
