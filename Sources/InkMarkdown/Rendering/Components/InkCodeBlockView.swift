import UIKit

/// 代码块 Block：圆角灰背容器内渲染等宽字体代码。
public struct InkCodeBlock: InkRenderableBlock {
  public let code: String
  public let language: String?
  public var config: InkAppearance.CodeBlock

  public init(
    code: String,
    language: String? = nil,
    config: InkAppearance.CodeBlock = InkAppearance.shared.codeBlock
  ) {
    self.code = code
    self.language = language
    self.config = config
  }

  public func makeView() -> UIView {
    InkCodeBlockViewFactory.makeView(code: code, language: language, config: config)
  }
}

// MARK: - 内部工厂

enum InkCodeBlockViewFactory {
  static func makeView(code: String, language: String?, config: InkAppearance.CodeBlock) -> UIView {
    InkCodeBlockViewImpl(code: code, language: language, config: config)
  }
}

// MARK: - 内部实现

final class InkCodeBlockViewImpl: UIView {

  private let code: String
  private let language: String?
  private let config: InkAppearance.CodeBlock
  private let container = UIView()
  private let label = UILabel()

  init(code: String, language: String?, config: InkAppearance.CodeBlock) {
    self.code = code
    self.language = language
    self.config = config
    super.init(frame: .zero)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    container.backgroundColor = config.backgroundColor
    container.layer.cornerRadius = config.cornerRadius
    container.layer.cornerCurve = .continuous
    container.clipsToBounds = true
    addSubview(container)

    label.numberOfLines = 0
    container.addSubview(label)

    let font = UIFont.monospacedSystemFont(ofSize: config.fontSize, weight: .regular)

    let para = NSMutableParagraphStyle()
    para.minimumLineHeight = config.lineHeight
    para.maximumLineHeight = config.lineHeight
    para.lineSpacing = 0

    let offset = max(0, (config.lineHeight - font.lineHeight) / 2)

    let trimmed = code.hasSuffix("\n") ? String(code.dropLast()) : code

    label.attributedText = NSAttributedString(
      string: trimmed,
      attributes: [
        .font: font,
        .foregroundColor: config.textColor,
        .paragraphStyle: para,
        .baselineOffset: offset,
      ]
    )

    isAccessibilityElement = true
    accessibilityLabel = language.map { "\($0) 代码块" } ?? "代码块"
    accessibilityValue = trimmed
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let targetWidth = size.width > 0 ? size.width : (bounds.width > 0 ? bounds.width : 320)
    let contentWidth = max(0, targetWidth - config.horizontalPadding * 2)
    let labelSize = label.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
    let totalHeight = labelSize.height + config.verticalPadding * 2 + config.spacingToText
    return CGSize(width: targetWidth, height: ceil(totalHeight))
  }

  override var intrinsicContentSize: CGSize {
    sizeThatFits(CGSize(width: bounds.width > 0 ? bounds.width : UIView.noIntrinsicMetric, height: .greatestFiniteMagnitude))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let width = bounds.width
    let height = bounds.height
    guard width > 0, height > 0 else { return }

    let containerHeight = max(0, height - config.spacingToText)
    container.frame = CGRect(x: 0, y: 0, width: width, height: containerHeight)

    let labelWidth = max(0, width - config.horizontalPadding * 2)
    let labelHeight = max(0, containerHeight - config.verticalPadding * 2)
    label.frame = CGRect(x: config.horizontalPadding, y: config.verticalPadding, width: labelWidth, height: labelHeight)
  }
}

