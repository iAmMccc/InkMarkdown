import UIKit
import SnapKit
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
    addSubview(card)
    card.snp.makeConstraints { make in
      make.top.bottom.equalToSuperview().inset(4)
      make.leading.trailing.equalToSuperview().inset(16)
    }

    let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
    let iconView = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: iconConfig))
    iconView.tintColor = UIColor(red: 0.45, green: 0.40, blue: 0.95, alpha: 1)
    iconView.setContentHuggingPriority(.required, for: .horizontal)
    card.addSubview(iconView)

    let titleLabel = UILabel()
    titleLabel.text = title
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    titleLabel.textColor = .label
    titleLabel.numberOfLines = 1
    titleLabel.adjustsFontSizeToFitWidth = true
    titleLabel.minimumScaleFactor = 0.8
    card.addSubview(titleLabel)

    iconView.snp.makeConstraints { make in
      make.leading.equalToSuperview().inset(16)
      make.centerY.equalToSuperview()
      make.width.height.equalTo(22)
    }

    if let accessory {
      let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
      chevron.tintColor = .tertiaryLabel
      chevron.setContentHuggingPriority(.required, for: .horizontal)
      card.addSubview(chevron)

      let accessoryLabel = UILabel()
      accessoryLabel.text = accessory.text
      accessoryLabel.font = .systemFont(ofSize: 14, weight: .regular)
      accessoryLabel.textColor = .secondaryLabel
      accessoryLabel.setContentHuggingPriority(.required, for: .horizontal)
      accessoryLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
      card.addSubview(accessoryLabel)

      chevron.snp.makeConstraints { make in
        make.trailing.equalToSuperview().inset(14)
        make.centerY.equalToSuperview()
      }
      accessoryLabel.snp.makeConstraints { make in
        make.trailing.equalTo(chevron.snp.leading).offset(-4)
        make.centerY.equalToSuperview()
      }
      titleLabel.snp.makeConstraints { make in
        make.leading.equalTo(iconView.snp.trailing).offset(8)
        make.trailing.lessThanOrEqualTo(accessoryLabel.snp.leading).offset(-12)
        make.centerY.equalToSuperview()
        make.top.bottom.equalToSuperview().inset(16)
      }

      let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
      card.addGestureRecognizer(tap)
      card.isUserInteractionEnabled = true
    } else {
      titleLabel.snp.makeConstraints { make in
        make.leading.equalTo(iconView.snp.trailing).offset(8)
        make.trailing.equalToSuperview().inset(16)
        make.centerY.equalToSuperview()
        make.top.bottom.equalToSuperview().inset(16)
      }
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
