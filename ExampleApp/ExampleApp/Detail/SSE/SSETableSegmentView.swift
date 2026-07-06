import UIKit
import InkMarkdown
import Markdown

/// 表格片段视图：SSE 吐字场景下逐行渲染表格。
///
/// 实现 `SSETypewriterSegment` 协议，按「行」粒度吐字：
/// 每行视为固定字符数（便于与文本段统一进度），进度推进时逐行显示。
final class SSETableSegmentView: UIView, SSETypewriterSegment {

  private let headers: [String]
  private let rows: [[String]]
  private let alignments: [Table.ColumnAlignment?]

  private let streamTable: InkStreamTableView
  private var displayedRowCount: Int = 0
  private var headerDisplayed: Bool = false

  /// 每行占用的逻辑字符数（用于统一吐字进度）
  private let charsPerRow: Int = 10

  init(headers: [String], rows: [[String]], alignments: [Table.ColumnAlignment?], layoutMode: InkTableLayoutMode = .wrap, configuration: InkConfiguration = .standard) {
    self.headers = headers
    self.rows = rows
    self.alignments = alignments
    self.streamTable = InkStreamTableView(layoutMode: layoutMode, configuration: configuration)
    super.init(frame: .zero)

    addSubview(streamTable)
    streamTable.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      streamTable.topAnchor.constraint(equalTo: topAnchor),
      streamTable.bottomAnchor.constraint(equalTo: bottomAnchor),
      streamTable.leadingAnchor.constraint(equalTo: leadingAnchor),
      streamTable.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  // MARK: - SSETypewriterSegment

  var typewriterLength: Int {
    // 表头 1 行 + 数据行数，每行 charsPerRow 个逻辑字符
    (1 + rows.count) * charsPerRow
  }

  func setVisibleLength(_ length: Int) {
    let visibleRows = length / charsPerRow

    if visibleRows >= 1 && !headerDisplayed {
      streamTable.setHeaders(headers, alignments: alignments, referenceRows: rows)
      headerDisplayed = true
    }

    let dataRowsToShow = max(0, visibleRows - 1)
    while displayedRowCount < dataRowsToShow && displayedRowCount < rows.count {
      streamTable.appendRow(rows[displayedRowCount])
      displayedRowCount += 1
    }
  }
}

// MARK: - Block 路由桥接

/// 表格 Block 的 SSE 桥接：让 InkBlockRenderer 路由到此，makeView 返回 SSETableSegmentView。
struct SSETableBlock: InkRenderableBlock {
  let headers: [String]
  let rows: [[String]]
  let alignments: [Table.ColumnAlignment?]
  let layoutMode: InkTableLayoutMode
  let configuration: InkConfiguration

  func makeView() -> UIView {
    SSETableSegmentView(headers: headers, rows: rows, alignments: alignments, layoutMode: layoutMode, configuration: configuration)
  }
}
