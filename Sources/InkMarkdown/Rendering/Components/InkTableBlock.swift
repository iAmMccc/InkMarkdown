import UIKit
import Markdown

/// 表格布局策略
public enum InkTableLayoutMode {
  /// 固定宽度，内容换行（适合列少、内容长的场景）
  case wrap
  /// 横向可滑动，单行不换行（适合列多、需要完整展示的场景）
  case scroll
}


/// 表格 Block：解析 Markdown Table 后渲染为原生 UIView 表格。
public struct InkTableBlock: InkRenderableBlock {
  public let headers: [String]
  public let rows: [[String]]
  public let alignments: [Table.ColumnAlignment?]
  public let layoutMode: InkTableLayoutMode
  public var config: InkAppearance.Table
  /// 完整渲染配置：单元格行内内容据此复用 `inlineSyntaxes` / `linkTapHandler`。
  public var configuration: InkConfiguration

  public init(
    headers: [String],
    rows: [[String]],
    alignments: [Table.ColumnAlignment?],
    layoutMode: InkTableLayoutMode = .wrap,
    configuration: InkConfiguration = .standard
  ) {
    self.headers = headers
    self.rows = rows
    self.alignments = alignments
    self.layoutMode = layoutMode
    self.config = configuration.appearance.table
    self.configuration = configuration
  }

  public func makeView() -> UIView {
    InkTableBlockView(headers: headers, rows: rows, alignments: alignments, layoutMode: layoutMode, config: config, configuration: configuration)
  }
}

// MARK: - 便捷工厂

public extension InkTableBlock {
  /// 从 swift-markdown 的 Table 节点构造。
  /// 保留单元格内的 Markdown 内联标记（如 `**加粗**`），渲染时解析。
  static func from(
    _ table: Table,
    layoutMode: InkTableLayoutMode = .wrap,
    configuration: InkConfiguration = .standard
  ) -> InkTableBlock {
    let headCells = Array(table.head.cells)
    let headers = headCells.map { Self.cellMarkdownText($0) }

    let bodyRows = Array(table.body.rows)
    let rows = bodyRows.map { row in
      Array(row.cells).map { Self.cellMarkdownText($0) }
    }

    return InkTableBlock(
      headers: headers,
      rows: rows,
      alignments: table.columnAlignments,
      layoutMode: layoutMode,
      configuration: configuration
    )
  }

  /// 提取 Cell 内联子节点的 Markdown 文本（保留加粗等标记）
  private static func cellMarkdownText(_ cell: Table.Cell) -> String {
    cell.children.map { $0.format() }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
