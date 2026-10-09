import UIKit
@_spi(InkMarkdown) import InkMarkdown

/// 可逐字吐字的片段视图协议。
///
/// SSE 吐字 cell 把 AI 回答拆成若干「片段」（普通文本段 / 代码块卡片），
/// 每个片段都实现本协议，cell 按统一进度逐字推进，轮到哪个片段就吐哪个。
protocol SSETypewriterSegment: UIView {
  /// 本片段参与吐字的总字符数。
  var typewriterLength: Int { get }
  /// 设置当前可见字符数（0...typewriterLength）。
  func setVisibleLength(_ length: Int)
}

// MARK: - 自定义代码块：Block 路由单元

/// 代码块自定义块：命中 ``` ``` ``` 围栏代码块时，由 `InkBlockRenderer` 路由到此，
/// 渲染成带 header 的卡片 UIView，而非塞进 NSAttributedString。
struct CodeBlockCardBlock: InkRenderableBlock, InkReusableBlock {
  /// 代码正文（swift-markdown 的 `CodeBlock.code`，含末尾换行）。
  let code: String
  /// 围栏语言标识（```swift 中的 swift），可为空。
  let language: String?

  func makeView() -> UIView {
    CodeBlockCardView(code: code, language: language)
  }

  func updateExistingView(_ view: UIView) -> Bool {
    false
  }

  func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    guard let previous = previous as? CodeBlockCardBlock else { return false }
    return code == previous.code && language == previous.language
  }
}

// MARK: - 自定义代码块视图

/// 代码块卡片：顶部 header（「代码块」文案 + 语言标签 + 圆点装饰），下方等宽正文。
///
/// 正文支持逐字显示，配合 SSE 吐字——代码会一行行「敲」出来。
final class CodeBlockCardView: UIView, SSETypewriterSegment {

  private let headerView = UIView()
  private let titleLabel = UILabel()
  private let languageLabel = UILabel()
  private let bodyLabel = UILabel()

  /// 完整代码（去掉尾部多余换行，避免卡片底部留白）。
  private let fullCode: String
  private let codeScalars: [Character]

  init(code: String, language: String?) {
    let trimmed = code.hasSuffix("\n") ? String(code.dropLast()) : code
    self.fullCode = trimmed
    self.codeScalars = Array(trimmed)
    super.init(frame: .zero)
    setup(language: language)
    // 默认全部可见（非吐字场景：历史消息、滚动回来）
    bodyLabel.text = fullCode
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func setup(language: String?) {
    let card = UIView()
    card.backgroundColor = UIColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1)
    card.layer.cornerRadius = 10
    card.layer.cornerCurve = .continuous
    card.layer.masksToBounds = true
    card.translatesAutoresizingMaskIntoConstraints = false
    addSubview(card)
    // 左右不再自缩进——卡片在 cell 的 stack 里已和文本段对齐
    NSLayoutConstraint.activate([
      card.topAnchor.constraint(equalTo: topAnchor),
      card.bottomAnchor.constraint(equalTo: bottomAnchor),
      card.leadingAnchor.constraint(equalTo: leadingAnchor),
      card.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])

    // Header：左侧三个「红黄绿」圆点装饰 + 「代码块」文案，右侧语言标签
    headerView.backgroundColor = UIColor(red: 0.16, green: 0.17, blue: 0.21, alpha: 1)
    headerView.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(headerView)
    NSLayoutConstraint.activate([
      headerView.topAnchor.constraint(equalTo: card.topAnchor),
      headerView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
      headerView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
      headerView.heightAnchor.constraint(equalToConstant: 34),
    ])

    let dots = UIStackView()
    dots.axis = .horizontal
    dots.spacing = 6
    for color in [UIColor.systemRed, .systemYellow, .systemGreen] {
      let dot = UIView()
      dot.backgroundColor = color
      dot.layer.cornerRadius = 5
      dot.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        dot.widthAnchor.constraint(equalToConstant: 10),
        dot.heightAnchor.constraint(equalToConstant: 10),
      ])
      dots.addArrangedSubview(dot)
    }
    dots.translatesAutoresizingMaskIntoConstraints = false
    headerView.addSubview(dots)
    NSLayoutConstraint.activate([
      dots.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
      dots.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
    ])

    titleLabel.text = "代码块"
    titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
    titleLabel.textColor = UIColor(white: 0.85, alpha: 1)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    headerView.addSubview(titleLabel)
    NSLayoutConstraint.activate([
      titleLabel.leadingAnchor.constraint(equalTo: dots.trailingAnchor, constant: 10),
      titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
    ])

    languageLabel.text = (language?.isEmpty == false) ? language : "text"
    languageLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    languageLabel.textColor = UIColor(white: 0.55, alpha: 1)
    languageLabel.translatesAutoresizingMaskIntoConstraints = false
    headerView.addSubview(languageLabel)
    NSLayoutConstraint.activate([
      languageLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
      languageLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
    ])

    bodyLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    bodyLabel.textColor = UIColor(white: 0.92, alpha: 1)
    bodyLabel.numberOfLines = 0
    bodyLabel.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(bodyLabel)
    NSLayoutConstraint.activate([
      bodyLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
      bodyLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
      bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
      bodyLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
    ])
  }

  // MARK: - SSETypewriterSegment

  var typewriterLength: Int { codeScalars.count }

  func setVisibleLength(_ length: Int) {
    let clamped = max(0, min(length, codeScalars.count))
    bodyLabel.text = String(codeScalars[0..<clamped])
  }

  func apply(code: String, language: String?) {
    let trimmed = code.hasSuffix("\n") ? String(code.dropLast()) : code
    bodyLabel.text = trimmed
    languageLabel.text = (language?.isEmpty == false) ? language : "text"
    setNeedsLayout()
  }
}
