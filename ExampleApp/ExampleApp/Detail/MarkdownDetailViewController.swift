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
    private var renderedContent: NSAttributedString?
    private var displayMode: DisplayMode = .rendered

    private let segmentedControl = UISegmentedControl(items: ["渲染效果", "Markdown 源码"])
    private let textView: UITextView = {
        let layoutManager = InkMarkdownLayoutManager()
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer()
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        return UITextView(frame: .zero, textContainer: textContainer)
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
        renderedContent = renderMarkdown(markdownSource)
        setupUI()
        applyDisplayMode()
    }

    // MARK: - UI

    private func setupUI() {
        segmentedControl.selectedSegmentIndex = DisplayMode.rendered.rawValue
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.dataDetectorTypes = [.link]

        view.addSubview(segmentedControl)
        view.addSubview(textView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            segmentedControl.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
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
            if let rendered = renderedContent {
                textView.attributedText = rendered
            } else {
                textView.attributedText = NSAttributedString(
                    string: "渲染失败，请检查 Markdown 源码。",
                    attributes: [.foregroundColor: UIColor.secondaryLabel]
                )
            }
        case .source:
            textView.attributedText = sourceAttributedString(markdownSource)
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

    private func renderMarkdown(_ source: String) -> NSAttributedString? {
        // TODO: 替换为 InkMarkdown 自身渲染器（计划见 docs/plans/example-app-demo-plan.md §6）
        // 早期方案使用 NSAttributedString.init(html:) 解析 HTMLFormatter 输出，
        // 但该 API 内部跑 WebKit 同步渲染，主线程一阻就是数百毫秒，详情页推入卡顿明显。
        // 改为基于 swift-markdown 的 MarkupVisitor 直接构造 NSAttributedString。
        return InkAttributedRenderer.render(source)
    }

    private func sourceAttributedString(_ source: String) -> NSAttributedString {
        let font = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        return NSAttributedString(string: source, attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
        ])
    }
}
