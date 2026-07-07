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
    InkCodeBlockViewImpl(code: code, language: language, config: config)
  }
}

// MARK: - 内部实现

private final class InkCodeBlockViewImpl: UIView {

  private let code: String
  private let language: String?
  private let config: InkAppearance.CodeBlock

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
    let container = UIView()
    container.backgroundColor = config.backgroundColor
    container.layer.cornerRadius = config.cornerRadius
    container.layer.cornerCurve = .continuous
    container.clipsToBounds = true
    container.translatesAutoresizingMaskIntoConstraints = false
    addSubview(container)

    NSLayoutConstraint.activate([
      // 规范总纲：上方不设间距（top=0），下方间距由 spacingToText 承担（规范：4）。
      container.topAnchor.constraint(equalTo: topAnchor),
      container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -config.spacingToText),
      container.leadingAnchor.constraint(equalTo: leadingAnchor),
      container.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])

    let label = UILabel()
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(label)

    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: container.topAnchor, constant: config.verticalPadding),
      label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -config.verticalPadding),
      label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: config.horizontalPadding),
      label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -config.horizontalPadding),
    ])

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
  }
}
