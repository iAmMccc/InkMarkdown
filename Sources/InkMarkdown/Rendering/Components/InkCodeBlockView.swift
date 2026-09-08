import UIKit

/// 代码块 Block：圆角灰背容器内渲染等宽字体代码。
public struct InkCodeBlock: InkRenderableBlock, InkReusableBlock {
  public let code: String
  public let language: String?
  public var config: InkAppearance.CodeBlock
  /// 完整渲染配置，供 Dynamic Type 缩放读取 ``InkRenderEnvironment/traitCollection``。
  public var renderConfiguration: InkConfiguration

  @MainActor
  public init(
    code: String,
    language: String? = nil
  ) {
    self.init(code: code, language: language, config: InkAppearance.shared.codeBlock, renderConfiguration: .standard)
  }

  public init(
    code: String,
    language: String? = nil,
    config: InkAppearance.CodeBlock
  ) {
    self.init(code: code, language: language, config: config, renderConfiguration: .standard)
  }

  public init(
    code: String,
    language: String? = nil,
    config: InkAppearance.CodeBlock,
    renderConfiguration: InkConfiguration
  ) {
    self.code = code
    self.language = language
    self.config = config
    self.renderConfiguration = renderConfiguration
  }

  @MainActor public func makeView() -> UIView {
    InkCodeBlockViewFactory.makeView(
      code: code,
      language: language,
      config: config,
      appearance: renderConfiguration.appearance,
      scalingTraitCollection: renderConfiguration.renderEnvironment.traitCollection
    )
  }

  @MainActor
  public func updateExistingView(_ view: UIView) -> Bool {
    guard let impl = view as? InkCodeBlockViewImpl else { return false }
    impl.apply(
      code: code,
      language: language,
      config: config,
      appearance: renderConfiguration.appearance,
      scalingTraitCollection: renderConfiguration.renderEnvironment.traitCollection
    )
    return true
  }

  @MainActor
  public func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    guard let previous = previous as? InkCodeBlock else { return false }
    return code == previous.code
      && language == previous.language
      && config == previous.config
      && renderConfiguration.isSemanticallyEqualTo(previous.renderConfiguration)
  }
}

// MARK: - 内部工厂

enum InkCodeBlockViewFactory {
  @MainActor static func makeView(
    code: String,
    language: String?,
    config: InkAppearance.CodeBlock,
    appearance: InkAppearance,
    scalingTraitCollection: UITraitCollection? = nil
  ) -> UIView {
    InkCodeBlockViewImpl(
      code: code,
      language: language,
      config: config,
      appearance: appearance,
      scalingTraitCollection: scalingTraitCollection
    )
  }
}

// MARK: - 内部实现

final class InkCodeBlockViewImpl: UIView {

  private let code: String
  private let language: String?
  private let config: InkAppearance.CodeBlock
  private var appearance: InkAppearance
  private var scalingTraitCollection: UITraitCollection?
  private let container = UIView()
  private let label = UILabel()

  init(
    code: String,
    language: String?,
    config: InkAppearance.CodeBlock,
    appearance: InkAppearance,
    scalingTraitCollection: UITraitCollection? = nil
  ) {
    self.code = code
    self.language = language
    self.config = config
    self.appearance = appearance
    self.scalingTraitCollection = scalingTraitCollection
    super.init(frame: .zero)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup() {
    apply(
      code: code,
      language: language,
      config: config,
      appearance: appearance,
      scalingTraitCollection: scalingTraitCollection
    )
  }

  func apply(
    code: String,
    language: String?,
    config: InkAppearance.CodeBlock,
    appearance: InkAppearance,
    scalingTraitCollection: UITraitCollection?
  ) {
    self.appearance = appearance
    self.scalingTraitCollection = scalingTraitCollection

    container.backgroundColor = config.backgroundColor
    container.layer.cornerRadius = config.cornerRadius
    container.layer.cornerCurve = .continuous
    container.clipsToBounds = true
    addSubview(container)

    label.numberOfLines = 0
    label.adjustsFontForContentSizeCategory = true
    container.addSubview(label)

    let font = appearance.scaledFont(
      UIFont.monospacedSystemFont(ofSize: config.fontSize, weight: .regular),
      textStyle: .body,
      compatibleWith: scalingTraitCollection
    )

    let scaledLineHeight = appearance.scaledValue(config.lineHeight, textStyle: .body, compatibleWith: scalingTraitCollection)
    let para = NSMutableParagraphStyle()
    para.minimumLineHeight = scaledLineHeight
    para.maximumLineHeight = scaledLineHeight
    para.lineSpacing = 0

    let offset = max(0, (scaledLineHeight - font.lineHeight) / 2)

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
    invalidateIntrinsicContentSize()
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let targetWidth = InkDisplayMetrics.resolvedMeasurementWidth(
      proposal: size.width,
      bounds: bounds.width
    )
    guard targetWidth > 0 else {
      return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
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
