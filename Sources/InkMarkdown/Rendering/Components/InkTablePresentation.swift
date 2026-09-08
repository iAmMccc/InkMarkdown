import UIKit
import Markdown

// MARK: - 表格单元格来源（internal）

/// 单个单元格的输入来源：原文与 prepared 绑定在同一值内，无法与另一 cell 的 prepared 错位。
enum InkTableCellSource: Equatable, Sendable {
  /// 公开 raw 输入；接纳时执行一次 `sourcePreparedForParsing`。
  case raw(String)
  /// 已由顶层 renderer / Markup 派生的 prepared 片段；不再执行 sourceFilter。
  case prepared(original: String, source: InkPreparedMarkdownSource)

  /// 单元格原始文本，供分隔行判定与无副作用检查使用。
  var original: String {
    switch self {
    case .raw(let text):
      return text
    case .prepared(let original, _):
      return original
    }
  }
}

/// 已完成来源接纳、可供测量与建行反复消费的单元格值。
struct InkTablePreparedCell: Equatable, Sendable {
  /// 复制 / fallback 使用的原文（不被 filter 回写）。
  let original: String
  /// 可直接交给行内解析的 prepared 源码。
  let prepared: InkPreparedMarkdownSource
}

extension InkTableCellSource {
  /// 将来源接纳为可复用的 prepared cell。raw 恰好过滤一次；prepared 直接沿用。
  @MainActor
  func accepted(using configuration: InkConfiguration) -> InkTablePreparedCell {
    switch self {
    case .raw(let text):
      return InkTablePreparedCell(
        original: text,
        prepared: configuration.sourcePreparedForParsing(text)
      )
    case .prepared(let original, let source):
      return InkTablePreparedCell(original: original, prepared: source)
    }
  }
}

extension Array where Element == InkTableCellSource {
  @MainActor
  func accepted(using configuration: InkConfiguration) -> [InkTablePreparedCell] {
    map { $0.accepted(using: configuration) }
  }
}

extension Array where Element == [InkTableCellSource] {
  @MainActor
  func accepted(using configuration: InkConfiguration) -> [[InkTablePreparedCell]] {
    map { $0.accepted(using: configuration) }
  }
}

// MARK: - 布局快照与呈现状态

/// 一次一致的列宽模式与可呈现行；不暴露可变缓存容器给调用方改写。
struct InkTableLayoutSnapshot {
  enum Update: Equatable {
    case none
    case appendRow
    case fullRebuild
  }

  let update: Update
  let contentWidth: CGFloat
  let columnWidths: [CGFloat]
  let widthMode: InkTableRenderHelper.ColumnWidthMode
  let headers: [InkTablePreparedCell]
  let rows: [[InkTablePreparedCell]]
  let alignments: [Table.ColumnAlignment?]
  let layoutMode: InkTableLayoutMode

  var rowCount: Int { rows.count }

  var originalHeaders: [String] { headers.map(\.original) }
  var originalRows: [[String]] { rows.map { $0.map(\.original) } }

  /// 已按已知内容宽算出列布局。未知宽接纳只带表头/行，此值为 `false`。
  var hasColumnLayout: Bool { contentWidth > 0 && !columnWidths.isEmpty }
}

/// 表格呈现状态：集中来源接纳、测量与列宽失效。静态/流式只选输入操作。
@MainActor
struct InkTablePresentation {
  private(set) var headers: [InkTablePreparedCell] = []
  private(set) var rows: [[InkTablePreparedCell]] = []
  private(set) var referenceRows: [[InkTablePreparedCell]] = []
  private var alignments: [Table.ColumnAlignment?] = []
  private var layoutMode: InkTableLayoutMode
  private var config: InkAppearance.Table
  private var configuration: InkConfiguration
  private var lastContentWidth: CGFloat = 0
  private var cachedColumnWidths: [CGFloat] = []
  private var hasAcceptedHeaders = false

  init(
    layoutMode: InkTableLayoutMode,
    config: InkAppearance.Table? = nil,
    configuration: InkConfiguration
  ) {
    self.layoutMode = layoutMode
    self.configuration = configuration
    self.config = config ?? configuration.appearance.table
  }

