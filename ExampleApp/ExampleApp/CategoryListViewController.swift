import UIKit
import InkMarkdown

/// 第二层：分类下的子列表，点击进入详情。
final class CategoryListViewController: DemoListViewController {

  private let category: DemoCategory
  private let sections: [DemoSection]

  init(category: DemoCategory) {
    self.category = category
    switch category {
    case .markdownStandard:
      self.sections = DemoCatalog.markdownStandardSections()
    case .customComponent:
      self.sections = DemoCatalog.customComponentSections()
    case .streaming:
      self.sections = DemoCatalog.streamingSections()
    case .integration:
      self.sections = DemoCatalog.integrationSections()
    }
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = category.title
  }

  // MARK: - DataSource

  override func numberOfSections(in tableView: UITableView) -> Int {
    sections.count
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    sections[section].rows.count
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    sections[section].title
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    sections[section].footer
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let entry = sections[indexPath.section].rows[indexPath.row]
    switch entry {
    case .component(let component):
      return dequeueSubtitleCell(title: component.displayName, subtitle: component.subtitle)
    case .scenario(let scenario):
      return dequeueSubtitleCell(title: scenario.title, subtitle: scenario.subtitle)
    }
  }

  // MARK: - Delegate

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    super.tableView(tableView, didSelectRowAt: indexPath)
    guard let nav = navigationController else { return }

    let entry = sections[indexPath.section].rows[indexPath.row]
    switch entry {
    case .component(let component):
      let pager = ComponentPagerViewController(component: component)
      nav.pushViewController(pager, animated: true)

    case .scenario(let scenario):
      let vc = viewController(for: scenario)
      nav.pushViewController(vc, animated: true)
    }
  }

  private func viewController(for scenario: Scenario) -> UIViewController {
    switch scenario {
    case .comprehensiveReadme:
      return MarkdownDetailViewController(title: scenario.title, resourceName: "comprehensive-readme")
    case .localFile:
      return MarkdownDetailViewController(title: scenario.title, resourceName: "comprehensive-readme")
    case .serverJSON:
      return ServerMarkdownViewController()
    case .sseStreaming:
      return SSEChatViewController()
    case .streamingPerformance:
      return StreamingPerformanceViewController()
    case .imageRenderingDemo:
      return ImageDemoViewController()
    }
  }
}
