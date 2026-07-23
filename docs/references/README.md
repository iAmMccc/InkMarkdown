# 依赖 API 参考

API 依赖参考指南，记录项目依赖的关键 API 以及外部库对比。

## 文档索引

| 查询需求 | 文档链接 |
| --- | --- |
| swift-markdown 的解析入口、节点、遍历与改写 | [swift-markdown API 速查](swift-markdown-api-guide.md) |
| Foundation / UIKit 富文本与 TextKit 类型 | [Apple 文本系统 API 速查](apple-text-system-api-guide.md) |
| iOS Markdown 开源库对比 | [iOS Markdown 库定位对比](ios-markdown-ecosystem.md) |
| InkMarkdown 内部模块划分 | [贡献者文档：模块详解](../contributor-guide/05-modules.md) |
| Markdown 节点渲染规范 | [渲染语义规范](../spec/README.md) |

API 速查文档以当前 `Package.swift` 和本地依赖源码为准。上游接口变更时，请先核对依赖版本再同步更新本文档。

外部库对比以各自仓库官方文档、DocC 与源码为准。

官方参考：

- 仓库：[swiftlang/swift-markdown](https://github.com/swiftlang/swift-markdown)（cmark-gfm 驱动）
- 本地缓存（若有）：`Packages/Caches/swift-markdown/`
- DocC：包内 `Sources/Markdown/Markdown.docc`
