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

  static func makeRow(
    texts: [String],
    isHeader: Bool,
    widthMode: ColumnWidthMode,
    alignments: [Table.ColumnAlignment?],
    config: InkAppearance.Table,
    configuration: InkConfiguration,
    rowContainer: UIView
  ) {
    if isHeader {
      rowContainer.backgroundColor = config.headerBackgroundColor
    }

    var cells: [UIView] = []
    for (colIndex, text) in texts.enumerated() {
      let cell = makeCellView(text: text, isHeader: isHeader, columnIndex: colIndex, alignments: alignments, config: config, configuration: configuration)
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
    isHeader: Bool,
    columnIndex: Int,
    alignments: [Table.ColumnAlignment?],
    config: InkAppearance.Table,
    configuration: InkConfiguration
  ) -> UIView {
    let cellView = UIView()

    let baseFont: UIFont
    let textColor: UIColor
    if isHeader {
      baseFont = configuration.appearance.scaledFont(.systemFont(ofSize: config.headerFontSize, weight: .bold), textStyle: .body)
      textColor = config.headerColor
    } else {
      baseFont = configuration.appearance.scaledFont(.systemFont(ofSize: config.bodyFontSize, weight: .regular), textStyle: .body)
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

    let scaledLineHeight = configuration.appearance.scaledValue(config.lineHeight, textStyle: .body)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.minimumLineHeight = scaledLineHeight
    paragraphStyle.maximumLineHeight = scaledLineHeight
    paragraphStyle.alignment = textAlignment
    paragraphStyle.lineBreakMode = .byCharWrapping

    let baselineOffset = (config.lineHeight - baseFont.lineHeight) / 2

    // 解析内联 Markdown（加粗/斜体/行内代码/链接 + 自定义 Directive），与正文共用 configuration
    let inlineAttr = InkAttributedRenderer.renderInline(text, configuration: configuration, baseFont: baseFont, textColor: textColor)
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

  /// 测量各列最大内容宽度（含 padding，受 maxWidthRatio 限制）。
  /// 使用渲染后的 attributed string 测量，自动适配所有内联样式。
  static func measureColumnContentWidths(headers: [String], rows: [[String]], config: InkAppearance.Table, configuration: InkConfiguration, containerWidth: CGFloat = UIScreen.main.bounds.width) -> [CGFloat] {
    let colCount = headers.count
    guard colCount > 0 else { return [] }

    let headerFont = UIFont.systemFont(ofSize: config.headerFontSize, weight: .bold)
    let bodyFont = UIFont.systemFont(ofSize: config.bodyFontSize)
    let maxColumnWidth = containerWidth * config.columnMaxWidthRatio
    var widths: [CGFloat] = Array(repeating: 0, count: colCount)

    for colIndex in 0..<colCount {
      let headerAttr = InkAttributedRenderer.renderInline(headers[colIndex], configuration: configuration, baseFont: headerFont, textColor: .label)
      let headerWidth = ceil(headerAttr.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).width)
      widths[colIndex] = headerWidth

      for row in rows {
        guard colIndex < row.count else { continue }
        let cellAttr = InkAttributedRenderer.renderInline(row[colIndex], configuration: configuration, baseFont: bodyFont, textColor: .label)
        let cellWidth = ceil(cellAttr.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil).width)
        widths[colIndex] = max(widths[colIndex], cellWidth)
      }
      widths[colIndex] = min(widths[colIndex] + config.horizontalPadding * 2, maxColumnWidth)
    }
    return widths
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
