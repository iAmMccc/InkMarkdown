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
///
/// 所有非流式样式统一走块路由（`InkBlockRenderer`）：代码块 / 表格 / 分割线优先渲染为
/// 自定义 UIView，其余元素落进富文本兜底块 `InkAttributedTextBlock`。tableCard 因带交互
/// 开关（横滑 / 长按复制）走独立路径，其余样式共用通用块路由。
final class RenderedListViewController: UIViewController, PagerListController {

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
  private var genericContentStack: UIStackView?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    // tableCard 带交互开关，走独立路径；其余样式统一走通用块路由。
    if style == .tableCard {
      setupTableBlockRouting()
    } else {
      setupGenericBlockRouting()
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
    guard style == .latexEnabled || style == .mermaidEnabled else { return }
    rebuildGenericBlockContent()
  }

  /// 该样式对应的完整渲染配置。Block 路由的 blockHandlers（需要 `self` 侧信息）在此注入。
  private func makeConfiguration() -> InkConfiguration {
    var config: InkConfiguration
    switch style {
    case .latexEnabled:
      config = .demoGeneratedContent(
        mode: .latexOnly,
        userInterfaceStyle: traitCollection.userInterfaceStyle
      )
    case .mermaidEnabled:
      config = .demoGeneratedContent(
        mode: .mermaidOnly,
        userInterfaceStyle: traitCollection.userInterfaceStyle
      )
      config.appearance.enableDemoMermaidImageTap { [weak self] in self }
    default:
      config = style.configuration
    }

    // 真图 tab：块级图片点击弹出全屏预览（行内 attachment 不响应 tap）。
    if style == .imageEnabled {
      config.appearance.enableDemoBlockImageTap { [weak self] in self }
    }

    // h1ActionCard：H1 替换为业务卡片，其余走默认路由。
    if style == .h1ActionCard {
      config.blockHandlers = [H1ActionCardBlockHandler()] + InkConfiguration.defaultBlockHandlers
    }
    return config
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
    stack.spacing = 0  // 容器紧贴：块间距由各块自身的 bottom 间距承担，不由 stack 叠加
    stack.alignment = .fill
    stack.distribution = .fill
    // Markdown 距屏幕左右 15pt（demo 侧统一控制；库 blockInsets 已归零不占边距）。
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

    genericContentStack = stack
    rebuildGenericBlockContent()
  }

  private func rebuildGenericBlockContent() {
    guard let stack = genericContentStack else { return }
    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

    var config = makeConfiguration()
    let failureObserver: GeneratedContentFailureObserver?
    switch style {
    case .latexEnabled, .mermaidEnabled:
      let observer = GeneratedContentFailureObserver()
      observer.attach(to: &config.appearance)
      failureObserver = observer
    default:
      failureObserver = nil
    }

    let blocks = InkBlockRenderer.render(source, configuration: config)
    for block in blocks {
      if let observer = failureObserver {
        stack.addArrangedSubview(observer.makeView(for: block))
      } else {
        stack.addArrangedSubview(block.makeView())
      }
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
    stack.spacing = 0  // 容器紧贴：块间距由各块自身的 bottom 间距承担，不由 stack 叠加
    stack.alignment = .fill
    stack.distribution = .fill
    // Markdown 距屏幕左右 15pt（demo 侧统一控制；库 blockInsets 已归零不占边距）。
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
    let accessory: H1ActionCardBlock.Accessory? = (title == "值类型与引用类型")
      ? .init(
          text: "查看示例",
          alertTitle: "值类型与引用类型",
          alertMessage: "这是 Block 路由演示——H1 被替换为可点击的自定义卡片。业务方可通过 InkBlockHandler 把任意块渲染成原生 UIView 并承载交互。"
        )
      : nil
    return H1ActionCardBlock(title: title, accessory: accessory)
  }
}
