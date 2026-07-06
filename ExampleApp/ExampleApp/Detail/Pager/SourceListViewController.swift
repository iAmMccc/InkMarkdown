import UIKit
import JXSegmentedView

/// 源码 tab：等宽字体展示 Markdown 原文。
final class SourceListViewController: UIViewController, PagerListController, JXSegmentedListContainerViewListDelegate {

  let tabTitle = "源码"

  private let source: String
  private let textView = UITextView()

  init(source: String) {
    self.source = source
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    textView.isEditable = false
    textView.isSelectable = true
    textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    textView.text = source
    textView.textColor = .label
    textView.backgroundColor = .systemBackground
    textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    textView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(textView)

    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: view.topAnchor),
      textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
  }

  @objc func listView() -> UIView { view }
}
