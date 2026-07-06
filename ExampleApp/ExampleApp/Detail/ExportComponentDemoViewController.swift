import UIKit
import InkMarkdown

/// 导出组件 Demo：展示 InkComponentBlock(.export) 的渲染效果。
final class ExportComponentDemoViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    title = "导出组件"
    setupDemo()
  }

  private func setupDemo() {
    let item = InkExportComponentItem(
      label: "导出联系方式",
      exportType: "QXB_AI_REACH_EXPORT",
      exportId: "019f0703-6d85-70aa-8e89-6066cfe4e5e8"
    )

    let block = InkComponentBlock(kind: .export(item)) { event in
      if case .export(let tapped) = event {
        let alert = UIAlertController(
          title: "点击跳转",
          message: "exportType: \(tapped.exportType)\nexportId: \(tapped.exportId)",
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        self.present(alert, animated: true)
      }
    }

    let componentView = block.makeView()
    componentView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(componentView)

    NSLayoutConstraint.activate([
      componentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      componentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      componentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
  }
}
