import UIKit
import Markdown

// MARK: - 表格视图（内部实现，静态一次性渲染）

final class InkTableBlockView: UIView {

  private var presentation: InkTablePresentation
  private var layoutMode: InkTableLayoutMode
  private var config: InkAppearance.Table
  private var configuration: InkConfiguration

  private var contentRoot: UIView?
  private var contentStack: UIStackView?
  private var copyGestureRecognizer: UILongPressGestureRecognizer?
  private var lastMeasuredContentWidth: CGFloat = 0
  private var layoutContentWidthOverride: CGFloat?
  private var isRebuildingForWidth = false
  private var lastSnapshot: InkTableLayoutSnapshot?

  init(
    headerSources: [InkTableCellSource],
    rowSources: [[InkTableCellSource]],
    alignments: [Table.ColumnAlignment?],
    layoutMode: InkTableLayoutMode,
    config: InkAppearance.Table,
    configuration: InkConfiguration
  ) {
    self.layoutMode = layoutMode
    self.config = config
    self.configuration = configuration
    self.presentation = InkTablePresentation(layoutMode: layoutMode, configuration: configuration)
    super.init(frame: .zero)
    accept(headerSources: headerSources, rowSources: rowSources, alignments: alignments)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func apply(
    headerSources: [InkTableCellSource],
    rowSources: [[InkTableCellSource]],
    alignments: [Table.ColumnAlignment?],
    layoutMode: InkTableLayoutMode,
    config: InkAppearance.Table,
    configuration: InkConfiguration
  ) {
    self.layoutMode = layoutMode
    self.config = config
    self.configuration = configuration
    presentation = InkTablePresentation(layoutMode: layoutMode, configuration: configuration)
    lastMeasuredContentWidth = 0
    contentRoot?.removeFromSuperview()
    contentRoot = nil
    contentStack = nil
    if let copyGestureRecognizer {
      removeGestureRecognizer(copyGestureRecognizer)
      self.copyGestureRecognizer = nil
    }
    accept(headerSources: headerSources, rowSources: rowSources, alignments: alignments)
    setup()
    invalidateIntrinsicContentSize()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // scroll 内容保持自然宽度；宿主宽度变化只应改变 UIScrollView viewport。
    guard layoutMode == .wrap, !isRebuildingForWidth, bounds.width > 0 else { return }
    let contentWidth = InkTableRenderHelper.contentWidth(for: self, config: config)
    guard abs(contentWidth - lastMeasuredContentWidth) > 0.5 else { return }
    rebuildLayout(forContentWidth: contentWidth)
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let targetWidth = size.width > 0 ? size.width : (bounds.width > 0 ? bounds.width : 320)
    let requestedContentWidth = max(1, targetWidth - config.horizontalInset * 2)
    if layoutMode == .wrap, abs(requestedContentWidth - lastMeasuredContentWidth) > 0.5 {
      rebuildLayout(forContentWidth: requestedContentWidth)
    }
    let availableWidth = max(0, targetWidth - config.horizontalInset * 2)
    guard let stack = contentStack else {
      return CGSize(width: targetWidth, height: config.verticalInset)
    }

    let fitting = stack.systemLayoutSizeFitting(
      CGSize(width: availableWidth, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    return CGSize(width: targetWidth, height: fitting.height + config.verticalInset)
  }

  override var intrinsicContentSize: CGSize {
    sizeThatFits(CGSize(width: bounds.width > 0 ? bounds.width : UIView.noIntrinsicMetric, height: .greatestFiniteMagnitude))
  }

  // MARK: - Setup

  private func rebuildLayout(forContentWidth contentWidth: CGFloat) {
    guard !isRebuildingForWidth else { return }
    isRebuildingForWidth = true
    defer { isRebuildingForWidth = false }

    let snapshot = presentation.layout(contentWidth: contentWidth)
    lastSnapshot = snapshot
    lastMeasuredContentWidth = snapshot.contentWidth

    contentRoot?.removeFromSuperview()
    contentRoot = nil
    contentStack = nil
    if let copyGestureRecognizer {
      removeGestureRecognizer(copyGestureRecognizer)
      self.copyGestureRecognizer = nil
    }
    layoutContentWidthOverride = contentWidth
    defer { layoutContentWidthOverride = nil }
    setup(using: snapshot)
  }

  private func accept(
    headerSources: [InkTableCellSource],
    rowSources: [[InkTableCellSource]],
    alignments: [Table.ColumnAlignment?]
  ) {
    let contentWidth = layoutContentWidthOverride
      ?? InkTableRenderHelper.contentWidth(for: self, config: config)
    lastSnapshot = presentation.replace(
      headers: headerSources,
      rows: rowSources,
      alignments: alignments,
      contentWidth: contentWidth
    )
    lastMeasuredContentWidth = lastSnapshot?.contentWidth ?? contentWidth
  }

  private func setup() {
    let contentWidth = layoutContentWidthOverride
      ?? InkTableRenderHelper.contentWidth(for: self, config: config)
    let snapshot = lastSnapshot ?? presentation.layout(contentWidth: contentWidth)
    lastSnapshot = snapshot
    lastMeasuredContentWidth = snapshot.contentWidth
    setup(using: snapshot)
  }

  private func setup(using snapshot: InkTableLayoutSnapshot) {
    switch layoutMode {
    case .wrap:
      setupWrapMode(snapshot: snapshot)
    case .scroll:
      setupScrollMode(snapshot: snapshot)
    }
  }

  // MARK: - Wrap 模式

  private func setupWrapMode(snapshot: InkTableLayoutSnapshot) {
    let container = InkTableRenderHelper.makeContainer(config: config)
    addSubview(container)
    contentRoot = container
    container.translatesAutoresizingMaskIntoConstraints = false
    let bottomConstraint = container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -config.verticalInset)
    bottomConstraint.priority = UILayoutPriority(999)
    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: topAnchor),
      bottomConstraint,
      container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: config.horizontalInset),
      container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -config.horizontalInset),
    ])

    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 0
    stack.alignment = .fill
    container.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])

    contentStack = stack
    populateStack(stack, snapshot: snapshot)
  }

  // MARK: - Scroll 模式

  private func setupScrollMode(snapshot: InkTableLayoutSnapshot) {
    let scrollView = UIScrollView()
    scrollView.showsHorizontalScrollIndicator = true
    scrollView.showsVerticalScrollIndicator = false
    scrollView.alwaysBounceHorizontal = true
    scrollView.alwaysBounceVertical = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(scrollView)
    contentRoot = scrollView
    let bottomConstraint = scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -config.verticalInset)
    bottomConstraint.priority = UILayoutPriority(999)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      bottomConstraint,
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

    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 0
    stack.alignment = .fill
    container.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])

    contentStack = stack
    populateStack(stack, snapshot: snapshot)
  }

  // MARK: - 填充行

  private func populateStack(_ stack: UIStackView, snapshot: InkTableLayoutSnapshot) {
    if !snapshot.headers.isEmpty {
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
      stack.addArrangedSubview(headerRow)
      stack.addArrangedSubview(InkTableRenderHelper.makeSeparator(config: config))
    }

    for (index, row) in snapshot.rows.enumerated() {
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
      stack.addArrangedSubview(rowView)
      if index < snapshot.rows.count - 1 {
        stack.addArrangedSubview(InkTableRenderHelper.makeSeparator(config: config))
      }
    }

    if config.enableLongPressCopy {
      let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      addGestureRecognizer(gesture)
      copyGestureRecognizer = gesture
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
