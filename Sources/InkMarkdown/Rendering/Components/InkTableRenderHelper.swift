import UIKit
import Markdown

// MARK: - 内部公共渲染工具

/// 表格行/单元格/分割线的共享构建逻辑，供 InkTableBlockView 和 InkStreamTableView 复用。
@MainActor enum InkTableRenderHelper {

  /// 列宽分配方式
  enum ColumnWidthMode {
    /// 按比例分配（wrap 模式）
    case ratio([CGFloat])
    /// 固定像素宽度（scroll 模式）
    case fixed([CGFloat])
  }

  /// 渲染与测量共用同一 trait 快照下的字体，避免 Dynamic Type 视觉值与布局值漂移。
  static func font(
    isHeader: Bool,
    config: InkAppearance.Table,
    configuration: InkConfiguration
  ) -> UIFont {
    let size = isHeader ? config.headerFontSize : config.bodyFontSize
    let weight: UIFont.Weight = isHeader ? .bold : .regular
    return configuration.appearance.scaledFont(
      .systemFont(ofSize: size, weight: weight),
      textStyle: .body,
      compatibleWith: configuration.renderEnvironment.traitCollection
    )
  }

  /// 返回表格内容区宽度。列宽上限、测量和实际 row 约束必须使用同一输入，
  /// 因此这里扣除表格两侧 inset，而不是回退到全局 screen 宽度。
  static func contentWidth(for view: UIView, config: InkAppearance.Table) -> CGFloat {
    max(1, InkDisplayMetrics.availableWidth(for: view) - config.horizontalInset * 2)
  }

