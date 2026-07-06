import UIKit
import InkMarkdown
import Markdown

// MARK: - Table Block Handler

private struct DemoTableBlockHandler: InkBlockHandler {
  let layoutMode: InkTableLayoutMode
  let enableCopy: Bool

  func canHandle(_ markup: Markup) -> Bool {
    markup is Markdown.Table
  }

  func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let table = markup as? Markdown.Table else { return nil }
    var config = configuration
    config.appearance.table.enableLongPressCopy = enableCopy
    return InkTableBlock.from(table, layoutMode: layoutMode, configuration: config)
  }
}

/// 渲染 tab：标准样式或某一种自定义样式，共用同一套 VC。
final class RenderedListViewController: UIViewController, PagerListController, UITextViewDelegate, TagInlineInteractionHandler {

  let tabTitle: String

  private let source: String
  private let style: DemoStyle

  init(source: String, style: DemoStyle) {
    self.source = source
    self.style = style
    self.tabTitle = style.displayName
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private var scrollableToggle: UISwitch?
  private var copyToggle: UISwitch?
  private var blockContentView: UIView?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    if style.usesBlockRouting {
      setupBlockRouting()
    } else {
      setupAttributedText()
    }
  }

  private func setupAttributedText() {
    let layoutManager = InkMarkdownLayoutManager()
    let textStorage = NSTextStorage()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer()
    textContainer.lineFragmentPadding = 0
    textContainer.widthTracksTextView = true
    layoutManager.addTextContainer(textContainer)

    let textView = UITextView(frame: .zero, textContainer: textContainer)
    textView.isEditable = false
    textView.isSelectable = true
    textView.dataDetectorTypes = [.link]
    textView.delegate = self
    textView.backgroundColor = .systemBackground
    textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

    let rendered = InkAttributedRenderer.render(source, configuration: style.configuration)
    textStorage.setAttributedString(rendered)

    textView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(textView)
    NSLayoutConstraint.activate([
      textView.topAnchor.constraint(equalTo: view.topAnchor),
      textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
  }

  func textView(
    _ textView: UITextView,
    shouldInteractWith URL: URL,
    in characterRange: NSRange,
    interaction: UITextItemInteraction
  ) -> Bool {
    if let tagText = URL.tagInlineText() {
      tagInline(tagText, didTapInTextView: textView)
      return false
    }
    return true
  }

  func tagInline(_ text: String, didTapInTextView textView: UITextView) {
    let alert = UIAlertController(
      title: text,
      message: "这是 InkMarkdown 演示用的 $...$ 行内标签——主库未来通过扩展语法 $标签$(target) 声明跳转目标。",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "好的", style: .default))
    present(alert, animated: true)
  }

  private func setupBlockRouting() {
    if style == .tableCard {
      setupTableBlockRouting()
    } else {
      setupGenericBlockRouting()
    }
  }

  private func setupGenericBlockRouting() {
    let scrollView = UIScrollView()
    scrollView.alwaysBounceVertical = true
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 8
    stack.alignment = .fill
    stack.distribution = .fill
    stack.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
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

    let config = InkConfiguration(blockHandlers: [H1ActionCardBlockHandler()] + InkConfiguration.defaultBlockHandlers)
    let blocks = InkBlockRenderer.render(source, configuration: config)
    for block in blocks {
      stack.addArrangedSubview(block.makeView())
    }
  }

  private func setupTableBlockRouting() {
    // 顶部开关栏
    let toggleBar = UIStackView()
    toggleBar.axis = .vertical
    toggleBar.spacing = 0
    toggleBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(toggleBar)
    NSLayoutConstraint.activate([
      toggleBar.topAnchor.constraint(equalTo: view.topAnchor),
      toggleBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      toggleBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    // 横向滑动开关
    let scrollRow = makeToggleRow(title: "横向滑动") { [weak self] toggle in
      self?.scrollableToggle = toggle
      toggle.addTarget(self, action: #selector(self?.toggleChanged), for: .valueChanged)
    }
    toggleBar.addArrangedSubview(scrollRow)

    // 长按复制开关
    let copyRow = makeToggleRow(title: "长按复制") { [weak self] toggle in
      self?.copyToggle = toggle
      toggle.addTarget(self, action: #selector(self?.toggleChanged), for: .valueChanged)
    }
    toggleBar.addArrangedSubview(copyRow)

    let separator = UIView()
    separator.backgroundColor = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false
    toggleBar.addArrangedSubview(separator)
    separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

    // 表格内容区域
    let contentView = UIView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(contentView)
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: toggleBar.bottomAnchor),
      contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    blockContentView = contentView

    rebuildTableContent()
  }

  private func makeToggleRow(title: String, configure: (UISwitch) -> Void) -> UIView {
    let row = UIView()
    row.translatesAutoresizingMaskIntoConstraints = false
    row.heightAnchor.constraint(equalToConstant: 44).isActive = true

    let label = UILabel()
    label.text = title
    label.font = .systemFont(ofSize: 14)
    label.textColor = .secondaryLabel
    label.translatesAutoresizingMaskIntoConstraints = false
    row.addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
      label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
    ])

    let toggle = UISwitch()
    toggle.isOn = false
    toggle.translatesAutoresizingMaskIntoConstraints = false
    row.addSubview(toggle)
    NSLayoutConstraint.activate([
      toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
      toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
    ])
    configure(toggle)

    return row
  }

  @objc private func toggleChanged() {
    rebuildTableContent()
  }

  private func rebuildTableContent() {
    guard let contentView = blockContentView else { return }
    let scrollable = scrollableToggle?.isOn ?? false
    let enableCopy = copyToggle?.isOn ?? false

    contentView.subviews.forEach { $0.removeFromSuperview() }

    let scrollView = UIScrollView()
    scrollView.alwaysBounceVertical = true
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    ])

    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 8
    stack.alignment = .fill
    stack.distribution = .fill
    stack.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
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

    let layoutMode: InkTableLayoutMode = scrollable ? .scroll : .wrap
    let tableConfig = InkConfiguration(
        blockHandlers: [DemoTableBlockHandler(layoutMode: layoutMode, enableCopy: enableCopy)]
    )
    let blocks = InkBlockRenderer.render(source, configuration: tableConfig)
    for block in blocks {
      stack.addArrangedSubview(block.makeView())
    }
  }
}

// MARK: - H1 Action Card Block Handler

private struct H1ActionCardBlockHandler: InkBlockHandler {
  func canHandle(_ markup: Markup) -> Bool {
    (markup as? Markdown.Heading)?.level == 1
  }

  func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let heading = markup as? Markdown.Heading, heading.level == 1 else { return nil }
    let title = heading.plainText
    let accessory: H1ActionCardBlock.Accessory? = (title == "集团结构")
      ? .init(
          text: "查看集团成员",
          alertTitle: "查看集团成员",
          alertMessage: "这是 Block 路由演示——业务卡片可承载真实跳转逻辑，主库 Theme/BlockStyle 体系落地后将通过 Markdown 扩展语法声明 target。"
        )
      : nil
    return H1ActionCardBlock(title: title, accessory: accessory)
  }
}
