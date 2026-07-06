import UIKit

/// Demo 列表基类：提供 insetGrouped 的 UITableView + subtitle cell 的通用骨架。
/// 子类只需实现数据源方法和跳转逻辑。
class DemoListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

  let tableView = UITableView(frame: .zero, style: .insetGrouped)

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    tableView.dataSource = self
    tableView.delegate = self
    tableView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
  }

  // MARK: - 子类重写

  func numberOfSections(in tableView: UITableView) -> Int { 1 }
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 0 }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    UITableViewCell()
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { nil }
  func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { nil }

  // MARK: - 便捷方法

  func dequeueSubtitleCell(title: String, subtitle: String) -> UITableViewCell {
    let reuseID = "subtitleCell"
    let cell = tableView.dequeueReusableCell(withIdentifier: reuseID)
      ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
    cell.textLabel?.text = title
    cell.detailTextLabel?.text = subtitle
    cell.detailTextLabel?.textColor = .secondaryLabel
    cell.accessoryType = .disclosureIndicator
    return cell
  }
}
