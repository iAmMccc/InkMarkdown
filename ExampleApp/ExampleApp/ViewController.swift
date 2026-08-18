//
//  ViewController.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import UIKit
import InkMarkdown

/// 第一层：大分类入口列表（UIKit 渲染引擎 vs SwiftUI 适配器）。
class StoreViewController: DemoListViewController {

  private let categories = MainCategory.allCases

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "InkMarkdown Demo"
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    categories.count
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    "UI 框架架构选择"
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    "请选择测试环境进入对应的功能测试集。两套框架下的测试集功能保持 1:1 对齐。"
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let category = categories[indexPath.row]
    return dequeueSubtitleCell(title: category.title, subtitle: category.subtitle)
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    super.tableView(tableView, didSelectRowAt: indexPath)
    let category = categories[indexPath.row]
    let listVC = CategoryListViewController(mainCategory: category)
    navigationController?.pushViewController(listVC, animated: true)
  }
}
