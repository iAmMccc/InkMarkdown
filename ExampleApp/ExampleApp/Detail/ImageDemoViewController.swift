import UIKit
import InkMarkdown

/// 图片渲染专属 Demo：10 个场景展示网络图、本地 Asset、Base64、块通道、行内混排、
/// 全屏预览、多图、占位文本、自定义尺寸与安全拒绝。
final class ImageDemoViewController: UIViewController {

  private let scrollView = UIScrollView()
  private let stackView: UIStackView = {
    let sv = UIStackView()
    sv.axis = .vertical
    sv.spacing = 16
    sv.alignment = .fill
    return sv
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "图片渲染 Demo"
    view.backgroundColor = .systemBackground
    setupViews()
    renderDemos()
  }

  private func setupViews() {
    scrollView.alwaysBounceVertical = true
    view.addSubview(scrollView)
    scrollView.addSubview(stackView)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
      stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
      stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
      stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
    ])
  }

  private func renderDemos() {
    let demos: [(title: String, markdown: String, configure: (inout InkAppearance) -> Void)] = [
      // 场景 1: 网络图 + 标准渲染
      ("场景 1: 网络图片", "![风景](https://picsum.photos/400/300)", { appearance in
        appearance.imageRendering.isEnabled = true
        appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
      }),
      // 场景 2: 本地 asset 图
      ("场景 2: 本地 Asset 图片", "![App 图标](asset://AppIcon)", { appearance in
        appearance.imageRendering.isEnabled = true
      }),
      // 场景 3: base64 内联图
      ("场景 3: Base64 内联图（小图正常显示）", "![base64](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==)", { appearance in
        appearance.imageRendering.isEnabled = true
      }),
      // 场景 4: 独占段 promote → 块通道
      ("场景 4: 独占段图片（块通道）", "![大图](https://picsum.photos/800/600)", { appearance in
        appearance.imageRendering.isEnabled = true
        appearance.imageRendering.promotesToBlock = true
        appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
      }),
      // 场景 5: 行内图文混排
      ("场景 5: 行内图文混排", "这是一段文字 ![图标](https://picsum.photos/24/24) 中间嵌入了小图标，不破坏行高。", { appearance in
        appearance.imageRendering.isEnabled = true
        appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
      }),
      // 场景 6: 点击查看大图（全屏预览）
      ("场景 6: 点击查看大图", "![点击查看大图](https://picsum.photos/1200/800)\n\n> 点击图片可全屏预览", { appearance in
        appearance.imageRendering.isEnabled = true
        appearance.imageRendering.tapAction = .callback
        appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
      }),
      // 场景 7: 多图
      ("场景 7: 多图场景", "![图1](https://picsum.photos/300/200)\n\n![图2](https://picsum.photos/301/200)\n\n![图3](https://picsum.photos/302/200)", { appearance in
        appearance.imageRendering.isEnabled = true
        appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
      }),
      // 场景 8: 占位文本（图片关闭）
      ("场景 8: 图片渲染关闭（占位文本）", "![占位展示](https://picsum.photos/400/300)", { appearance in
        appearance.imageRendering.isEnabled = false
      }),
      // 场景 9: 宿主自定义尺寸
      ("场景 9: 自定义最大宽度 200pt", "![限宽图](https://picsum.photos/800/600)", { appearance in
        appearance.imageRendering.isEnabled = true
        appearance.imageRendering.sizing.maxBlockImageWidth = 200
        appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
      }),
      // 场景 10: 安全拒绝
      ("场景 10: 安全拒绝（allowedHosts 不含目标域）", "![被拒绝的图](https://evil.example.com/malware.png)", { appearance in
        appearance.imageRendering.isEnabled = true
        appearance.imageRendering.securityPolicy.allowedHosts = ["safe.example.com"]
      }),
    ]

    for demo in demos {
      let sectionLabel = UILabel()
      sectionLabel.text = demo.title
      sectionLabel.font = .boldSystemFont(ofSize: 16)
      sectionLabel.textColor = .label
      stackView.addArrangedSubview(sectionLabel)

      var appearance = InkAppearance()
      demo.configure(&appearance)

      // 场景 6：通过 callback 弹出全屏预览
      if demo.title.hasPrefix("场景 6:") {
        appearance.imageRendering.onImageTap = { [weak self] source, image in
          self?.presentFullscreenPreview(source: source, image: image)
        }
      }

      let config = InkConfiguration(appearance: appearance)
      let blocks = InkBlockRenderer.render(demo.markdown, configuration: config)
      for block in blocks {
        stackView.addArrangedSubview(block.makeView())
      }

      let separator = UIView()
      separator.backgroundColor = .separator
      separator.translatesAutoresizingMaskIntoConstraints = false
      separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
      stackView.addArrangedSubview(separator)
    }
  }

  private func presentFullscreenPreview(source: ImageSource, image: UIImage?) {
    guard let image else { return }
    let preview = InkImagePreviewController(source: source, displayImage: image)
    preview.modalPresentationStyle = .fullScreen
    present(preview, animated: true)
  }
}
