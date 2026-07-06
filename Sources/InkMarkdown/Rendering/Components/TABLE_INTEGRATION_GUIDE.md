# InkMarkdown 表格组件接入指南

## 概述

InkMarkdown 通过 **Block 路由** 机制支持 GFM（GitHub Flavored Markdown）表格渲染。核心库提供完整的表格解析与原生 UIView 渲染能力，业务方只需在调用 `InkBlockRenderer.render()` 时注入表格工厂闭包即可。

---

## 最小接入（3 行代码）

```swift
import InkMarkdown
import Markdown

let blocks = InkBlockRenderer.render(
  markdownSource,
  customTableBlockFactory: { table in
    InkTableBlock.from(table)
  }
)

// 将 blocks 渲染到 UI
for block in blocks {
  stackView.addArrangedSubview(block.makeView())
}
```

以上代码即可让 Markdown 中的表格渲染为原生 UIView，使用默认样式（wrap 模式、14pt 字号、不可复制）。

---

## 布局模式

通过 `InkTableLayoutMode` 控制表格的横向行为：

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `.wrap` | 列宽按比例分配，内容自动换行 | 列少、内容长（如股东名称） |
| `.scroll` | 列宽按内容计算，支持横向滑动，内容换行 | 列多、需完整展示 |

```swift
// Wrap 模式（默认）
InkTableBlock.from(table, layoutMode: .wrap)

// Scroll 模式
InkTableBlock.from(table, layoutMode: .scroll)
```

---

## 样式配置

通过 `InkTableStyleConfig` 自定义表格样式。该结构体为**值类型**，每次修改只影响当前表格实例。

### 基本用法

```swift
var config = InkTableStyleConfig()
config.headerFontSize = 16
config.bodyFontSize = 14
config.cornerRadius = 8
config.enableLongPressCopy = true

let block = InkTableBlock.from(table, layoutMode: .wrap, config: config)
```

### 完整配置项

#### 字号
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `headerFontSize` | CGFloat | 14 | 表头字号 |
| `bodyFontSize` | CGFloat | 14 | 数据行字号 |

#### 颜色
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `headerColor` | UIColor | label 90% | 表头文字颜色 |
| `bodyColor` | UIColor | label | 数据行文字颜色 |
| `separatorColor` | UIColor | .separator | 分割线颜色 |
| `headerBackgroundColor` | UIColor | .secondarySystemBackground | 表头背景色 |

#### 间距
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `horizontalPadding` | CGFloat | 10 | 单元格文字左右间距 |
| `verticalPadding` | CGFloat | 12 | 单元格文字上下间距 |
| `lineHeight` | CGFloat | 20 | 文字行高（n 行 = n × 20） |

#### 容器
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `tableHorizontalInset` | CGFloat | 12 | 表格外层左右边距 |
| `tableVerticalInset` | CGFloat | 4 | 表格外层上下边距 |
| `cornerRadius` | CGFloat | 0 | 表格圆角 |
| `borderWidth` | CGFloat | 0.5 | 外边框宽度 |
| `separatorThickness` | CGFloat | 0.5 | 横/纵分割线粗细 |

#### 列宽限制
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `columnMaxWidthRatio` | CGFloat | 0.5 | 单列最大宽度占屏幕比例 |

#### 交互
| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enableLongPressCopy` | Bool | false | 是否支持长按复制表格内容 |

---

## 完整接入示例

### 场景：业务详情页中渲染 Markdown 表格

```swift
import UIKit
import InkMarkdown
import Markdown

class DetailViewController: UIViewController {

  private let markdownSource: String

  override func viewDidLoad() {
    super.viewDidLoad()

    let scrollView = UIScrollView()
    view.addSubview(scrollView)
    // ... scrollView 布局约束 ...

    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 8
    scrollView.addSubview(stackView)
    // ... stackView 布局约束 ...

    // 渲染 Markdown，注入表格工厂
    let blocks = InkBlockRenderer.render(
      markdownSource,
      customTableBlockFactory: { [weak self] table in
        self?.makeTableBlock(from: table)
      }
    )

    for block in blocks {
      stackView.addArrangedSubview(block.makeView())
    }
  }

  private func makeTableBlock(from table: Table) -> InkRenderableBlock {
    var config = InkTableStyleConfig()
    config.enableLongPressCopy = true
    config.columnMaxWidthRatio = 0.45

    // 列数 > 4 时使用横向滑动模式
    let columnCount = Array(table.head.cells).count
    let mode: InkTableLayoutMode = columnCount > 4 ? .scroll : .wrap

    return InkTableBlock.from(table, layoutMode: mode, config: config)
  }
}
```

### 场景：根据业务需求动态切换模式

```swift
// 工厂闭包中可根据表格内容动态决策
let blocks = InkBlockRenderer.render(source, customTableBlockFactory: { table in
  let headers = Array(table.head.cells).map { $0.plainText }

  // 检测是否为「股东信息」类表格
  let isShareholderTable = headers.contains("股东名称")

  var config = InkTableStyleConfig()
  if isShareholderTable {
    config.columnMaxWidthRatio = 0.4  // 股东名称列较长，限制更严
    config.enableLongPressCopy = true
  }

  return InkTableBlock.from(table, layoutMode: .wrap, config: config)
})
```

---

## 架构说明

```
InkBlockRenderer.render(source, customTableBlockFactory: ...)
        │
        ▼
   swift-markdown 解析出 Table 节点
        │
        ▼
   customTableBlockFactory(table) 被调用
        │
        ▼
   InkTableBlock.from(table, ...) 构造 Block
        │
        ▼
   block.makeView() → InkTableBlockView (private, 原生 Auto Layout)
