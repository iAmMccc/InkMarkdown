# swift-markdown API 速查

基于 [swiftlang/swift-markdown](https://github.com/swiftlang/swift-markdown)（解析器为 cmark-gfm）。InkMarkdown **不重写解析**，扩展点建在这些类型上。

本地可对读：`Packages/Caches/swift-markdown/`（有缓存时）。升级依赖后回写本页。

## 1. 在管线里的位置

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

默认 `[]`：标准 GFM + smart + sourcepos。InkMarkdown 默认不传额外选项。不要为了「省事」乱加 directive/doxygen——会产出本库未处理的节点。

> 默认会记录 source location。要关掉须显式 `.disableSourcePosOpts`。

## 4. 遍历

| 方式 | 协议 | Result | 场景 |
| --- | --- | --- | --- |
| 递归 `children` | — | — | 取属性、简单走树 |
| Visitor | `MarkupVisitor` | 任意 | 收集 / 转换 |
| Walker | `MarkupWalker` | `Void` | 副作用遍历 |
| Rewriter | `MarkupRewriter` | `Markup?` | 改树；`nil` = 删除 |

`MarkupWalker.defaultVisit` **会** `descendInto`（递归）。自定义 `visitX` 若要继续下钻，自己调 `descendInto`。

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

## 5. 节点 × InkMarkdown

状态：已渲 · 降级 · 未专门处理

### 块

| 类型 | 关键属性 | InkMarkdown |
| --- | --- | --- |
| `Document` | children | 入口 |
| `Paragraph` | 行内子节点 | 已渲 |
| `Heading` | `level` 1…6 | 已渲（H1 与 H2–H6 两档字号） |
| `BlockQuote` | 块子节点 | 已渲：竖线 + 缩进 |
| `OrderedList` / `UnorderedList` | `ListItem` | 已渲 |
| `ListItem` | `checkbox: Checkbox?` | 已渲：任务列表 |
| `CodeBlock` | `code`、`language?` | 已渲：富文本 + UIView |
| `ThematicBreak` | — | 已渲 |
| `Table` / Head / Body / Row / Cell | 对齐、单元格 | 已渲：UIView 块；单元格经 `format()` 再渲内联 |
| `HTMLBlock` | literal | 忽略 |
| `CustomBlock` / `BlockDirective` / `Doxygen*` | — | 未专门处理；可用 `InkBlockHandler` |

### 行内

| 类型 | 关键属性 | InkMarkdown |
| --- | --- | --- |
| `Text` | `string` | 已渲 + `InkInlineSyntax` 扫描 |
| `Emphasis` / `Strong` | 行内子节点 | 已渲：italic / bold |
| `Link` | `destination?`、`title?` | 已渲：色 + `linkTapHandler` |
| `Image` | `source?`、alt 子节点 | 降级：`[🖼 …]` 占位 |
| `InlineCode` | code | 已渲：等宽 + 背景 |
| `Strikethrough` | 行内子节点 | 降级：有文本、无删除线样式 |
| `LineBreak` / `SoftBreak` | — | 已渲：`\n` / 空格 |
| `InlineHTML` | rawHTML | 降级：`<br>`→换行；空自定义标签丢弃；其余空 |
| `CustomInline` / `SymbolLink` / `InlineAttributes` | — | 未专门处理 |

## 6. 取值片段

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

容器没有 `.string` 时：

```swift
// 纯文本
func plainText(of node: Markup) -> String {
  if let t = node as? Text { return t.string }
  return node.children.map { plainText(of: $0) }.joined()
}

// 保留 Markdown 标记（InkTableBlock 做法）
cell.children.map { $0.format() }.joined()
```

## 7. 格式化 / 改写

```swift
let md = doc.format()                       // MarkupFormatter
let html = HTMLFormatter.format(doc)        // 静态方法，不是 HTMLFormatter().format
print(doc.debugDescription())               // 树调试
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

本库渲染链路**没有**挂 Rewriter。需要时在调用 renderer 前自行 `visit`。路线图 v2 规划显式 `InkTransformer`。

## 8. 接 InkMarkdown 扩展点

### `InkBlockHandler`（块 → UIView）

```swift
struct MyTableHandler: InkBlockHandler {
  func canHandle(_ markup: Markup) -> Bool { markup is Table }
  func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let table = markup as? Table else { return nil }
    return InkTableBlock.from(table, layoutMode: .wrap, configuration: configuration)
  }
}
```

### `InkInlineSyntax`（纯文本片段，不是 Markup）

```swift
struct MentionSyntax: InkInlineSyntax {
  func render(text: String, context: InkInlineContext) -> NSAttributedString? {
    guard text.contains("@") else { return nil }
    // 用 context.baseFont / textColor
    return NSAttributedString(string: text, attributes: [
      .font: context.baseFont,
      .foregroundColor: context.textColor,
    ])
  }
}
```

`Image` 是行内节点：真图不要指望 `InkBlockHandler` 拦「块」，应改行内路径或预处理。

## 9. 注意

1. **不可变 + COW**：改节点得到新树；遍历只读是安全的
2. **身份**：不要用引用相等当稳定 ID
3. **range**：默认解析通常有 `range`；`.disableSourcePosOpts` 可关
4. **未知节点**：HTML / Doxygen / SymbolLink 等要降级或忽略，防止 silently 漏渲
5. **版本**：跟 `Package.resolved` / 缓存副本走，升级后核对本表
