import UIKit

/// 分割线 Block：顶部一条细线 + 下方留白。
public struct InkThematicBreakBlock: InkRenderableBlock, InkReusableBlock {
  public let config: InkAppearance.ThematicBreak

  @MainActor
  public init() {
    self.init(config: InkAppearance.shared.thematicBreak)
  }

  public init(config: InkAppearance.ThematicBreak) {
    self.config = config
  }

  @MainActor public func makeView() -> UIView {
    InkThematicBreakView(config: config)
  }

  @MainActor
  public func updateExistingView(_ view: UIView) -> Bool {
    guard let breakView = view as? InkThematicBreakView else { return false }
    breakView.apply(config: config)
    return true
  }

  @MainActor
  public func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    guard let previous = previous as? InkThematicBreakBlock else { return false }
    return config == previous.config
  }
}

// MARK: - 内部视图实现

final class InkThematicBreakView: UIView {

  private var config: InkAppearance.ThematicBreak
  private let lineView = UIView()

  init(config: InkAppearance.ThematicBreak) {
    self.config = config
    super.init(frame: .zero)
    backgroundColor = .clear
    lineView.backgroundColor = config.color
    addSubview(lineView)

    isAccessibilityElement = true
    accessibilityLabel = "分割线"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func apply(config: InkAppearance.ThematicBreak) {
    self.config = config
    lineView.backgroundColor = config.color
    invalidateIntrinsicContentSize()
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let targetWidth = size.width > 0 ? size.width : (bounds.width > 0 ? bounds.width : 320)
    return CGSize(width: targetWidth, height: config.lineThickness + config.spacingAfter)
  }

  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: config.lineThickness + config.spacingAfter)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let width = bounds.width
    guard width > 0 else { return }
    lineView.frame = CGRect(x: 0, y: 0, width: width, height: config.lineThickness)
  }
}
