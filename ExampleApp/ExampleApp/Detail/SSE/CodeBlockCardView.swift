import UIKit
import SnapKit
import InkMarkdown

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
struct CodeBlockCardBlock: InkRenderableBlock {
    /// 代码正文（swift-markdown 的 `CodeBlock.code`，含末尾换行）。
    let code: String
    /// 围栏语言标识（```swift 中的 swift），可为空。
    let language: String?

    func makeView() -> UIView {
        CodeBlockCardView(code: code, language: language)
    }
}

// MARK: - 自定义代码块视图

/// 代码块卡片：顶部 header（「代码块」文案 + 语言标签 + 圆点装饰），下方等宽正文。
///
/// 正文支持逐字显示，配合 SSE 吐字——代码会一行行「敲」出来。
private final class CodeBlockCardView: UIView, SSETypewriterSegment {

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
        addSubview(card)
        card.snp.makeConstraints { make in
            // 左右不再自缩进——卡片在 cell 的 stack 里已和文本段对齐
            make.edges.equalToSuperview()
        }

        // Header：左侧三个「红黄绿」圆点装饰 + 「代码块」文案，右侧语言标签
        headerView.backgroundColor = UIColor(red: 0.16, green: 0.17, blue: 0.21, alpha: 1)
        card.addSubview(headerView)
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(34)
        }

        let dots = UIStackView()
        dots.axis = .horizontal
        dots.spacing = 6
        for color in [UIColor.systemRed, .systemYellow, .systemGreen] {
            let dot = UIView()
            dot.backgroundColor = color
            dot.layer.cornerRadius = 5
            dot.snp.makeConstraints { $0.width.height.equalTo(10) }
            dots.addArrangedSubview(dot)
        }
        headerView.addSubview(dots)
        dots.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
        }

        titleLabel.text = "代码块"
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = UIColor(white: 0.85, alpha: 1)
        headerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(dots.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
        }

        languageLabel.text = (language?.isEmpty == false) ? language : "text"
        languageLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        languageLabel.textColor = UIColor(white: 0.55, alpha: 1)
        headerView.addSubview(languageLabel)
        languageLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }

        bodyLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        bodyLabel.textColor = UIColor(white: 0.92, alpha: 1)
        bodyLabel.numberOfLines = 0
        card.addSubview(bodyLabel)
        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(14)
            make.bottom.equalToSuperview().offset(-12)
        }
    }

    // MARK: - SSETypewriterSegment

    var typewriterLength: Int { codeScalars.count }

    func setVisibleLength(_ length: Int) {
        let clamped = max(0, min(length, codeScalars.count))
        bodyLabel.text = String(codeScalars[0..<clamped])
    }
}
