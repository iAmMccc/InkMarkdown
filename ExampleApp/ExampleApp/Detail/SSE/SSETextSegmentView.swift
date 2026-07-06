import UIKit
import SnapKit

/// 文本片段视图：把一段 NSAttributedString 包成可逐字吐字的片段。
///
/// 与 `CodeBlockCardView` 一起，构成 SSE 吐字 cell 的两类片段。普通文本走这里
/// （UITextView 渲染），围栏代码块走代码卡片，cell 按统一进度顺序推进。
final class SSETextSegmentView: UIView, SSETypewriterSegment {

    private let textView = UITextView()
    private let fullRendered: NSAttributedString

    init(attributedText: NSAttributedString) {
        self.fullRendered = attributedText
        super.init(frame: .zero)
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.dataDetectorTypes = [.link]
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        addSubview(textView)
        textView.snp.makeConstraints { $0.edges.equalToSuperview() }
        // 默认全部可见（历史消息、滚动回来）
        textView.attributedText = attributedText
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - SSETypewriterSegment

    var typewriterLength: Int { fullRendered.length }

    func setVisibleLength(_ length: Int) {
        let clamped = max(0, min(length, fullRendered.length))
        textView.attributedText = fullRendered.attributedSubstring(from: NSRange(location: 0, length: clamped))
    }
}
