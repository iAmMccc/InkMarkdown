import UIKit
import InkMarkdown

/// 单个 Markdown 组件的 Pager 详情页：Segmented + 横滑子页（源码 / 标准 / 自定义样式）。
///
/// 原生实现：顶部 `UISegmentedControl` 控制 tab，下方分页 `UIScrollView` 承载各子 VC，
/// segment 点击与横滑手势双向同步。替代原先的 JXSegmentedView 依赖。
final class ComponentPagerViewController: UIViewController {

  private let component: MarkdownComponent

  private let segmentedControl = UISegmentedControl()
  private let pagingScrollView: UIScrollView = {
    let sv = UIScrollView()
    sv.isPagingEnabled = true
    sv.showsHorizontalScrollIndicator = false
    sv.alwaysBounceVertical = false
    sv.contentInsetAdjustmentBehavior = .never
    return sv
  }()
  private let pagesStack = UIStackView()

  /// tab 顺序：开启态/主样式 → 自定义(含标准关闭态) → 源码
  private lazy var listVCs: [PagerListController] = buildListViewControllers()

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
    setupPaging()
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
    for (index, vc) in listVCs.enumerated() {
      segmentedControl.insertSegment(withTitle: vc.tabTitle, at: index, animated: false)
    }
    segmentedControl.selectedSegmentIndex = 0
    segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

    segmentedControl.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(segmentedControl)
    NSLayoutConstraint.activate([
      segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
      segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
    ])
  }

  private func setupPaging() {
    pagingScrollView.delegate = self
    pagingScrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(pagingScrollView)
    NSLayoutConstraint.activate([
      pagingScrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
      pagingScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      pagingScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      pagingScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    pagesStack.axis = .horizontal
    pagesStack.distribution = .fillEqually
    pagesStack.alignment = .fill
    pagesStack.translatesAutoresizingMaskIntoConstraints = false
    pagingScrollView.addSubview(pagesStack)

    // stack 固定在 scrollView 的 contentLayoutGuide 上，高度对齐 frameLayoutGuide，
    // 宽度 = 页数 × 可视宽度 → 形成横向分页。
    NSLayoutConstraint.activate([
      pagesStack.topAnchor.constraint(equalTo: pagingScrollView.contentLayoutGuide.topAnchor),
      pagesStack.bottomAnchor.constraint(equalTo: pagingScrollView.contentLayoutGuide.bottomAnchor),
      pagesStack.leadingAnchor.constraint(equalTo: pagingScrollView.contentLayoutGuide.leadingAnchor),
      pagesStack.trailingAnchor.constraint(equalTo: pagingScrollView.contentLayoutGuide.trailingAnchor),
      pagesStack.heightAnchor.constraint(equalTo: pagingScrollView.frameLayoutGuide.heightAnchor),
    ])

    for vc in listVCs {
      addChild(vc)
      let page = UIView()
      page.translatesAutoresizingMaskIntoConstraints = false

      vc.view.translatesAutoresizingMaskIntoConstraints = false
      page.addSubview(vc.view)
      NSLayoutConstraint.activate([
        vc.view.topAnchor.constraint(equalTo: page.topAnchor),
        vc.view.bottomAnchor.constraint(equalTo: page.bottomAnchor),
        vc.view.leadingAnchor.constraint(equalTo: page.leadingAnchor),
        vc.view.trailingAnchor.constraint(equalTo: page.trailingAnchor),
      ])

      // 先把 page 加进 stack（此时它与 scrollView 才有共同祖先），再绑定宽度到
      // frameLayoutGuide——否则 page 尚无 superview，跨层级约束会崩。
      pagesStack.addArrangedSubview(page)
      page.widthAnchor.constraint(equalTo: pagingScrollView.frameLayoutGuide.widthAnchor).isActive = true

      vc.didMove(toParent: self)
    }
  }

  // MARK: - 同步

  @objc private func segmentChanged() {
    let index = segmentedControl.selectedSegmentIndex
    let offset = CGPoint(x: pagingScrollView.bounds.width * CGFloat(index), y: 0)
    pagingScrollView.setContentOffset(offset, animated: true)
  }

  private func buildListViewControllers() -> [PagerListController] {
    let sample = component.standardSample
    var vcs: [PagerListController] = []
    // 主渲染样式放首位——一进来直接看到效果；自定义样式次之；源码放最后。
    // 图片组件主样式为真图 opt-in（`.imageEnabled`），其余组件仍为 `.standard`。
    vcs.append(RenderedListViewController(source: sample, style: component.primaryRenderStyle))
    for custom in component.customStyles {
      vcs.append(RenderedListViewController(source: sample, style: custom))
    }
    vcs.append(SourceListViewController(source: sample))
    return vcs
  }
}

// MARK: - UIScrollViewDelegate（横滑 → 同步 segment）

extension ComponentPagerViewController: UIScrollViewDelegate {

  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    syncSegmentToScroll()
  }

  func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    syncSegmentToScroll()
  }

  private func syncSegmentToScroll() {
    guard pagingScrollView.bounds.width > 0 else { return }
    let index = Int(round(pagingScrollView.contentOffset.x / pagingScrollView.bounds.width))
    if index >= 0 && index < listVCs.count {
      segmentedControl.selectedSegmentIndex = index
    }
  }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension ComponentPagerViewController: UIPopoverPresentationControllerDelegate {

  func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
    .none
  }
}
