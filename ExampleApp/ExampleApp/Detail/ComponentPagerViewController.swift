import UIKit
import InkMarkdown
import JXSegmentedView
import SnapKit

/// 单个 Markdown 组件的 Pager 详情页：Segmented + 横滑子页（源码 / 标准 / 自定义样式）。
final class ComponentPagerViewController: UIViewController {

  private let component: MarkdownComponent
  private let segmentedView = JXSegmentedView()
  private let segmentedDataSource = JXSegmentedTitleDataSource()
  private lazy var listContainerView = JXSegmentedListContainerView(dataSource: self)

  /// tab 顺序：[源码, 标准, ...customStyles]
  private lazy var listVCs: [JXSegmentedListContainerViewListDelegate & PagerListController] = buildListViewControllers()

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
    title = component.displayName

    navigationItem.rightBarButtonItem = UIBarButtonItem(
      image: UIImage(systemName: "questionmark.circle"),
      style: .plain,
      target: self,
      action: #selector(showHelp)
    )

    setupSegmented()
    setupContainer()
  }

  // MARK: - Help

  @objc private func showHelp() {
    let helpVC = ComponentHelpViewController(component: component)
    helpVC.modalPresentationStyle = .popover
    helpVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
    helpVC.popoverPresentationController?.delegate = self
    helpVC.preferredContentSize = CGSize(width: 280, height: 220)
    present(helpVC, animated: true)
  }

  // MARK: - Layout

  private func setupSegmented() {
    segmentedDataSource.titles = listVCs.map(\.tabTitle)
    segmentedDataSource.titleNormalColor = .secondaryLabel
    segmentedDataSource.titleSelectedColor = .label
    segmentedDataSource.titleNormalFont = .systemFont(ofSize: 15, weight: .regular)
    segmentedDataSource.titleSelectedFont = .systemFont(ofSize: 15, weight: .semibold)
    segmentedDataSource.isTitleColorGradientEnabled = true

    let indicator = JXSegmentedIndicatorLineView()
    indicator.indicatorColor = .label
    indicator.indicatorWidth = JXSegmentedViewAutomaticDimension
    indicator.indicatorHeight = 2

    segmentedView.dataSource = segmentedDataSource
    segmentedView.indicators = [indicator]
    segmentedView.listContainer = listContainerView

    view.addSubview(segmentedView)
    segmentedView.snp.makeConstraints { make in
      make.top.equalTo(view.safeAreaLayoutGuide)
      make.leading.trailing.equalToSuperview()
      make.height.equalTo(44)
    }
  }

  private func setupContainer() {
    view.addSubview(listContainerView)
    listContainerView.snp.makeConstraints { make in
      make.top.equalTo(segmentedView.snp.bottom)
      make.leading.trailing.bottom.equalToSuperview()
    }
  }

  private func buildListViewControllers() -> [JXSegmentedListContainerViewListDelegate & PagerListController] {
    let sample = component.standardSample
    var vcs: [JXSegmentedListContainerViewListDelegate & PagerListController] = []
    vcs.append(SourceListViewController(source: sample))
    vcs.append(RenderedListViewController(source: sample, style: .standard))
    for custom in component.customStyles {
      vcs.append(RenderedListViewController(source: sample, style: custom))
    }
    return vcs
  }
}

// MARK: - JXSegmentedListContainerViewDataSource

extension ComponentPagerViewController: JXSegmentedListContainerViewDataSource {

  func numberOfLists(in listContainerView: JXSegmentedListContainerView) -> Int {
    listVCs.count
  }

  func listContainerView(
    _ listContainerView: JXSegmentedListContainerView,
    initListAt index: Int
  ) -> JXSegmentedListContainerViewListDelegate {
    listVCs[index]
  }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension ComponentPagerViewController: UIPopoverPresentationControllerDelegate {

  func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
    .none
  }
}
