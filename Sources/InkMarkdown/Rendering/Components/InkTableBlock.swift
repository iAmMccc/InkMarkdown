import UIKit
import Markdown

/// 表格布局策略
public enum InkTableLayoutMode: Sendable, Equatable {
  /// 固定宽度，内容换行（适合列少、内容长的场景）
  case wrap
  /// 横向可滑动，单行不换行（适合列多、需要完整展示的场景）
  case scroll
}


/// 表格 Block：解析 Markdown Table 后渲染为原生 UIView 表格。
public struct InkTableBlock: InkRenderableBlock, InkReusableBlock {
  public let headers: [String]
  public let rows: [[String]]
  public let alignments: [Table.ColumnAlignment?]
  public let layoutMode: InkTableLayoutMode
  public var config: InkAppearance.Table
  /// 完整渲染配置：单元格行内内容据此复用 `inlineSyntaxes` / `linkTapHandler`。
  public var configuration: InkConfiguration

  /// `InkBlockRenderer` 已经在解析前完成顶层预处理时，表格 cell 也必须沿用同一边界。
  /// `nil` 表示来自公开 raw-string initializer，仍按 raw 输入语义渲染。
  let preparedHeaders: [InkPreparedMarkdownSource]?
  let preparedRows: [[InkPreparedMarkdownSource]]?

  @MainActor
  public init(
    headers: [String],
    rows: [[String]],
    alignments: [Table.ColumnAlignment?],
    layoutMode: InkTableLayoutMode = .wrap
  ) {
    self.init(headers: headers, rows: rows, alignments: alignments, layoutMode: layoutMode, configuration: .standard)
  }

  public init(
    headers: [String],
    rows: [[String]],
    alignments: [Table.ColumnAlignment?],
    layoutMode: InkTableLayoutMode = .wrap,
    configuration: InkConfiguration
  ) {
    self.headers = headers
    self.rows = rows
    self.alignments = alignments
    self.layoutMode = layoutMode
    self.config = configuration.appearance.table
    self.configuration = configuration
    self.preparedHeaders = nil
    self.preparedRows = nil
  }

  init(
    headers: [String],
    rows: [[String]],
    preparedHeaders: [InkPreparedMarkdownSource],
    preparedRows: [[InkPreparedMarkdownSource]],
    alignments: [Table.ColumnAlignment?],
    layoutMode: InkTableLayoutMode,
    configuration: InkConfiguration
  ) {
    self.headers = headers
    self.rows = rows
    self.alignments = alignments
    self.layoutMode = layoutMode
    self.config = configuration.appearance.table
    self.configuration = configuration
    self.preparedHeaders = preparedHeaders
    self.preparedRows = preparedRows
  }

  @MainActor public func makeView() -> UIView {
    InkTableBlockView(
      headers: headers,
      rows: rows,
      alignments: alignments,
      layoutMode: layoutMode,
      config: config,
      configuration: configuration,
      preparedHeaders: preparedHeaders,
      preparedRows: preparedRows
    )
  }

  @MainActor
  public func updateExistingView(_ view: UIView) -> Bool {
    guard let tableView = view as? InkTableBlockView else { return false }
    tableView.apply(
      headers: headers,
      rows: rows,
      alignments: alignments,
      layoutMode: layoutMode,
      config: config,
      configuration: configuration,
      preparedHeaders: preparedHeaders,
      preparedRows: preparedRows
    )
    return true
  }

  @MainActor
  public func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    guard let previous = previous as? InkTableBlock else { return false }
    return headers == previous.headers
      && rows == previous.rows
      && alignments == previous.alignments
      && layoutMode == previous.layoutMode
      && config == previous.config
      && preparedHeaders == previous.preparedHeaders
      && preparedRows == previous.preparedRows
      && configuration.isSemanticallyEqualTo(previous.configuration)
  }
}

// MARK: - 便捷工厂

public extension InkTableBlock {
  /// 从 swift-markdown 的 Table 节点构造。
  /// 保留单元格内的 Markdown 内联标记（如 `**加粗**`），渲染时解析。
  @MainActor
  static func from(
    _ table: Markdown.Table,
    layoutMode: InkTableLayoutMode = .scroll
  ) -> InkTableBlock {
    from(table, layoutMode: layoutMode, configuration: .standard)
  }

  static func from(
    _ table: Markdown.Table,
    layoutMode: InkTableLayoutMode = .scroll,
    configuration: InkConfiguration
  ) -> InkTableBlock {
    let headCells = Array(table.head.cells)
    let headers = headCells.map { Self.cellMarkdownText($0) }
    let preparedHeaders = headCells.map { Self.preparedCellSource($0) }

    let bodyRows = Array(table.body.rows)
    let rows = bodyRows.map { row in
      Array(row.cells).map { Self.cellMarkdownText($0) }
    }
    let preparedRows = bodyRows.map { row in
      Array(row.cells).map { Self.preparedCellSource($0) }
    }

    return InkTableBlock(
      headers: headers,
      rows: rows,
      preparedHeaders: preparedHeaders,
      preparedRows: preparedRows,
      alignments: table.columnAlignments,
      layoutMode: layoutMode,
      configuration: configuration
    )
  }

  /// 提取 Cell 内联子节点的 Markdown 文本（保留加粗等标记）
  private static func cellMarkdownText(_ cell: Table.Cell) -> String {
    cell.children.map { $0.format() }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func preparedCellSource(_ cell: Table.Cell) -> InkPreparedMarkdownSource {
    InkPreparedMarkdownSource(preparedValue: cellMarkdownText(cell))
  }
}