  /// 静态一次替换全部内容（新的接纳生命周期）。
  mutating func replace(
    headers headerSources: [InkTableCellSource],
    rows rowSources: [[InkTableCellSource]],
    alignments: [Table.ColumnAlignment?] = [],
    contentWidth: CGFloat
  ) -> InkTableLayoutSnapshot {
    self.headers = headerSources.accepted(using: configuration)
    self.rows = rowSources.accepted(using: configuration)
    self.referenceRows = []
    self.alignments = alignments
    hasAcceptedHeaders = !self.headers.isEmpty
    return layoutIfWidthKnown(contentWidth: contentWidth, update: .fullRebuild)
  }

  /// 流式首次接纳表头与测量参考行。已接纳后返回 `nil`（保持既有第二次 setHeaders 忽略契约）。
  mutating func setHeaders(
    _ headerSources: [InkTableCellSource],
    referenceRows referenceSources: [[InkTableCellSource]] = [],
    alignments: [Table.ColumnAlignment?] = [],
    contentWidth: CGFloat
  ) -> InkTableLayoutSnapshot? {
    guard !hasAcceptedHeaders else { return nil }
    headers = headerSources.accepted(using: configuration)
    referenceRows = referenceSources.accepted(using: configuration)
    rows = []
    self.alignments = alignments
    hasAcceptedHeaders = true
    return layoutIfWidthKnown(contentWidth: contentWidth, update: .fullRebuild)
  }

  /// 追加一行。短行可仅标记 append；需扩列时要求全量重建。分隔行返回 `nil`。
  mutating func appendRow(
    _ cellSources: [InkTableCellSource],
    contentWidth: CGFloat? = nil
  ) -> InkTableLayoutSnapshot? {
    guard hasAcceptedHeaders else { return nil }
    if cellSources.allSatisfy({ Self.isSeparatorCell($0.original) }) {
      return nil
    }
    let prepared = cellSources.accepted(using: configuration)
    rows.append(prepared)
    let width = contentWidth ?? lastContentWidth
    guard width > 0 else {
      return makeDeferredSnapshot()
    }
    let needsExpand = cachedColumnWidths.isEmpty || rowNeedsColumnExpand(prepared, contentWidth: width)
    if needsExpand || abs(width - lastContentWidth) > 0.5 {
      return recomputeLayout(contentWidth: width, update: .fullRebuild)
    }
    return makeSnapshot(update: .appendRow, contentWidth: lastContentWidth, columnWidths: cachedColumnWidths)
  }

  /// 宿主内容宽变化时重算。wrap 超容差才重建；scroll 保持自然列宽，仅刷新 snapshot。
  mutating func layout(contentWidth: CGFloat) -> InkTableLayoutSnapshot {
    guard hasAcceptedHeaders else {
      return makeSnapshot(update: .none, contentWidth: contentWidth, columnWidths: [])
    }
    guard contentWidth > 0 else {
      return makeDeferredSnapshot()
    }
    switch layoutMode {
    case .wrap:
      if !cachedColumnWidths.isEmpty, abs(contentWidth - lastContentWidth) <= 0.5 {
        return makeSnapshot(update: .none, contentWidth: lastContentWidth, columnWidths: cachedColumnWidths)
      }
      return recomputeLayout(contentWidth: contentWidth, update: .fullRebuild)
    case .scroll:
      // scroll：自然列宽不随 viewport 收缩；仍返回当前 widthMode 供 viewport 宿主使用。
      if cachedColumnWidths.isEmpty {
        return recomputeLayout(contentWidth: contentWidth, update: .fullRebuild)
      }
      lastContentWidth = contentWidth
      return makeSnapshot(update: .none, contentWidth: contentWidth, columnWidths: cachedColumnWidths)
    }
  }