  static func makeRow(
    texts: [String],
    isHeader: Bool,
    widthMode: ColumnWidthMode,
    alignments: [Table.ColumnAlignment?],
    config: InkAppearance.Table,
    configuration: InkConfiguration,
    rowContainer: UIView,
    preparedTexts: [InkPreparedMarkdownSource]? = nil
  ) {
    if isHeader {
      rowContainer.backgroundColor = config.headerBackgroundColor
    }

    var cells: [UIView] = []
    for (colIndex, text) in texts.enumerated() {
      let preparedSource = preparedTexts.flatMap { colIndex < $0.count ? $0[colIndex] : nil }
      let cell = makeCellView(
        text: text,
        preparedSource: preparedSource,
        isHeader: isHeader,
        columnIndex: colIndex,
        alignments: alignments,
        config: config,
        configuration: configuration
      )
      cell.translatesAutoresizingMaskIntoConstraints = false
      rowContainer.addSubview(cell)
      cells.append(cell)
    }

    for (colIndex, cell) in cells.enumerated() {
      let top = cell.topAnchor.constraint(equalTo: rowContainer.topAnchor)
      let bottom = cell.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor)
      bottom.priority = .defaultHigh
      let bottomLimit = cell.bottomAnchor.constraint(lessThanOrEqualTo: rowContainer.bottomAnchor)
      NSLayoutConstraint.activate([top, bottom, bottomLimit])

      if colIndex == 0 {
        cell.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor).isActive = true
      } else {
        cell.leadingAnchor.constraint(equalTo: cells[colIndex - 1].trailingAnchor).isActive = true
      }
      if colIndex == cells.count - 1 {
        cell.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor).isActive = true
      }

      switch widthMode {
      case .ratio(let ratios):
        if colIndex < ratios.count && colIndex < cells.count - 1 {
          cell.widthAnchor.constraint(equalTo: rowContainer.widthAnchor, multiplier: ratios[colIndex]).isActive = true
        }
      case .fixed(let widths):
        if colIndex < widths.count && colIndex < cells.count - 1 {
          let wc = cell.widthAnchor.constraint(equalToConstant: widths[colIndex])
          wc.priority = .required
          wc.isActive = true
        }
      }
    }

    for i in 1..<cells.count {
      let vLine = UIView()
      vLine.backgroundColor = config.separatorColor
      vLine.translatesAutoresizingMaskIntoConstraints = false
      rowContainer.addSubview(vLine)
      NSLayoutConstraint.activate([
        vLine.leadingAnchor.constraint(equalTo: cells[i].leadingAnchor),
        vLine.topAnchor.constraint(equalTo: rowContainer.topAnchor),
        vLine.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor),
        vLine.widthAnchor.constraint(equalToConstant: config.separatorThickness),
      ])
    }
  }

  static func makeCellView(
    text: String,
    preparedSource: InkPreparedMarkdownSource? = nil,
    isHeader: Bool,
    columnIndex: Int,
    alignments: [Table.ColumnAlignment?],
    config: InkAppearance.Table,
    configuration: InkConfiguration
  ) -> UIView {
    let cellView = UIView()

    let baseFont = font(isHeader: isHeader, config: config, configuration: configuration)
    let textColor: UIColor
    if isHeader {
      textColor = config.headerColor
    } else {
      textColor = config.bodyColor
    }

    let textAlignment: NSTextAlignment
    let alignment = (columnIndex < alignments.count) ? alignments[columnIndex] : nil
    switch alignment {
    case .center:
      textAlignment = .center
    case .right:
      textAlignment = .right
    default:
      textAlignment = .left
    }

    let scaledLineHeight = configuration.appearance.scaledValue(
      config.lineHeight,
      textStyle: .body,
      compatibleWith: configuration.renderEnvironment.traitCollection
    )
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.minimumLineHeight = scaledLineHeight
    paragraphStyle.maximumLineHeight = scaledLineHeight
    paragraphStyle.alignment = textAlignment
    paragraphStyle.lineBreakMode = .byCharWrapping

    let baselineOffset = (scaledLineHeight - baseFont.lineHeight) / 2

    // 解析内联 Markdown（加粗/斜体/行内代码/链接 + 自定义 Directive），与正文共用 configuration
    let inlineAttr: NSAttributedString
    if let preparedSource {
      inlineAttr = InkAttributedRenderer.renderInline(
        preparedSource: preparedSource,
        configuration: configuration,
        baseFont: baseFont,
        textColor: textColor,
        fallbackText: text
      )
    } else {
      inlineAttr = InkAttributedRenderer.renderInline(
        text,
        configuration: configuration,
        baseFont: baseFont,
        textColor: textColor
      )
    }
    let attrText = NSMutableAttributedString(attributedString: inlineAttr)
    let fullRange = NSRange(location: 0, length: attrText.length)
    attrText.addAttributes([
      .paragraphStyle: paragraphStyle,
      .baselineOffset: baselineOffset,
    ], range: fullRange)

    let cell = InkTableCellTextView(
      attributedText: attrText,
      linkColor: configuration.appearance.link.color,
      linkTapHandler: configuration.linkTapHandler
    )
    cell.translatesAutoresizingMaskIntoConstraints = false
    cell.setContentCompressionResistancePriority(.required, for: .vertical)
    cell.setContentHuggingPriority(.required, for: .vertical)

    cellView.addSubview(cell)
    NSLayoutConstraint.activate([
      cell.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: config.horizontalPadding),
      cell.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -config.horizontalPadding),
      cell.topAnchor.constraint(equalTo: cellView.topAnchor, constant: config.verticalPadding),
      cell.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: -config.verticalPadding),
    ])

    return cellView
  }



  static func makeSeparator(config: InkAppearance.Table) -> UIView {
    let separator = UIView()
    separator.backgroundColor = config.separatorColor
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.heightAnchor.constraint(equalToConstant: config.separatorThickness).isActive = true
    return separator
  }

  static func makeContainer(config: InkAppearance.Table) -> UIView {
    let container = UIView()
    container.layer.cornerRadius = config.cornerRadius
    container.layer.cornerCurve = .continuous
    container.layer.borderWidth = config.borderWidth
    container.layer.borderColor = config.separatorColor.cgColor
    container.clipsToBounds = true
    return container
  }

  static func buildPlainText(headers: [String], rows: [[String]]) -> String {
    var lines: [String] = []
    if !headers.isEmpty {
      lines.append(headers.joined(separator: "\t"))
    }
    for row in rows {
      lines.append(row.joined(separator: "\t"))
    }
    return lines.joined(separator: "\n")
  }

  static func showCopyFeedback(on view: UIView, config: InkAppearance.Table) {
    if let custom = config.onCopyFeedback {
      custom(view)
      return
    }
    let toast = UILabel()
    toast.adjustsFontForContentSizeCategory = true
    toast.text = "已复制"
    toast.font = .systemFont(ofSize: 13)
    toast.textColor = .white
    toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    toast.textAlignment = .center
    toast.layer.cornerRadius = 4
    toast.clipsToBounds = true
    toast.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(toast)
    NSLayoutConstraint.activate([
      toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      toast.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      toast.widthAnchor.constraint(equalToConstant: 64),
      toast.heightAnchor.constraint(equalToConstant: 28),
    ])
    UIView.animate(withDuration: 0.2, delay: 1.0, options: [], animations: {
      toast.alpha = 0
    }, completion: { _ in
      toast.removeFromSuperview()
    })
  }

  /// 测量各列最大内容宽度（含 padding）。
  ///
  /// wrap 模式传入默认上限；scroll 模式可传入无穷上限，保留内容的自然宽度，
  /// 由外层 UIScrollView 提供 viewport。
  /// 使用渲染后的 attributed string 测量，自动适配所有内联样式。
  static func measureColumnContentWidths(
    headers: [String],
    rows: [[String]],
    config: InkAppearance.Table,
    configuration: InkConfiguration,
    containerWidth: CGFloat,
    maximumColumnWidth: CGFloat? = nil,
    preparedHeaders: [InkPreparedMarkdownSource]? = nil,
    preparedRows: [[InkPreparedMarkdownSource]]? = nil
  ) -> [CGFloat] {
    let colCount = headers.count
    guard colCount > 0 else { return [] }

    let headerFont = font(isHeader: true, config: config, configuration: configuration)
    let bodyFont = font(isHeader: false, config: config, configuration: configuration)
    let maxColumnWidth = max(1, maximumColumnWidth ?? containerWidth * config.columnMaxWidthRatio)
    var widths: [CGFloat] = Array(repeating: 0, count: colCount)

    for colIndex in 0..<colCount {
      let headerAttr = renderInline(
        text: headers[colIndex],
        preparedSource: preparedHeaders.flatMap { colIndex < $0.count ? $0[colIndex] : nil },
        configuration: configuration,
        baseFont: headerFont,
        textColor: config.headerColor
      )
      let headerWidth = ceil(headerAttr.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).width)
      widths[colIndex] = headerWidth

      for (rowIndex, row) in rows.enumerated() {
        guard colIndex < row.count else { continue }
        let preparedSource = preparedRows.flatMap { rowIndex < $0.count && colIndex < $0[rowIndex].count ? $0[rowIndex][colIndex] : nil }
        let cellAttr = renderInline(
          text: row[colIndex],
          preparedSource: preparedSource,
          configuration: configuration,
          baseFont: bodyFont,
          textColor: config.bodyColor
        )
        let cellWidth = ceil(cellAttr.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).width)
        widths[colIndex] = max(widths[colIndex], cellWidth)
      }
      widths[colIndex] = min(widths[colIndex] + config.horizontalPadding * 2, maxColumnWidth)
    }
    return widths
  }

  private static func renderInline(
    text: String,
    preparedSource: InkPreparedMarkdownSource?,
    configuration: InkConfiguration,
    baseFont: UIFont,
    textColor: UIColor
  ) -> NSAttributedString {
    if let preparedSource {
      return InkAttributedRenderer.renderInline(
        preparedSource: preparedSource,
        configuration: configuration,
        baseFont: baseFont,
        textColor: textColor,
        fallbackText: text
      )
    }
    return InkAttributedRenderer.renderInline(
      text,
      configuration: configuration,
      baseFont: baseFont,
      textColor: textColor
    )
  }

  /// 将内容宽度转化为比例
  static func widthsToRatios(_ widths: [CGFloat]) -> [CGFloat] {
    let total = widths.reduce(0, +)
    guard total > 0 else {
      let equal = 1.0 / CGFloat(max(widths.count, 1))
      return Array(repeating: equal, count: widths.count)
    }
    return widths.map { $0 / total }
  }
}
