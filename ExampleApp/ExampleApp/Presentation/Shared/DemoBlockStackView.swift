import UIKit
import InkMarkdown

/// ExampleApp 共享的 UIKit 块级 Markdown 堆叠容器。
///
/// 在 `UIScrollView` 内按 Demo 统一间距（左右 16、块间距 12）纵向排列 `InkRenderableBlock` 视图。
final class DemoBlockStackView: UIView {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var blockViews: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    /// 用已渲染的 block 列表重新铺排视图层级。
    func render(blocks: [InkRenderableBlock]) {
        for view in blockViews {
            view.removeFromSuperview()
        }
        blockViews.removeAll()

        var previousView: UIView?

        for block in blocks {
            let view = block.makeView()
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
            blockViews.append(view)

            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            ])

            if let previousView {
                view.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 12).isActive = true
            } else {
                view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16).isActive = true
            }
            previousView = view
        }

        if let last = previousView {
            last.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20).isActive = true
        }
    }

    /// 解析 Markdown 并铺排 block 视图。
    func render(markdown: String, configuration: InkConfiguration) {
        let blocks = InkBlockRenderer.render(markdown, configuration: configuration)
        render(blocks: blocks)
    }

    // MARK: - Private

    private func setupUI() {
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
}