  /// 未知宽只保留已接纳内容，不算列宽、不缓存假布局。
  private mutating func layoutIfWidthKnown(
    contentWidth: CGFloat,
    update: InkTableLayoutSnapshot.Update
  ) -> InkTableLayoutSnapshot {
    guard contentWidth > 0 else {
      lastContentWidth = 0
      cachedColumnWidths = []
      return makeDeferredSnapshot()
    }
    return recomputeLayout(contentWidth: contentWidth, update: update)
  }

  private mutating func recomputeLayout(
    contentWidth: CGFloat,
    update: InkTableLayoutSnapshot.Update
  ) -> InkTableLayoutSnapshot {
    guard contentWidth > 0 else {
      return makeDeferredSnapshot()
    }
    let measureRows = referenceRows + rows
    let maximumColumnWidth: CGFloat? = layoutMode == .scroll ? .greatestFiniteMagnitude : nil
    let widths = InkTableRenderHelper.measureColumnContentWidths(
      headers: headers,
      rows: measureRows,
      config: config,
      configuration: configuration,
      containerWidth: contentWidth,
      maximumColumnWidth: maximumColumnWidth
    )
    lastContentWidth = contentWidth
    cachedColumnWidths = widths
    return makeSnapshot(update: update, contentWidth: contentWidth, columnWidths: widths)
  }

  private func makeSnapshot(
    update: InkTableLayoutSnapshot.Update,
    contentWidth: CGFloat,
    columnWidths: [CGFloat]
  ) -> InkTableLayoutSnapshot {
    let widthMode: InkTableRenderHelper.ColumnWidthMode
    switch layoutMode {
    case .wrap:
      widthMode = .ratio(InkTableRenderHelper.widthsToRatios(columnWidths))
    case .scroll:
      widthMode = .fixed(columnWidths)
    }
    return InkTableLayoutSnapshot(
      update: update,
      contentWidth: contentWidth,
      columnWidths: columnWidths,
      widthMode: widthMode,
      headers: headers,
      rows: rows,
      alignments: alignments,
      layoutMode: layoutMode
    )
  }

  private func makeDeferredSnapshot() -> InkTableLayoutSnapshot {
    InkTableLayoutSnapshot(
      update: .none,
      contentWidth: 0,
      columnWidths: [],
      widthMode: layoutMode == .wrap ? .ratio([]) : .fixed([]),
      headers: headers,
      rows: rows,
      alignments: alignments,
      layoutMode: layoutMode
    )
  }

  private func rowNeedsColumnExpand(
    _ cells: [InkTablePreparedCell],
    contentWidth: CGFloat
  ) -> Bool {
    guard !cachedColumnWidths.isEmpty else { return true }
    let bodyFont = InkTableRenderHelper.font(
      isHeader: false,
      config: config,
      configuration: configuration
    )
    let maxColumnWidth = layoutMode == .scroll
      ? CGFloat.greatestFiniteMagnitude
      : max(1, contentWidth) * config.columnMaxWidthRatio
    for (colIndex, cell) in cells.enumerated() {
      guard colIndex < cachedColumnWidths.count else { break }
      let attributed = InkAttributedRenderer.renderInline(
        preparedSource: cell.prepared,
        configuration: configuration,
        baseFont: bodyFont,
        textColor: config.bodyColor,
        fallbackText: cell.original
      )
      let measuredWidth = attributed.boundingRect(
        with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
        options: .usesLineFragmentOrigin,
        context: nil
      ).width
      let cellWidth = min(ceil(measuredWidth) + config.horizontalPadding * 2, maxColumnWidth)
      if cellWidth > cachedColumnWidths[colIndex] + 0.5 {
        return true
      }
    }
    return false
  }

  private static func isSeparatorCell(_ text: String) -> Bool {
    let s = text.trimmingCharacters(in: .whitespaces)
    guard !s.isEmpty else { return true }
    var i = s.startIndex
    if s[i] == ":" { i = s.index(after: i) }
    guard i < s.endIndex && s[i] == "-" else { return false }
    while i < s.endIndex && s[i] == "-" { i = s.index(after: i) }
    if i < s.endIndex && s[i] == ":" { i = s.index(after: i) }
    return i == s.endIndex
  }
}
