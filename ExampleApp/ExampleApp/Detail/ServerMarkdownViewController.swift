import UIKit
import InkMarkdown

/// 演示「服务端 JSON 中的 Markdown 字段 → UIKit 渲染」全流程。
///
/// 上半屏展示模拟服务端返回的 JSON（等宽字体），下半屏展示从该 JSON
/// 中取出 `content` 字段后经 `InkAttributedRenderer` 渲染的效果。
/// 让读者直观看到：Markdown 的来源（本地文件 / JSON 字段）不影响渲染路径。
final class ServerMarkdownViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "服务端 JSON"
        setupLayout()
        renderContent()
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(stackView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Content

    private func renderContent() {
        let intro = makeStepHeader(
            number: "1",
            title: "服务端响应",
            description: "假设这是 GET /api/articles/42 的 JSON 响应，content 字段是 Markdown 文本。"
        )
        stackView.addArrangedSubview(intro)
        stackView.addArrangedSubview(makeJSONCard(text: ServerMarkdownViewController.sampleJSON))

        let arrow = makeArrowHint(
            "↓ 解码后取出 article.content 这一字段，传给 InkAttributedRenderer"
        )
        stackView.addArrangedSubview(arrow)

        let renderHeader = makeStepHeader(
            number: "2",
            title: "UIKit 渲染结果",
            description: "对 content 字段调用 InkAttributedRenderer.render(_:)，输出 NSAttributedString。"
        )
        stackView.addArrangedSubview(renderHeader)

        // 实际解码 + 渲染——这段代码就是您未来真实接入服务端时的代码
        guard let data = ServerMarkdownViewController.sampleJSON.data(using: .utf8),
              let article = try? JSONDecoder().decode(Article.self, from: data) else {
            stackView.addArrangedSubview(makeErrorCard("JSON 解码失败"))
            return
        }
        let rendered = InkAttributedRenderer.render(article.content)
        stackView.addArrangedSubview(makeRenderedCard(article: article, body: rendered))
    }

    // MARK: - Subviews

    private func makeStepHeader(number: String, title: String, description: String) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4

        let titleLabel = UILabel()
        titleLabel.text = "Step \(number)：\(title)"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label

        let descLabel = UILabel()
        descLabel.text = description
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(descLabel)
        return container
    }

    private func makeJSONCard(text: String) -> UIView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 10
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .label
        textView.text = text
        return textView
    }

    private func makeArrowHint(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }

    private func makeRenderedCard(article: Article, body: NSAttributedString) -> UIView {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 8
        card.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        card.isLayoutMarginsRelativeArrangement = true
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 10

        // Meta 区：把 JSON 中的非 Markdown 字段也展示出来——证明它们是正常解码的
        let metaLabel = UILabel()
        metaLabel.font = .systemFont(ofSize: 12)
        metaLabel.textColor = .secondaryLabel
        metaLabel.numberOfLines = 0
        metaLabel.text = "id: \(article.id)  ·  作者：\(article.author)  ·  发布于 \(article.publishedAt)"

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.text = article.title

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        let bodyLayoutManager = InkMarkdownLayoutManager()
        let bodyStorage = NSTextStorage(attributedString: body)
        bodyStorage.addLayoutManager(bodyLayoutManager)
        let bodyContainer = NSTextContainer()
        bodyContainer.lineFragmentPadding = 0
        bodyContainer.widthTracksTextView = true
        bodyLayoutManager.addTextContainer(bodyContainer)
        let bodyView = UITextView(frame: .zero, textContainer: bodyContainer)
        bodyView.isEditable = false
        bodyView.isScrollEnabled = false
        bodyView.backgroundColor = .clear
        bodyView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        bodyView.dataDetectorTypes = [.link]

        card.addArrangedSubview(metaLabel)
        card.addArrangedSubview(titleLabel)
        card.addArrangedSubview(separator)
        card.addArrangedSubview(bodyView)
        return card
    }

    private func makeErrorCard(_ message: String) -> UIView {
        let label = UILabel()
        label.text = "⚠️ \(message)"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .systemRed
        return label
    }

    // MARK: - Sample Data

    /// 模拟博客 API 响应。`content` 字段存原始 Markdown 文本——
    /// 这是 GitHub API、ChatGPT API、绝大多数 CMS 后端的通用做法。
    private static let sampleJSON = #"""
    {
      "id": 42,
      "title": "InkMarkdown 入门",
      "author": "qixin",
      "publishedAt": "2026-05-29",
      "content": "## 这是从服务端来的 Markdown\n\n你看到的这段内容存放在 JSON 的 `content` 字段里，原样是一段 **Markdown 文本**。\n\n常见的服务端响应做法：\n\n- 后端把 Markdown 当**纯文本字符串**存储\n- 前端用 `JSONDecoder` 解码取出该字段\n- 调用 `InkAttributedRenderer.render(_:)` 得到 `NSAttributedString`\n- 直接喂给 `UITextView` / `UILabel` 显示\n\n参考链接：[CommonMark Spec](https://spec.commonmark.org/0.31.2/)\n\n```swift\nlet article = try JSONDecoder().decode(Article.self, from: data)\nlet attr = InkAttributedRenderer.render(article.content)\ntextView.attributedText = attr\n```\n\n> 小结：服务端 JSON 与本地 .md 文件唯一的区别只在「字符串怎么拿到」，渲染流程完全一致。"
    }
    """#
}

// MARK: - Decoding Model

/// 模拟服务端文章模型。和您未来真实业务里的 `Article` 类型一一对应。
private struct Article: Decodable {
    let id: Int
    let title: String
    let author: String
    let publishedAt: String
    let content: String
}
