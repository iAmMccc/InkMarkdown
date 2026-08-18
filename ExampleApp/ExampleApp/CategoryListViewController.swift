//
//  CategoryListViewController.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import UIKit
import SwiftUI
import InkMarkdown
import InkMarkdownSwiftUI

/// 第二层：指定 UI 框架下的功能测试用例列表（UIKit 与 SwiftUI 1:1 对称）。
final class CategoryListViewController: DemoListViewController {

  private let mainCategory: MainCategory
  private let scenarios = DemoScenario.allCases

  init(mainCategory: MainCategory) {
    self.mainCategory = mainCategory
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = mainCategory.title
  }

  // MARK: - DataSource

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    scenarios.count
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    "测试用例集 (\(mainCategory == .uikitEngine ? "UIKit 渲染引擎" : "SwiftUI 适配器"))"
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    "两套 UI 框架共享相同的底层渲染规范与语义。"
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let scenario = scenarios[indexPath.row]
    return dequeueSubtitleCell(title: scenario.title, subtitle: scenario.subtitle)
  }

  // MARK: - Delegate

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    super.tableView(tableView, didSelectRowAt: indexPath)
    guard let nav = navigationController else { return }

    let scenario = scenarios[indexPath.row]
    let vc = viewController(for: scenario)
    nav.pushViewController(vc, animated: true)
  }

  private func viewController(for scenario: DemoScenario) -> UIViewController {
    switch mainCategory {
    case .uikitEngine:
      switch scenario {
      case .standardStatic:
        return UIKitStandardMarkdownDemoViewController()
      case .customComponents:
        return UIKitComponentsDemoViewController()
      case .configuration:
        return UIKitConfigurationDemoViewController()
      case .streamingDocument:
        return UIKitStreamingMarkdownViewController()
      case .aiChat:
        return SSEChatViewController()
      case .longTextPerformance:
        return MarkdownDetailViewController(title: scenario.title, resourceName: "comprehensive-readme")
      }

    case .swiftUIAdapter:
      switch scenario {
      case .standardStatic:
        return hostingController(SwiftUIStaticMarkdownDemoView(), title: scenario.title)
      case .customComponents:
        return hostingController(SwiftUIComponentsDemoView(), title: scenario.title)
      case .configuration:
        return hostingController(SwiftUIConfigurationDemoView(), title: scenario.title)
      case .streamingDocument:
        return hostingController(SwiftUIStreamingMarkdownDemoView(), title: scenario.title)
      case .aiChat:
        return hostingController(SwiftUIChatDemoView(), title: scenario.title)
      case .longTextPerformance:
        return hostingController(SwiftUILongTextDemoView(), title: scenario.title)
      }
    }
  }

  private func hostingController<Content: View>(_ rootView: Content, title: String) -> UIViewController {
    let controller = UIHostingController(rootView: rootView)
    controller.title = title
    return controller
  }
}
