import UIKit
import Markdown

// MARK: - 表格视图（内部实现，静态一次性渲染）

final class InkTableBlockView: UIView {

  private let headers: [String]
  private let rows: [[String]]
  private let alignments: [Table.ColumnAlignment?]
  private let layoutMode: InkTableLayoutMode
  private let config: InkAppearance.Table
  private let configuration: InkConfiguration

  init(headers: [String], rows: [[String]], alignments: [Table.ColumnAlignment?], layoutMode: InkTableLayoutMode, config: InkAppearance.Table, configuration: InkConfiguration) {
    self.headers = headers
    self.rows = rows
    self.alignments = alignments
    self.layoutMode = layoutMode
    self.config = config
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Setup

  private func setup() {
    switch layoutMode {
    case .wrap:
      setupWrapMode()
    case .scroll:
      setupScrollMode()
    }
  }

  // MARK: - Wrap 模式

  private func setupWrapMode() {
    let contentWidths = InkTableRenderHelper.measureColumnContentWidths(headers: headers, rows: rows, config: config, configuration: configuration)
    let ratios = InkTableRenderHelper.widthsToRatios(contentWidths)

    let container = InkTableRenderHelper.makeContainer(config: config)
    addSubview(container)
    container.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      // 规范总纲：上方不设间距（top=0），下方间距由 verticalInset 承担（规范：24）。
      container.topAnchor.constraint(equalTo: topAnchor),
      container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -config.verticalInset),
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

    populateStack(stack, widthMode: .ratio(ratios))
  }

  // MARK: - Scroll 模式

  private func setupScrollMode() {
    let fixedWidths = InkTableRenderHelper.measureColumnContentWidths(headers: headers, rows: rows, config: config, configuration: configuration)

    let scrollView = UIScrollView()
    scrollView.showsHorizontalScrollIndicator = true
    scrollView.showsVerticalScrollIndicator = false
    scrollView.alwaysBounceHorizontal = true
    scrollView.alwaysBounceVertical = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(scrollView)
    NSLayoutConstraint.activate([
      // 规范总纲：上方不设间距（top=0），下方间距由 verticalInset 承担（规范：24）。
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

    populateStack(stack, widthMode: .fixed(fixedWidths))
  }

  // MARK: - 填充行

  private func populateStack(_ stack: UIStackView, widthMode: InkTableRenderHelper.ColumnWidthMode) {
    if !headers.isEmpty {
      let headerRow = UIView()
      InkTableRenderHelper.makeRow(texts: headers, isHeader: true, widthMode: widthMode, alignments: alignments, config: config, configuration: configuration, rowContainer: headerRow)
      stack.addArrangedSubview(headerRow)
      stack.addArrangedSubview(InkTableRenderHelper.makeSeparator(config: config))
    }

    for (index, row) in rows.enumerated() {
      let rowView = UIView()
      InkTableRenderHelper.makeRow(texts: row, isHeader: false, widthMode: widthMode, alignments: alignments, config: config, configuration: configuration, rowContainer: rowView)
      stack.addArrangedSubview(rowView)
      if index < rows.count - 1 {
        stack.addArrangedSubview(InkTableRenderHelper.makeSeparator(config: config))
      }
    }

    if config.enableLongPressCopy {
      let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      addGestureRecognizer(gesture)
    }
  }

  // MARK: - 长按复制

  @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began else { return }
    UIPasteboard.general.string = InkTableRenderHelper.buildPlainText(headers: headers, rows: rows)
    InkTableRenderHelper.showCopyFeedback(on: self, config: config)
  }
}
