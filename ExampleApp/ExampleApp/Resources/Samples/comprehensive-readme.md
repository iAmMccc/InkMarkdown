# InkMarkdown

**InkMarkdown** 是基于 Apple [swift-markdown](https://github.com/apple/swift-markdown) 的 Markdown 解析与 **UIKit 渲染**库，目标是在 iOS 14+ 上提供可主题化、可扩展的 `NSAttributedString` 输出。

## 特性

- CommonMark 0.31 严格集作为**最小渲染集合**
- 解析层复用 swift-markdown（cmark-gfm），与 AST 语义对齐
- UIKit 原生：链接可点击、文本可选中复制
- 后续支持 GFM 扩展与自定义 Theme（见 `docs/spec`）

## 快速开始（规划）

```swift
import InkMarkdown

// 渲染器落地后预期 API：
// let attr = InkMarkdown.render(markdown, theme: .default)
// textView.attributedText = attr
```

当前 ExampleApp 使用 **HTMLFormatter 占位渲染**，仅作视觉基线，非最终路径。

## 项目结构

```
InkMarkdown/
├── Sources/InkMarkdown/     # 库源码
├── ExampleApp/              # 本演示 App
├── docs/spec/               # 语法规范
└── docs/references/         # 三方库参考
```

## 引用与链接

> 设计目标：让 Markdown 在邮件、笔记、帮助文档场景中**可读、可选、可点击**。

详见 [CommonMark Spec](https://spec.commonmark.org/0.31.2/) 与仓库内 `docs/spec/common-syntax.md`。

![项目示意图](https://via.placeholder.com/200x48.png?text=InkMarkdown)

## 待办

1. 实现 Markup → NSAttributedString 渲染管线
2. Theme 体系（字体、颜色、段落间距）
3. GFM 扩展（表格、任务列表、删除线）

---

*本页为综合样例，混排标题、列表、代码、引用、链接与强调，用于检验长文观感。*
