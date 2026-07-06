import UIKit

/// 兜底块：把非自定义 UIView 的部分塞回 NSAttributedString，用 UITextView 渲染。
public struct InkAttributedTextBlock: InkRenderableBlock {
  public let attributedText: NSAttributedString
  /// 文本容器内边距。
  public let insets: UIEdgeInsets

  public init(
    attributedText: NSAttributedString,
    insets: UIEdgeInsets = InkAppearance.shared.text.blockInsets
  ) {
    self.attributedText = attributedText
    self.insets = insets
  }

  public func makeView() -> UIView {
    let textContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    textContainer.lineFragmentPadding = 0
    let layoutManager = InkMarkdownLayoutManager()
    layoutManager.usesFontLeading = false
    layoutManager.addTextContainer(textContainer)
    let textStorage = NSTextStorage(attributedString: attributedText)
    textStorage.addLayoutManager(layoutManager)
    let textView = UITextView(frame: .zero, textContainer: textContainer)
    textView.isEditable = false
    textView.isSelectable = true
    textView.dataDetectorTypes = UIDataDetectorTypes.link
    textView.backgroundColor = UIColor.clear
    textView.isScrollEnabled = false
    textView.textContainerInset = insets
    return textView
  }
}
