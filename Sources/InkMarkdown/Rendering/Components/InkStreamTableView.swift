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
  private var presentation: InkTablePresentation
  private var lastSnapshot: InkTableLayoutSnapshot?

  private var contentStack: UIStackView!
  private var isRebuildingForWidth = false

  /// 行数变化时回调（用于通知外部更新 cell 高度）
  public var onHeightChange: (() -> Void)?

  public init(layoutMode: InkTableLayoutMode = .wrap, configuration: InkConfiguration = .standard) {
    self.layoutMode = layoutMode
    self.config = configuration.appearance.table
    self.configuration = configuration
    self.presentation = InkTablePresentation(layoutMode: layoutMode, configuration: configuration)
    super.init(frame: .zero)
    setupContainer()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    // scroll 内容保持自然宽度；宿主宽度变化只应改变 UIScrollView viewport。
    guard layoutMode == .wrap, !isRebuildingForWidth, lastSnapshot != nil, bounds.width > 0 else { return }
    let contentWidth = InkTableRenderHelper.contentWidth(for: self, config: config)
    guard abs(contentWidth - (lastSnapshot?.contentWidth ?? 0)) > 0.5 else { return }

    // 宽度变化只重算列布局；不调用 onHeightChange，避免在布局栈中递归触发宿主尺寸失效。
    isRebuildingForWidth = true
    defer { isRebuildingForWidth = false }
    let snapshot = presentation.layout(contentWidth: contentWidth)
    lastSnapshot = snapshot
    if snapshot.update == .fullRebuild {
      rebuildAllRows(from: snapshot)
    }
  }

  // MARK: - Public API

  /// 设置表头（仅调用一次，后续调用会忽略）
  /// - Parameters:
  ///   - headers: 表头文字
  ///   - alignments: 列对齐方式
  ///   - referenceRows: 用于列宽计算的参考数据（不会渲染），传入全部行数据可获得最优列宽
  public func setHeaders(_ headers: [String], alignments: [Table.ColumnAlignment?] = [], referenceRows: [[String]] = []) {
    let contentWidth = InkTableRenderHelper.contentWidth(for: self, config: config)
    guard let snapshot = presentation.setHeaders(
      headers.map { .raw($0) },
      referenceRows: referenceRows.map { row in row.map { .raw($0) } },
      alignments: alignments,
      contentWidth: contentWidth
    ) else {
      return
    }
    lastSnapshot = snapshot
    let headerRow = UIView()
    InkTableRenderHelper.makeRow(
      cells: snapshot.headers,
      isHeader: true,
      widthMode: snapshot.widthMode,
      alignments: snapshot.alignments,
      config: config,
      configuration: configuration,
      rowContainer: headerRow
    )
    contentStack.addArrangedSubview(headerRow)
    onHeightChange?()
  }

  /// 追加一行数据（SSE 每吐出一行时调用）
  /// 自动忽略 Markdown 分隔行（如 `---`、`:---`、`---:`、`:---:`）
  public func appendRow(_ cells: [String]) {
    let contentWidth = lastSnapshot?.contentWidth
      ?? InkTableRenderHelper.contentWidth(for: self, config: config)
    guard let snapshot = presentation.appendRow(
      cells.map { .raw($0) },
      contentWidth: contentWidth
    ) else {
      return
    }
    lastSnapshot = snapshot

    switch snapshot.update {
    case .fullRebuild:
      rebuildAllRows(from: snapshot)
    case .appendRow:
      guard let row = snapshot.rows.last else { break }
      contentStack.addArrangedSubview(InkTableRenderHelper.makeSeparator(config: config))
      let rowView = UIView()
      InkTableRenderHelper.makeRow(
        cells: row,
        isHeader: false,
        widthMode: snapshot.widthMode,
        alignments: snapshot.alignments,
        config: config,
        configuration: configuration,
        rowContainer: rowView
      )
      contentStack.addArrangedSubview(rowView)
    case .none:
      break
    }
    onHeightChange?()
  }

  /// 当前已渲染的行数
  public var rowCount: Int { presentation.rows.count }

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
      container.topAnchor.constraint(equalTo: topAnchor),
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
      scrollView.topAnchor.constraint(equalTo: topAnchor),
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

  private func rebuildAllRows(from snapshot: InkTableLayoutSnapshot) {
    contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

    let headerRow = UIView()
    InkTableRenderHelper.makeRow(
      cells: snapshot.headers,
      isHeader: true,
      widthMode: snapshot.widthMode,
      alignments: snapshot.alignments,
      config: config,
      configuration: configuration,
      rowContainer: headerRow
    )
    contentStack.addArrangedSubview(headerRow)

    for row in snapshot.rows {
      contentStack.addArrangedSubview(InkTableRenderHelper.makeSeparator(config: config))
      let rowView = UIView()
      InkTableRenderHelper.makeRow(
        cells: row,
        isHeader: false,
        widthMode: snapshot.widthMode,
        alignments: snapshot.alignments,
        config: config,
        configuration: configuration,
        rowContainer: rowView
      )
      contentStack.addArrangedSubview(rowView)
    }
  }

  // MARK: - 长按复制

  @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began else { return }
    let headers = lastSnapshot?.originalHeaders ?? presentation.headers.map(\.original)
    let rows = lastSnapshot?.originalRows ?? presentation.rows.map { $0.map(\.original) }
    UIPasteboard.general.string = InkTableRenderHelper.buildPlainText(headers: headers, rows: rows)
    InkTableRenderHelper.showCopyFeedback(on: self, config: config)
  }
}
