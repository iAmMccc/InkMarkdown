# InkMarkdown 文档

以源码和 `Package.swift` 为准。文档和代码打架时，改文档。

## 怎么找

| 目录 | 写什么 |
| --- | --- |
| [roadmap.md](roadmap.md) | 做成什么样、现在到哪、后面怎么走 |
| [contributor-guide/](contributor-guide/01-overview.md) | 架构、原理、怎么开发 |
| [references/](references/README.md) | swift-markdown 怎么用 |
| [spec/](spec/README.md) | 各语法渲染成什么样子 |

建议顺序：roadmap → 概述 → 架构 → 开发；其余按需。

## 别当现行事实

| 文件 | 常见过时内容 |
| --- | --- |
| `AGENTS.md` / `Claude.md` | 本地 path 依赖、SmartCodable、多平台、项目还在初始化 |
| `TABLE_INTEGRATION_GUIDE.md` | 旧 table factory API |

现行约定：

- 依赖：远程 `swiftlang/swift-markdown`（`branch: main`）
- 平台：仅 iOS 14+
- UI：UIKit 已有；SwiftUI 在路线图
- 文本绘制：默认 TextKit 1
- 扩展：`InkBlockHandler` / `InkInlineSyntax` / `InkConfiguration`
