import UIKit

/// ❓ 按钮弹出的组件说明气泡。
final class ComponentHelpViewController: UIViewController {

  private let component: MarkdownComponent

  init(component: MarkdownComponent) {
    self.component = component
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let titleLabel = UILabel()
    titleLabel.text = component.displayName
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    titleLabel.textColor = .label
    titleLabel.numberOfLines = 0

    let body = UITextView()
    body.isEditable = false
    body.isScrollEnabled = true
    body.backgroundColor = .clear
    body.textContainerInset = .zero
    body.textContainer.lineFragmentPadding = 0

    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 4
    body.attributedText = NSAttributedString(
      string: component.helpDescription,
      attributes: [
        .font: UIFont.systemFont(ofSize: 13),
        .foregroundColor: UIColor.secondaryLabel,
        .paragraphStyle: paragraph,
      ]
    )

    let stack = UIStackView(arrangedSubviews: [titleLabel, body])
    stack.axis = .vertical
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
    ])
  }
}
