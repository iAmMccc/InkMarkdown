import UIKit
import InkMarkdown

/// 文本片段视图：把一段 NSAttributedString 包成可逐字吐字的片段。
///
/// 与 `CodeBlockCardView` 一起，构成 SSE 吐字 cell 的两类片段。普通文本走这里
/// （UITextView 渲染），围栏代码块走代码卡片，cell 按统一进度顺序推进。
///
/// 行内生成图（LaTeX 等）以 ``InkImageAttachment`` 嵌入 attributed string；
/// 渲染期不触发 Store，必须在装入 textStorage 后调用 ``InkImageAttachment.bindAttachments``。
final class SSETextSegmentView: UIView, SSETypewriterSegment {

    private let textView = UITextView()
    private var fullRendered: NSAttributedString
    private var currentVisibleLength: Int = 0

    /// 行内图加载导致高度变化时回调（供 tableView 刷新行高）。
    var onHeightChange: (() -> Void)?

    init(attributedText: NSAttributedString) {
        self.fullRendered = attributedText
        self.currentVisibleLength = attributedText.length
        super.init(frame: .zero)
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.dataDetectorTypes = [.link]
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        // 默认全部可见（历史消息、滚动回来）
        applyVisibleText(attributedText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - SSETypewriterSegment

    var typewriterLength: Int { fullRendered.length }

    /// 流式 rebuild 时若新 attributed 是旧全文扩展，复用本 view 并更新全文，保留已 materialize 的 attachment。
    func canExtend(with newText: NSAttributedString) -> Bool {
        return true
    }

    func updateFullText(_ newText: NSAttributedString) {
        fullRendered = newText
        setVisibleLength(currentVisibleLength)
    }

    func setVisibleLength(_ length: Int) {
        currentVisibleLength = max(0, min(length, fullRendered.length))
        let visible = fullRendered.attributedSubstring(from: NSRange(location: 0, length: currentVisibleLength))
        applyVisibleText(visible)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // D1：SSE rebuild 常在 width=0 时 bind；宽度就绪后再 bind 一次（幂等），让行内图陆续出图。
        guard bounds.width > 0, textView.textStorage.length > 0 else { return }
        bindInlineAttachments()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, bounds.width > 0, textView.textStorage.length > 0 else { return }
        bindInlineAttachments()
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIView.layoutFittingExpandedSize.width
        let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    /// 写入 textStorage 并绑定行内 ``InkImageAttachment``，否则 LaTeX 等会永久停在占位图。
    private func applyVisibleText(_ text: NSAttributedString) {
        textView.attributedText = text
        bindInlineAttachments()
        invalidateIntrinsicContentSize()
    }

    private func bindInlineAttachments() {
        InkImageAttachment.bindAttachments(
            in: textView.textStorage,
            layoutManager: textView.layoutManager,
            onHeightChange: { [weak self] in
                guard let self else { return }
                self.invalidateIntrinsicContentSize()
                self.setNeedsLayout()
                self.onHeightChange?()
            }
        )
    }
}
