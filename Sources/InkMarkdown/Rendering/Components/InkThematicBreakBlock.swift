import UIKit

/// 分割线 Block：顶部一条细线 + 下方留白。
public struct InkThematicBreakBlock: InkRenderableBlock {
  public let config: InkAppearance.ThematicBreak

  public init(config: InkAppearance.ThematicBreak = InkAppearance.shared.thematicBreak) {
    self.config = config
  }

  public func makeView() -> UIView {
    let container = UIView()
    container.backgroundColor = .clear
    container.translatesAutoresizingMaskIntoConstraints = false
    container.heightAnchor.constraint(equalToConstant: config.lineThickness + config.spacingAfter).isActive = true

    let line = UIView()
    line.backgroundColor = config.color
    line.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(line)
    NSLayoutConstraint.activate([
      line.topAnchor.constraint(equalTo: container.topAnchor),
      line.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      line.heightAnchor.constraint(equalToConstant: config.lineThickness),
    ])

    return container
  }
}
