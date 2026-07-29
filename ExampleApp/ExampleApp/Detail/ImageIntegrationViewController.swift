import UIKit
import InkMarkdown

/// 集成测试：图片渲染场景。块级图片可点击全屏预览，行内混排仅展示。
final class ImageIntegrationViewController: UIViewController {

  private let resourceName: String

  /// - Parameter resourceName: Bundle 内 `.md` 文件名（不含扩展名）。
  init(resourceName: String = "image-rendering-integration") {
    self.resourceName = resourceName
    super.init(nibName: nil, bundle: nil)
    title = "图片渲染"
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    setupContent()
  }

  private func setupContent() {
    let markdown = Self.loadMarkdown(named: resourceName) ?? Self.fallbackMarkdown

    let scrollView = UIScrollView()
    scrollView.alwaysBounceVertical = true
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 0
    stack.alignment = .fill
    stack.distribution = .fill
    stack.layoutMargins = UIEdgeInsets(top: 12, left: 15, bottom: 12, right: 15)
    stack.isLayoutMarginsRelativeArrangement = true
    stack.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
    ])

    var appearance = InkAppearance()
    appearance.imageRendering.isEnabled = true
    appearance.imageRendering.promotesToBlock = true
    appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
    appearance.enableDemoBlockImageTap { [weak self] in self }

    let config = InkConfiguration(appearance: appearance)
    let blocks = InkBlockRenderer.render(markdown, configuration: config)
    for block in blocks {
      stack.addArrangedSubview(block.makeView())
    }
  }

  /// 兼容「folder reference」与「group」两种 Xcode 添加方式。
  private static func loadMarkdown(named name: String) -> String? {
    MarkdownDetailViewController.loadMarkdown(named: name)
  }

  /// 资源缺失时的内联兜底样例（与 `image-rendering-integration.md` 语义一致）。
  private static let fallbackMarkdown = """
  # 图片渲染集成测试

  ## 块级大图（可点击放大）

  ![块级大图](https://picsum.photos/seed/ink-block/1200/800)

  ## 竖图与中图（可点击放大）

  ![竖图](https://picsum.photos/seed/ink-portrait/600/900)

  ![中等尺寸](https://picsum.photos/seed/ink-medium/400/300)

  ## 行内图文混排

  正文 ![行内图标](https://picsum.photos/seed/ink-icon/24/24) 混排演示。

  ## 加载失败（可选）

  ![失败示例](https://picsum.photos/id/999999/200/200)
  """
}
