import UIKit
import InkMarkdown

/// 展示单篇 Markdown 样例：分段切换「渲染效果」与「Markdown 源码」。
final class MarkdownDetailViewController: UIViewController {

    private enum DisplayMode: Int {
        case rendered = 0
        case source = 1
    }

    private let resourceName: String
    private var markdownSource: String = ""
    private var displayMode: DisplayMode = .rendered

    private let segmentedControl = UISegmentedControl(items: ["渲染效果", "Markdown 源码"])
    private let blockStackView = DemoBlockStackView()
    private let sourceTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return textView
    }()

    /// - Parameters:
    ///   - title: 导航栏标题。
    ///   - resourceName: Bundle 内 `.md` 文件名（不含扩展名）。
    init(title: String, resourceName: String) {
        self.resourceName = resourceName
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        loadMarkdownSource()
        setupUI()
        renderMarkdownContent()
        applyDisplayMode()
    }

    // MARK: - UI

    private func setupUI() {
        segmentedControl.selectedSegmentIndex = DisplayMode.rendered.rawValue
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        blockStackView.translatesAutoresizingMaskIntoConstraints = false
        sourceTextView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(segmentedControl)
        view.addSubview(blockStackView)
        view.addSubview(sourceTextView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            blockStackView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            blockStackView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            blockStackView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            blockStackView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),

            sourceTextView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            sourceTextView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            sourceTextView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            sourceTextView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
        ])
    }

    @objc private func segmentChanged() {
        guard let mode = DisplayMode(rawValue: segmentedControl.selectedSegmentIndex) else { return }
        displayMode = mode
        applyDisplayMode()
    }

    private func applyDisplayMode() {
        switch displayMode {
        case .rendered:
            blockStackView.isHidden = false
            sourceTextView.isHidden = true
        case .source:
            blockStackView.isHidden = true
            sourceTextView.isHidden = false
            sourceTextView.attributedText = sourceAttributedString(markdownSource)
        }
    }

    // MARK: - Resource Loading

    private func loadMarkdownSource() {
        guard let text = Self.loadMarkdown(named: resourceName) else {
            markdownSource = "# 加载失败\n\n找不到资源文件 `\(resourceName).md`，请在 Xcode 中将 Resources/Samples 加入 target。"
            return
        }
        markdownSource = text
    }

    /// 兼容「folder reference」与「group」两种 Xcode 添加方式。
    static func loadMarkdown(named name: String) -> String? {
        let lookups: [(subdirectory: String?, resource: String)] = [
            ("Samples", name),
            (nil, name),
        ]
        for item in lookups {
            let url: URL?
            if let sub = item.subdirectory {
                url = Bundle.main.url(forResource: item.resource, withExtension: "md", subdirectory: sub)
            } else {
                url = Bundle.main.url(forResource: item.resource, withExtension: "md")
            }
            guard let url, let data = try? Data(contentsOf: url) else { continue }
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    // MARK: - Rendering

    private func renderMarkdownContent() {
        let config = DemoInkConfigurationBuilder.makeStaticConfiguration(
            userInterfaceStyle: traitCollection.userInterfaceStyle
        )
        blockStackView.render(markdown: markdownSource, configuration: config)
    }

    private func sourceAttributedString(_ source: String) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        return NSAttributedString(string: source, attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
        ])
    }
}
