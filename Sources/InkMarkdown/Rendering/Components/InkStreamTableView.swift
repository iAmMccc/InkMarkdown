import UIKit
import Markdown

// MARK: - 流式表格视图（SSE 逐行渲染）

/// 支持 SSE 流式吐字场景的表格视图。
///
/// 使用方式：
/// ```swift
/// let tableView = InkStreamTableView(configuration: myConfiguration)
///
/// // SSE 收到表头行时
/// tableView.setHeaders(["序号", "股东名称", "持股比例"])
///
/// // SSE 每收到一行数据时
/// tableView.appendRow(["1", "镇立新", "32.25%"])
/// tableView.appendRow(["2", "罗希平", "6.84%"])
/// ```
public final class InkStreamTableView: UIView {

  private let config: InkAppearance.Table
  private let configuration: InkConfiguration
  private let layoutMode: InkTableLayoutMode

  private var headers: [String] = []
  private var rows: [[String]] = []
  private var alignments: [Table.ColumnAlignment?] = []

  private var contentStack: UIStackView!
  private var hasRenderedHeader: Bool = false

  /// 行数变化时回调（用于通知外部更新 cell 高度）
  public var onHeightChange: (() -> Void)?

  public init(layoutMode: InkTableLayoutMode = .wrap, configuration: InkConfiguration = .standard) {
    self.layoutMode = layoutMode
    self.config = configuration.appearance.table
    self.configuration = configuration
    super.init(frame: .zero)
    setupContainer()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Public API

  /// 设置表头（仅调用一次，后续调用会忽略）
  /// - Parameters:
  ///   - headers: 表头文字
  ///   - alignments: 列对齐方式
  ///   - referenceRows: 用于列宽计算的参考数据（不会渲染），传入全部行数据可获得最优列宽
  public func setHeaders(_ headers: [String], alignments: [Table.ColumnAlignment?] = [], referenceRows: [[String]] = []) {
    guard !hasRenderedHeader else { return }
    self.headers = headers
    self.alignments = alignments
    hasRenderedHeader = true

    let widths = InkTableRenderHelper.measureColumnContentWidths(headers: headers, rows: referenceRows, config: config, configuration: configuration)
    cachedFixedWidths = widths
    switch layoutMode {
    case .wrap:
      cachedWidthMode = .ratio(InkTableRenderHelper.widthsToRatios(widths))
    case .scroll:
      cachedWidthMode = .fixed(widths)
    }

    let headerRow = UIView()
    InkTableRenderHelper.makeRow(texts: headers, isHeader: true, widthMode: cachedWidthMode!, alignments: alignments, config: config, configuration: configuration, rowContainer: headerRow)
    contentStack.addArrangedSubview(headerRow)
    onHeightChange?()
  }

  /// 追加一行数据（SSE 每吐出一行时调用）
  /// 自动忽略 Markdown 分隔行（如 `---`、`:---`、`---:`、`:---:`）
  public func appendRow(_ cells: [String]) {
    if cells.allSatisfy({ Self.isSeparatorCell($0) }) { return }
    rows.append(cells)

    if widthsNeedExpand(for: cells) {
      let fullWidths = InkTableRenderHelper.measureColumnContentWidths(headers: headers, rows: rows, config: config, configuration: configuration)
      rebuildAllRows(widths: fullWidths)
    } else {
      contentStack.addArrangedSubview(InkTableRenderHelper.makeSeparator(config: config))
      let rowView = UIView()
      InkTableRenderHelper.makeRow(texts: cells, isHeader: false, widthMode: cachedWidthMode!, alignments: alignments, config: config, configuration: configuration, rowContainer: rowView)
      contentStack.addArrangedSubview(rowView)
    }
    onHeightChange?()
  }

  /// 当前已渲染的行数
  public var rowCount: Int { rows.count }

  // MARK: - Setup

  private func setupContainer() {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 0
    stack.alignment = .fill
    contentStack = stack

    switch layoutMode {
    case .wrap:
      setupWrapContainer(stack: stack)
    case .scroll:
      setupScrollContainer(stack: stack)
    }

    if config.enableLongPressCopy {
      let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      addGestureRecognizer(gesture)
    }
  }

  private func setupWrapContainer(stack: UIStackView) {
    let container = InkTableRenderHelper.makeContainer(config: config)

    addSubview(container)
    container.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: topAnchor, constant: config.verticalInset),
      container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -config.verticalInset),
      container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: config.horizontalInset),
      container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -config.horizontalInset),
    ])

    container.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])
  }

  private func setupScrollContainer(stack: UIStackView) {
    let scrollView = UIScrollView()
    scrollView.showsHorizontalScrollIndicator = true
    scrollView.showsVerticalScrollIndicator = false
    scrollView.alwaysBounceHorizontal = true
    scrollView.alwaysBounceVertical = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor, constant: config.verticalInset),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -config.verticalInset),
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: config.horizontalInset),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -config.horizontalInset),
    ])

    let container = InkTableRenderHelper.makeContainer(config: config)
    scrollView.addSubview(container)
    container.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      container.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
      container.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor),
    ])

    container.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])
  }

  // MARK: - 列宽

  private var cachedWidthMode: InkTableRenderHelper.ColumnWidthMode?
  private var cachedFixedWidths: [CGFloat] = []

  /// 仅用新追加行的单元格与当前缓存列宽比较，O(cols) 而非 O(N×cols)
  private func widthsNeedExpand(for cells: [String]) -> Bool {
    let bodyFont = UIFont.systemFont(ofSize: config.bodyFontSize)
    let maxColumnWidth = UIScreen.main.bounds.width * config.columnMaxWidthRatio
    for (colIndex, text) in cells.enumerated() {
      guard colIndex < cachedFixedWidths.count else { return true }
      let cellWidth = min(
        ceil((text as NSString).size(withAttributes: [.font: bodyFont]).width) + config.horizontalPadding * 2,
        maxColumnWidth
      )
      if cellWidth > cachedFixedWidths[colIndex] + 0.5 {
        return true
      }
    }
    return false
  }

  private func rebuildAllRows(widths: [CGFloat]) {
    cachedFixedWidths = widths
    switch layoutMode {
    case .wrap:
      cachedWidthMode = .ratio(InkTableRenderHelper.widthsToRatios(widths))
    case .scroll:
      cachedWidthMode = .fixed(widths)
    }

    contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

    let headerRow = UIView()
    InkTableRenderHelper.makeRow(texts: headers, isHeader: true, widthMode: cachedWidthMode!, alignments: alignments, config: config, configuration: configuration, rowContainer: headerRow)
    contentStack.addArrangedSubview(headerRow)

    for row in rows {
      contentStack.addArrangedSubview(InkTableRenderHelper.makeSeparator(config: config))
      let rowView = UIView()
      InkTableRenderHelper.makeRow(texts: row, isHeader: false, widthMode: cachedWidthMode!, alignments: alignments, config: config, configuration: configuration, rowContainer: rowView)
      contentStack.addArrangedSubview(rowView)
    }
  }

  // MARK: - 长按复制

  @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began else { return }
    UIPasteboard.general.string = InkTableRenderHelper.buildPlainText(headers: headers, rows: rows)
    InkTableRenderHelper.showCopyFeedback(on: self, config: config)
  }

  // MARK: - 分隔行检测

  /// 判断单个 cell 是否为 Markdown 表格分隔行格式（`:?-+:?`）
  private static func isSeparatorCell(_ cell: String) -> Bool {
    let s = cell.trimmingCharacters(in: .whitespaces)
    guard !s.isEmpty else { return true }
    var i = s.startIndex
    if s[i] == ":" { i = s.index(after: i) }
    guard i < s.endIndex && s[i] == "-" else { return false }
    while i < s.endIndex && s[i] == "-" { i = s.index(after: i) }
    if i < s.endIndex && s[i] == ":" { i = s.index(after: i) }
    return i == s.endIndex
  }
}
