import UIKit
import InkMarkdown

/// 公式与图表失败时的显式错误条：标题 / 原因 + 可选展开源码。
///
/// ExampleApp 层组件。库默认失败仍走 `failureFallback`（如源码代码块）；
/// 本视图通过 `InkImageRendering.onLoadFinished` 叠加显式错误 UX，不替代库契约。
final class GeneratedContentErrorBannerView: UIView {

  private let titleLabel = UILabel()
  private let reasonLabel = UILabel()
  private let toggleButton = UIButton(type: .system)
  private let sourceTextView = UITextView()
  private let stack = UIStackView()

  private var sourceCode: String?
  private var isExpanded = false

  /// 展开/收起源码导致高度变化时通知宿主（D2）。
  var onLayoutChange: (() -> Void)?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// - Parameters:
  ///   - title: 错误条主标题。
  ///   - reason: 简短原因说明。
  ///   - sourceCode: 可选源码；非空时显示「查看源码」展开。
  func configure(title: String, reason: String, sourceCode: String?) {
    titleLabel.text = title
    reasonLabel.text = reason
    self.sourceCode = sourceCode
    sourceTextView.text = sourceCode
    let hasSource = !(sourceCode?.isEmpty ?? true)
    toggleButton.isHidden = !hasSource
    sourceTextView.isHidden = true
    isExpanded = false
    toggleButton.setTitle("查看源码", for: .normal)
    isHidden = false
  }

  func reset() {
    isHidden = true
    isExpanded = false
    sourceTextView.isHidden = true
    toggleButton.setTitle("查看源码", for: .normal)
  }

  private func setup() {
    backgroundColor = UIColor.systemRed.withAlphaComponent(0.08)
    layer.cornerRadius = 10
    layer.cornerCurve = .continuous
    layer.borderWidth = 1
    layer.borderColor = UIColor.systemRed.withAlphaComponent(0.35).cgColor

    titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
    titleLabel.textColor = .systemRed
    titleLabel.numberOfLines = 0

    reasonLabel.font = .systemFont(ofSize: 13)
    reasonLabel.textColor = .secondaryLabel
    reasonLabel.numberOfLines = 0

    toggleButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
    toggleButton.contentHorizontalAlignment = .leading
    toggleButton.addTarget(self, action: #selector(toggleSource), for: .touchUpInside)

    sourceTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    sourceTextView.isEditable = false
    sourceTextView.isScrollEnabled = false
    sourceTextView.backgroundColor = UIColor.secondarySystemBackground
    sourceTextView.layer.cornerRadius = 6
    sourceTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    sourceTextView.isHidden = true

    stack.axis = .vertical
    stack.spacing = 6
    stack.alignment = .fill
    [titleLabel, reasonLabel, toggleButton, sourceTextView].forEach { stack.addArrangedSubview($0) }

    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
    ])

    isHidden = true
  }

  @objc private func toggleSource() {
    isExpanded.toggle()
    sourceTextView.isHidden = !isExpanded
    toggleButton.setTitle(isExpanded ? "收起源码" : "查看源码", for: .normal)
    invalidateIntrinsicContentSize()
    onLayoutChange?()
  }
}

/// 包装生成图块：成功隐藏错误条；失败显示统一错误条（库仍可展示 sourceCode fallback）。
final class GeneratedContentImageHostView: UIView, SSETypewriterSegment {

  private let stack = UIStackView()
  private let banner = GeneratedContentErrorBannerView()
  private let imageBlock: InkImageBlock
  private let failureTitle: String
  private let failureReason: String
  
  private var lastReportedHeight: CGFloat = 0

  var canonicalID: String { imageBlock.source.canonicalID }

  /// 块级图/错误条高度变化时回调（D2：供 tableView 刷新行高）。
  var onHeightChange: (() -> Void)?

  init(
    imageBlock: InkImageBlock,
    failureTitle: String = "公式与图表渲染失败",
    failureReason: String = "本地生成未成功。库已回退源码展示；可展开查看原始输入。"
  ) {
    self.imageBlock = imageBlock
    self.failureTitle = failureTitle
    self.failureReason = failureReason
    super.init(frame: .zero)

    stack.axis = .vertical
    stack.spacing = 8
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)

    banner.translatesAutoresizingMaskIntoConstraints = false
    imageBlock.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(banner)
    stack.addArrangedSubview(imageBlock)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: topAnchor),
      stack.leadingAnchor.constraint(equalTo: leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    banner.onLayoutChange = { [weak self] in
      guard let self else { return }
      self.invalidateIntrinsicContentSize()
      self.setNeedsLayout()
      self.onHeightChange?()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func handleLoadFinished(image: UIImage?) {
    if image == nil {
      banner.configure(
        title: failureTitle,
        reason: failureReason,
        sourceCode: imageBlock.source.generatedRequest?.source
      )
    } else {
      banner.reset()
    }
    invalidateIntrinsicContentSize()
    setNeedsLayout()
    onHeightChange?()
  }

  override var intrinsicContentSize: CGSize {
    let width = bounds.width > 0 ? bounds.width : UIView.layoutFittingExpandedSize.width
    let size = stack.systemLayoutSizeFitting(
      CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: bounds.width > 0 ? .required : .fittingSizeLevel,
      verticalFittingPriority: .fittingSizeLevel
    )
    return size
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let height = intrinsicContentSize.height
    if abs(height - lastReportedHeight) > 0.5 {
      lastReportedHeight = height
      onHeightChange?()
    }
  }

  // MARK: - SSETypewriterSegment

  var typewriterLength: Int { 1 }

  func setVisibleLength(_ length: Int) {
    isHidden = length < 1
    if length >= 1 {
      setNeedsLayout()
      layoutIfNeeded()
    }
  }
}

/// 生成内容失败观察：在 render 前挂到 `appearance.imageRendering.onLoadFinished`，
/// render 后把 generated `InkImageBlock` 包进 ``GeneratedContentImageHostView``。
final class GeneratedContentFailureObserver {

  private var hosts: [String: GeneratedContentImageHostView] = [:]

  func attach(to appearance: inout InkAppearance) {
    appearance.imageRendering.onLoadFinished = { [weak self] source, image in
      guard source.scheme == .generated else { return }
      self?.hosts[source.canonicalID]?.handleLoadFinished(image: image)
    }
  }

  /// 复用已有宿主时重新登记，保证新的 onLoadFinished 仍能命中。
  func register(_ host: GeneratedContentImageHostView) {
    hosts[host.canonicalID] = host
  }

  func makeView(for block: InkRenderableBlock) -> UIView {
    guard let imageBlock = block as? InkImageBlock, imageBlock.source.scheme == .generated else {
      return block.makeView()
    }
    let host = GeneratedContentImageHostView(imageBlock: imageBlock)
    hosts[host.canonicalID] = host
    return host
  }

  func makeSegment(for block: InkRenderableBlock) -> SSETypewriterSegment? {
    if let imageBlock = block as? InkImageBlock, imageBlock.source.scheme == .generated {
      let host = GeneratedContentImageHostView(imageBlock: imageBlock)
      hosts[host.canonicalID] = host
      return host
    }
    if let imageBlock = block as? InkImageBlock {
      return SSEImageSegmentView(imageBlock: imageBlock)
    }
    if let textBlock = block as? InkAttributedTextBlock {
      return SSETextSegmentView(attributedText: textBlock.attributedText)
    }
    return block.makeView() as? SSETypewriterSegment
  }
}
