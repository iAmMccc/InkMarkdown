import UIKit
import InkMarkdown

/// 业务卡片样式 H1：浅紫圆角卡片 + ✦ 前缀图标 + 主标题 + 右侧"查看集团成员 ›" accessory。
struct H1ActionCardBlock: InkRenderableBlock {
  let title: String
  /// 仅当该卡片需要 accessory 时设置；其余卡片只展示「✦ + 加粗标题」。
  let accessory: Accessory?

  struct Accessory {
    let text: String
    let alertTitle: String
    let alertMessage: String
  }

  func makeView() -> UIView {
    H1ActionCardView(title: title, accessory: accessory)
  }
}

private final class H1ActionCardView: UIView {

  private let accessory: H1ActionCardBlock.Accessory?

  init(title: String, accessory: H1ActionCardBlock.Accessory?) {
    self.accessory = accessory
    super.init(frame: .zero)
    setup(title: title)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setup(title: String) {
    let card = UIView()
    card.backgroundColor = UIColor(red: 0.93, green: 0.92, blue: 1.0, alpha: 1)
    card.layer.cornerRadius = 12
    card.layer.cornerCurve = .continuous
    card.translatesAutoresizingMaskIntoConstraints = false
    addSubview(card)
    NSLayoutConstraint.activate([
      card.topAnchor.constraint(equalTo: topAnchor, constant: 4),
      card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
      card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
    ])

    let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
    let iconView = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: iconConfig))
    iconView.tintColor = UIColor(red: 0.45, green: 0.40, blue: 0.95, alpha: 1)
    iconView.setContentHuggingPriority(.required, for: .horizontal)
    iconView.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(iconView)

    let titleLabel = UILabel()
    titleLabel.text = title
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    titleLabel.textColor = .label
    titleLabel.numberOfLines = 1
    titleLabel.adjustsFontSizeToFitWidth = true
    titleLabel.minimumScaleFactor = 0.8
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(titleLabel)

    NSLayoutConstraint.activate([
      iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
      iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 22),
      iconView.heightAnchor.constraint(equalToConstant: 22),
    ])

    if let accessory {
      let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
      chevron.tintColor = .tertiaryLabel
      chevron.setContentHuggingPriority(.required, for: .horizontal)
      chevron.translatesAutoresizingMaskIntoConstraints = false
      card.addSubview(chevron)

      let accessoryLabel = UILabel()
      accessoryLabel.text = accessory.text
      accessoryLabel.font = .systemFont(ofSize: 14, weight: .regular)
      accessoryLabel.textColor = .secondaryLabel
      accessoryLabel.setContentHuggingPriority(.required, for: .horizontal)
      accessoryLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
      accessoryLabel.translatesAutoresizingMaskIntoConstraints = false
      card.addSubview(accessoryLabel)

      NSLayoutConstraint.activate([
        chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
        chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),

        accessoryLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -4),
        accessoryLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

        titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
        titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: accessoryLabel.leadingAnchor, constant: -12),
        titleLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
        titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
      ])

      let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
      card.addGestureRecognizer(tap)
      card.isUserInteractionEnabled = true
    } else {
      NSLayoutConstraint.activate([
        titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
        titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        titleLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
        titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
      ])
    }
  }

  @objc private func handleTap() {
    guard
      let accessory,
      let scene = window?.windowScene,
      let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
    else { return }

    var top = root
    while let presented = top.presentedViewController { top = presented }

    let alert = UIAlertController(
      title: accessory.alertTitle,
      message: accessory.alertMessage,
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "好的", style: .default))
    top.present(alert, animated: true)
  }
}
