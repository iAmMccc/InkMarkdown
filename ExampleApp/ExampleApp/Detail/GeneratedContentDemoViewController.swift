import UIKit
import InkMarkdown

/// 公式与图表综合 Demo：场景矩阵展示 opt-in 开启 / 关闭对照与失败错误条。
final class GeneratedContentDemoViewController: UIViewController {

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
    title = "公式与图表 Demo"
    view.backgroundColor = .systemBackground
    setupViews()
    renderDemos()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
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
    let style = traitCollection.userInterfaceStyle

    appendSection(
      title: "场景 1: 行内 LaTeX（\\(...\\)）",
      markdown: "勾股定理 \\(a^2 + b^2 = c^2\\) 与欧拉公式 \\(e^{i\\pi} + 1 = 0\\) 可混排在正文中。",
      mode: .latexOnly
    )

    appendSection(
      title: "场景 2: 块级 LaTeX（$$...$$）",
      markdown: """
      $$
      \\int_{-\\infty}^{\\infty} e^{-x^2} \\, dx = \\sqrt{\\pi}
      $$
      """,
      mode: .latexOnly
    )

    appendSection(
      title: "场景 3: 块级 LaTeX（\\[...\\]）",
      markdown: """
      \\[
      \\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}
      \\]
      """,
      mode: .latexOnly
    )

    appendSection(
      title: "场景 4: Mermaid 流程图",
      markdown: """
      ```mermaid
      flowchart LR
          A[输入 Markdown] --> B{mermaid 围栏?}
          B -->|是| C[WebKit 本地渲染]
          B -->|否| D[普通代码块]
          C --> E[位图插入文档]
      ```
      """,
      mode: .mermaidOnly
    )

    appendSection(
      title: "场景 5: Mermaid 序列图",
      markdown: """
      ```mermaid
      sequenceDiagram
          participant U as 用户
          participant A as ExampleApp
          participant I as InkMarkdown
          U->>A: 打开公式与图表 Demo
          A->>I: 开启 mermaidRendering
          I-->>A: 返回 SVG 快照位图
          A-->>U: 展示渲染结果
      ```
      """,
      mode: .mermaidOnly
    )

    appendSection(
      title: "场景 6: 公式 + 图表混排",
      markdown: """
      ## 算法复杂度

      快排期望时间 \\(O(n \\log n)\\)，最坏 \\(O(n^2)\\)。

      ```mermaid
      flowchart TD
          Start[开始] --> Partition[分区]
          Partition --> Recurse[递归左右]
          Recurse --> Done[完成]
      ```

      归并排序稳定，时间恒为 \\(O(n \\log n)\\)。
      """,
      mode: .diagrams
    )

    appendSection(
      title: "场景 7: 关闭态对照（源码降级）",
      markdown: """
      ```mermaid
      graph TD; A-->B
      ```

      行内公式源码：\\(E = mc^2\\)

      未开启 latex/mermaid 时，围栏保持普通代码块，行内公式保持源码文本。
      """,
      mode: .disabled
    )

    // 场景 8：失败 — 显式错误条（SSOT）+ 触发真实生成失败
    let invalidMermaid = """
    ```mermaid
    this is not valid mermaid syntax [[[
    ```
    """
    appendFailureSection(
      title: "场景 8: 失败场景 + 显式错误条",
      markdown: invalidMermaid,
      userInterfaceStyle: style
    )

    // 可选：`$` 风险演示（单独标明，默认样式仍关闭 `$`）
    appendSection(
      title: "场景 9: `$...$` 风险对照（本场景临时开启）",
      markdown: """
      开启 `allowsInlineDollarDelimiter` 后，能量公式 $E = mc^2$ 会渲染；
      同时价格写法 $5 也有被误识别的风险——因此全局 Demo / SSE 默认关闭 `$`。
      """,
      mode: .diagrams,
      allowsInlineDollarDelimiter: true
    )
  }

  private func appendSection(
    title: String,
    markdown: String,
    mode: DemoGeneratedContentMode,
    allowsInlineDollarDelimiter: Bool = false
  ) {
    let sectionLabel = UILabel()
    sectionLabel.text = title
    sectionLabel.font = .boldSystemFont(ofSize: 16)
    sectionLabel.textColor = .label
    sectionLabel.numberOfLines = 0
    stackView.addArrangedSubview(sectionLabel)

    var config = InkConfiguration.demoGeneratedContent(
      mode: mode,
      userInterfaceStyle: traitCollection.userInterfaceStyle,
      allowsInlineDollarDelimiter: allowsInlineDollarDelimiter
    )
    let observer = GeneratedContentFailureObserver()
    if mode != .disabled {
      observer.attach(to: &config.appearance)
    }

    let blocks = InkBlockRenderer.render(markdown, configuration: config)
    for block in blocks {
      stackView.addArrangedSubview(observer.makeView(for: block))
    }

    appendSeparator()
  }

  private func appendFailureSection(
    title: String,
    markdown: String,
    userInterfaceStyle: UIUserInterfaceStyle
  ) {
    let sectionLabel = UILabel()
    sectionLabel.text = title
    sectionLabel.font = .boldSystemFont(ofSize: 16)
    sectionLabel.textColor = .label
    sectionLabel.numberOfLines = 0
    stackView.addArrangedSubview(sectionLabel)

    let noteLabel = UILabel()
    noteLabel.text = "非法 Mermaid 语法无法生图；失败时由统一错误条展示，下方为库侧 sourceCode fallback。"
    noteLabel.font = .systemFont(ofSize: 13)
    noteLabel.textColor = .secondaryLabel
    noteLabel.numberOfLines = 0
    stackView.addArrangedSubview(noteLabel)

    var config = InkConfiguration.demoGeneratedContent(
      mode: .mermaidOnly,
      userInterfaceStyle: userInterfaceStyle
    )
    let observer = GeneratedContentFailureObserver()
    observer.attach(to: &config.appearance)
    let blocks = InkBlockRenderer.render(markdown, configuration: config)
    for block in blocks {
      stackView.addArrangedSubview(observer.makeView(for: block))
    }

    appendSeparator()
  }

  private func appendSeparator() {
    let separator = UIView()
    separator.backgroundColor = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
    stackView.addArrangedSubview(separator)
  }
}
