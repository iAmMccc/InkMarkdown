import UIKit

/// 第一层：大分类入口列表。
class StoreViewController: DemoListViewController {

  private let categories = DemoCategory.allCases

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "InkMarkdown"
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    categories.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let category = categories[indexPath.row]
    return dequeueSubtitleCell(title: category.title, subtitle: category.subtitle)
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    super.tableView(tableView, didSelectRowAt: indexPath)
    let category = categories[indexPath.row]
    let listVC = CategoryListViewController(category: category)
    navigationController?.pushViewController(listVC, animated: true)
  }
}
