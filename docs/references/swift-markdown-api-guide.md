# swift-markdown API 速查

基于 [swiftlang/swift-markdown](https://github.com/swiftlang/swift-markdown)（解析器为 cmark-gfm）。InkMarkdown **不重写解析**，扩展点基于这些类型构建。

本地参考：`Packages/Caches/swift-markdown/`（有缓存时）。升级依赖后同步本页。

## 1. 渲染管线

```text
Markdown 文本
  → Document(parsing:options:)
  → Markup 不可变树
  → InkAttributedRenderer / InkBlockRenderer
  → NSAttributedString / UIView 块
```

## 2. 类型层级

```text
Markup
├─ BlockMarkup
│  ├─ BlockContainer（BlockQuote, ListItem, Document…）
│  ├─ InlineContainer 块（Heading, Paragraph…）
│  └─ 叶块（CodeBlock, ThematicBreak, HTMLBlock）
└─ InlineMarkup
   ├─ InlineContainer（Emphasis, Strong, Link…）
   └─ 行内叶（Text, InlineCode, LineBreak…）
```

| 协议 | 含义 |
| --- | --- |
| `BlockContainer` / `InlineContainer` | 子节点是块 / 行内 |
| `BasicBlockContainer` / `BasicInlineContainer` | 带默认 children 实现 |
| `ListItemContainer` | 子节点为 `ListItem` |
| `PlainTextConvertibleMarkup` | `plainText` |
| `LiteralMarkup` | `literal` |

## 3. 解析

```swift
import Markdown

let doc = Document(parsing: "# Hello\n\nSome **text**.")
let doc2 = Document(parsing: "...", source: URL(fileURLWithPath: "x.md"))
let doc3 = try Document(parsing: fileURL)
let doc4 = Document([Paragraph(Text("x")), Heading(level: 2, Text("T"))])
```

### `ParseOptions`（OptionSet）

| 选项 | 作用 |
| --- | --- |
| `.parseBlockDirectives` | `@Directive` 块指令 |
| `.parseSymbolLinks` | 双反引号符号链接 → `SymbolLink` |
| `.disableSmartOpts` | 关闭智能标点（默认 **开启** SMART） |
| `.parseMinimalDoxygen` | 最小 Doxygen；依赖 `.parseBlockDirectives` |
| `.disableSourcePosOpts` | 关闭 cmark `CMARK_OPT_SOURCEPOS`（默认 **开启** sourcepos → `node.range` 通常有值） |

默认 `[]`：标准 GFM + smart + sourcepos。InkMarkdown 默认不传额外选项。不要随意开启 directive/doxygen，避免生成未经处理的节点。

> 默认包含 source location。需要关闭时显式指定 `.disableSourcePosOpts`。

## 4. AST 遍历

| 方式 | 协议 | Result | 场景 |
| --- | --- | --- | --- |
| 递归 `children` | — | — | 读取属性、简单遍历 |
| Visitor | `MarkupVisitor` | 任意 | 收集或转换 |
| Walker | `MarkupWalker` | `Void` | 带有副作用的遍历 |
| Rewriter | `MarkupRewriter` | `Markup?` | 修改 AST 树；`nil` 表示删除节点 |

`MarkupWalker.defaultVisit` 会自动调用 `descendInto` 递归。自定义 `visitX` 如需继续深入下钻，需自行调用 `descendInto`。

```swift
// children
for child in node.children { ... }

// Visitor
struct LinkCollector: MarkupVisitor {
  typealias Result = [String]
  mutating func defaultVisit(_ markup: Markup) -> [String] {
    markup.children.flatMap { $0.accept(&self) }
  }
  mutating func visitLink(_ link: Link) -> [String] {
    [link.destination ?? ""] + defaultVisit(link)
  }
}
var c = LinkCollector()
let urls = doc.accept(&c)

// Walker
struct Printer: MarkupWalker {
  mutating func visitHeading(_ heading: Heading) {
    print("H\(heading.level)")
    descendInto(heading)
  }
}
```

## 5. 节点支持情况

状态分类：已渲染 · 降级处理 · 未处理

### 块级节点

| 类型 | 关键属性 | InkMarkdown 状态 |
| --- | --- | --- |
| `Document` | children | 入口 |
| `Paragraph` | 行内子节点 | 已渲染 |
| `Heading` | `level` 1…6 | 已渲染（区分 H1 与 H2–H6 字号） |
| `BlockQuote` | 块子节点 | 已渲染：左侧竖线 + 缩进 |
| `OrderedList` / `UnorderedList` | `ListItem` | 已渲染 |
| `ListItem` | `checkbox: Checkbox?` | 已渲染：支持 Task List |
| `CodeBlock` | `code`、`language?` | 已渲染：富文本 + UIView |
| `ThematicBreak` | — | 已渲 |
| `Table` / Head / Body / Row / Cell | 对齐、单元格 | 已渲染：UIView 块；单元格调用 `format()` 渲染内联 |
| `HTMLBlock` | literal | 忽略 |
| `CustomBlock` / `BlockDirective` / `Doxygen*` | — | 未独立处理；可通过 `InkBlockHandler` 扩展 |

### 行内节点

| 类型 | 关键属性 | InkMarkdown 状态 |
| --- | --- | --- |
| `Text` | `string` | 已渲染，支持 `InkInlineSyntax` 扫描 |
| `Emphasis` / `Strong` | 行内子节点 | 已渲染：斜体 / 加粗 |
| `Link` | `destination?`、`title?` | 已渲染：链接颜色 + `linkTapHandler` |
| `Image` | `source?`、alt 子节点 | 默认：降级为 `[🖼 …]` 占位；opt-in（`InkImageRendering.isEnabled`）：真图附件/块，见 [ADR-006](../decisions/ADR-006-opt-in-image-rendering.md) |
| `InlineCode` | code | 已渲染：等宽字体 + 背景色 |
| `Strikethrough` | 行内子节点 | 已渲染：文本与行内代码写入 `.strikethroughStyle`；自定义 `inlineSyntaxes` 与图片叶子节点不保证该属性，见 [扩展语法](../spec/extended-syntax.md) |
| `LineBreak` / `SoftBreak` | — | 已渲染：`\n` / 空格 |
| `InlineHTML` | rawHTML | 降级：`<br>` 转换为换行；丢弃自定义标签 |
| `CustomInline` / `SymbolLink` / `InlineAttributes` | — | 未独立处理 |

## 6. 提取内容

```swift
(heading as? Heading)?.level
(code as? CodeBlock).map { ($0.code, $0.language) }
(link as? Link).map { ($0.destination, $0.title) }
(image as? Image).map { ($0.source, $0.plainText) }
(text as? Text)?.string

if let table = node as? Table {
  let headers = table.head.cells
  let rows = table.body.rows
}

if let item = node as? ListItem, let box = item.checkbox {
  // .checked / .unchecked
}
```

当容器节点没有直接提供 `.string` 时：

```swift
// 提取纯文本
func plainText(of node: Markup) -> String {
  if let t = node as? Text { return t.string }
  return node.children.map { plainText(of: $0) }.joined()
}

// 保留 Markdown 标记（InkTableBlock 实现）
cell.children.map { $0.format() }.joined()
```

## 7. 格式化与改写

```swift
let md = doc.format()                       // MarkupFormatter
let html = HTMLFormatter.format(doc)        // 静态方法
print(doc.debugDescription())               // 输出调试树
```

```swift
struct EmphasisToStrong: MarkupRewriter {
  mutating func visitEmphasis(_ emphasis: Emphasis) -> Markup? {
    Strong(emphasis.children)
  }
}
var rw = EmphasisToStrong()
let newDoc = rw.visit(doc)   // Markup?
```

渲染管线默认未挂载 Rewriter。如需修改 AST，请在传入渲染器前处理。

## 8. 扩展点接入

### `InkBlockHandler`（块节点 → UIView）

```swift
struct MyTableHandler: InkBlockHandler {
  func canHandle(_ markup: Markup) -> Bool { markup is Table }
  func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let table = markup as? Table else { return nil }
    return InkTableBlock.from(table, layoutMode: .wrap, configuration: configuration)
  }
}
```

### `InkInlineSyntax`（行内文本解析）

```swift
struct MentionSyntax: InkInlineSyntax {
  func render(text: String, context: InkInlineContext) -> NSAttributedString? {
    guard text.contains("@") else { return nil }
    return NSAttributedString(string: text, attributes: [
      .font: context.baseFont,
      .foregroundColor: context.textColor,
    ])
  }
}
```

注意：`Image` 为行内节点。渲染图片需通过行内路径或预处理，`InkBlockHandler` 无法拦截行内节点。

## 9. 注意事项

1. **不可变与 COW**：修改节点会返回新树，只读遍历在多线程下安全。
2. **节点标识**：无法以引用相等作为唯一标识。
3. **Source Location**：默认包含源码位置信息；可通过 `.disableSourcePosOpts` 关闭。
4. **未知节点**：HTML / Doxygen / SymbolLink 等需做降级或忽略处理，防止漏渲染。
5. **版本一致性**：依赖参照 `Package.resolved`，升级后需核对与更新本文档。
