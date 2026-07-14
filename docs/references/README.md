# 依赖 API 参考

这是 Reference 文档。实现时查依赖 API，不在这里学习项目架构或决定 UIKit 的显示语义。

## 从哪里开始

| 你要查什么 | 文档 |
| --- | --- |
| swift-markdown 的解析入口、节点、遍历和改写 | [swift-markdown API 速查](swift-markdown-api-guide.md) |
| Foundation / UIKit 富文本与 TextKit 类型 | [Apple 文本系统 API 速查](apple-text-system-api-guide.md) |
| swift-markdown、MarkdownUI、Textual、SwiftStreamingMarkdown 的公开边界 | [iOS Markdown 库定位对比](ios-markdown-ecosystem.md) |
| InkMarkdown 的模块职责 | [贡献者文档：模块详解](../contributor-guide/05-modules.md) |
| Markdown 节点应该怎样显示 | [渲染语义规范](../spec/README.md) |

API 速查以当前 `Package.swift` 和本地源码为边界。上游类型变化后，先核对依赖版本，再更新本目录。

Apple 类型以 Apple Developer Documentation 为准；外部库对比以对应仓库的 README、DocC、manifest 和公开源码为准。二手索引只用于定位原始来源。

官方来源：

- 仓库：[swiftlang/swift-markdown](https://github.com/swiftlang/swift-markdown)（cmark-gfm 驱动）
- 本地缓存（若有）：`Packages/Caches/swift-markdown/`
- DocC：包内 `Sources/Markdown/Markdown.docc`
