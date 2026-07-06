import UIKit
import InkMarkdown

/// 数据来源组件 Demo：展示 InkComponentBlock(.source) 的渲染效果。
final class SourceComponentDemoViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    title = "数据来源"
    setupDemo()
  }

  private func setupDemo() {
    let tags: [InkSourceTagKind] = [
      .entDimensionJump(eid: "e8cdf5e0-97ad-4e1e-a8e4-29358f8a9866", dimensionKey: "business-info", dimensionName: "经营信息"),
      .source(title: "营业执照信息", url: "https://www.gsxt.gov.cn/", snippet: "小米科技有限责任公司"),
      .source(title: "查询详细页", url: "https://xxcx.yjj.beijing.gov.cn/", snippet: "医疗器械网络交易服务第三方平台备案凭证"),
      .source(title: "投资者关系", url: "https://ir.mi.com/zh-hant", snippet: "小米公司正式成立于2010年4月"),
    ]

    let item = InkSourceComponentItem(tags: tags)
    let block = InkComponentBlock(kind: .source(item)) { [weak self] event in
      guard let self = self else { return }
      if case .sourceTag(let tagKind) = event {
        let message: String
        switch tagKind {
        case .source(let title, let url, _):
          message = "外链跳转\ntitle: \(title)\nurl: \(url)"
        case .entDimensionJump(let eid, let dimensionKey, let dimensionName):
          message = "内部跳转\ndimensionName: \(dimensionName)\ndimensionKey: \(dimensionKey)\neid: \(eid)"
        }
        let alert = UIAlertController(title: "点击", message: message, preferredStyle: .alert)
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