```

- **InkBlockRenderer**：路由层，遍历 Markup 树，遇到 Table 节点时调用注入的工厂闭包
- **InkTableBlock**：数据模型（struct），持有表头、行数据、对齐方式、布局模式、样式配置
- **InkTableBlockView**：渲染层（private class），纯 Auto Layout 实现，不依赖第三方库

---

## SSE 流式渲染（逐行吐字）

SSE 场景下 Markdown 表格是逐行到达的，不能等表格完整才渲染。`InkStreamTableView` 支持增量追加行，实现一行一行渲染的效果。

### 基本用法

```swift
import InkMarkdown
import Markdown

// 1. 创建流式表格视图
let streamTable = InkStreamTableView(layoutMode: .wrap)
streamTable.onHeightChange = { [weak self] in
  // 通知外部刷新 cell 高度（UITableView / UICollectionView 场景）
  self?.tableView.beginUpdates()
  self?.tableView.endUpdates()
}
stackView.addArrangedSubview(streamTable)

// 2. SSE 收到表头行时
streamTable.setHeaders(["序号", "股东名称", "持股比例"])

// 3. SSE 每收到一行数据时
streamTable.appendRow(["1", "镇立新", "32.25%"])
streamTable.appendRow(["2", "罗希平", "6.84%"])
// ...后续行继续 appendRow
```

### 配合 SSE 解析的完整示例

```swift
class StreamingViewController: UIViewController {

  private var streamTable: InkStreamTableView?
  private var isParsingTable = false
  private var tableHeaderParsed = false

  /// SSE 每收到一个 chunk 时调用
  func onSSEChunk(_ text: String) {
    let lines = text.components(separatedBy: "\n")
    for line in lines {
      processLine(line)
    }
  }

  private func processLine(_ line: String) {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    // 检测表格开始：以 | 开头的行
    if trimmed.hasPrefix("|") {
      if !isParsingTable {
        // 新表格开始
        isParsingTable = true
        tableHeaderParsed = false
        let table = InkStreamTableView(layoutMode: .wrap, config: makeConfig())
        table.onHeightChange = { [weak self] in
          self?.updateLayout()
        }
        streamTable = table
        stackView.addArrangedSubview(table)
      }

      let cells = parseTableRow(trimmed)

      // 跳过分隔行（|---|---|---| 格式）
      if cells.first?.contains("---") == true { return }

      if !tableHeaderParsed {
        streamTable?.setHeaders(cells)
        tableHeaderParsed = true
      } else {
        streamTable?.appendRow(cells)
      }
    } else if isParsingTable {
      // 非 | 开头的行 = 表格结束
      isParsingTable = false
      streamTable = nil
    }
  }

  private func parseTableRow(_ line: String) -> [String] {
    line.split(separator: "|")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  private func makeConfig() -> InkTableStyleConfig {
    var config = InkTableStyleConfig()
    config.enableLongPressCopy = true
    return config
  }
}
```

### API 说明

| 方法 | 说明 |
|------|------|
| `setHeaders(_:alignments:)` | 设置表头，仅首次调用生效 |
| `appendRow(_:)` | 追加一行数据，立即渲染到视图中 |
| `rowCount` | 当前已渲染的数据行数 |
| `onHeightChange` | 行数变化时的回调，用于刷新外层布局 |

### 与静态渲染的对比

| | `InkTableBlock`（静态） | `InkStreamTableView`（流式） |
|---|---|---|
| 数据来源 | 完整 Markdown 一次解析 | SSE 逐行到达 |
| 渲染时机 | 一次性构建完整表格 | 逐行追加 |
| 适用场景 | 已有完整数据 | AI 流式输出 |
| 列宽计算 | 基于全部数据 | 基于已到达数据（表头 + 已有行） |

> **提示**：流式模式下列宽基于已到达数据计算。如果后续行内容明显更长，可在 `setHeaders` 前预估列宽，或设置 `columnMaxWidthRatio` 限制最大宽度避免布局跳动。

---

## 注意事项

1. **不注入工厂 = 表格回退为纯文本**。如果不传 `customTableBlockFactory`，表格会走默认的 NSAttributedString 渲染（管道符分隔的纯文本），不会渲染为表格视图。

2. **`InkTableStyleConfig` 是值类型**。每次 `var config = InkTableStyleConfig()` 拿到的是独立副本，修改不会影响其他表格。

3. **列宽计算依赖屏幕宽度**。`columnMaxWidthRatio` 基于 `UIScreen.main.bounds.width` 计算，iPad 上会自动获得更大的列宽。

4. **长按复制格式**。开启 `enableLongPressCopy` 后，复制到剪贴板的内容为 tab 分隔文本（兼容粘贴到 Excel/Numbers）。

5. **InkMarkdown 不依赖 SnapKit**。核心库纯 UIKit Auto Layout 实现，业务方无需引入额外依赖。
