import UIKit

/// 分割线 Block：顶部一条细线 + 下方留白。
public struct InkThematicBreakBlock: InkRenderableBlock {
  public let config: InkAppearance.ThematicBreak

  public init(config: InkAppearance.ThematicBreak = InkAppearance.shared.thematicBreak) {
    self.config = config
  }

  public func makeView() -> UIView {
    InkThematicBreakView(config: config)
  }
}

// MARK: - 内部视图实现

final class InkThematicBreakView: UIView {

  private let config: InkAppearance.ThematicBreak
  private let lineView = UIView()

  init(config: InkAppearance.ThematicBreak) {
    self.config = config
    super.init(frame: .zero)
    backgroundColor = .clear
    lineView.backgroundColor = config.color
    addSubview(lineView)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
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

