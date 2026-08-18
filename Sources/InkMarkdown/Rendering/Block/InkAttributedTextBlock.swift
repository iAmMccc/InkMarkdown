import UIKit

/// 兜底块：把非自定义 UIView 的部分塞回 NSAttributedString，用 UITextView 渲染。
public struct InkAttributedTextBlock: InkRenderableBlock {
  public let attributedText: NSAttributedString
  /// 文本容器内边距。
  public let insets: UIEdgeInsets
  /// 链接点击回调。命中 `.link` 属性时交还业务方处理；返回 `true` 拦截默认行为。
  /// 与表格单元格 `InkTableCellTextView` 共用同一套 `linkTapHandler` 语义，
  /// 使富文本兜底块里的链接（含业务自定义 scheme，如 `$标签$`）也能被拦截。
  public let linkTapHandler: ((URL, UIView) -> Bool)?

  public init(
    attributedText: NSAttributedString,
    insets: UIEdgeInsets = InkAppearance.shared.text.blockInsets,
    linkTapHandler: ((URL, UIView) -> Bool)? = nil
  ) {
    self.attributedText = attributedText
    self.insets = insets
    self.linkTapHandler = linkTapHandler
  }

  public func makeView() -> UIView {
    let textContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    textContainer.lineFragmentPadding = 0
    let layoutManager = InkMarkdownLayoutManager()
    layoutManager.usesFontLeading = false
    layoutManager.addTextContainer(textContainer)
    let textStorage = NSTextStorage(attributedString: attributedText)
    textStorage.addLayoutManager(layoutManager)

    let textView = InkAttributedBlockTextView(frame: .zero, textContainer: textContainer)
    textView.linkTapHandler = linkTapHandler
    textView.isEditable = false
    textView.isSelectable = true
    // Markdown 文本在解析阶段已由引擎打上 .link 属性，无需开启正则数据探测，避免与富文本属性及手势冲突。
    textView.dataDetectorTypes = []
    textView.backgroundColor = UIColor.clear
    textView.isScrollEnabled = false
    textView.textContainerInset = insets
    MainActor.assumeIsolated {
      InkImageAttachment.bindAttachments(in: textStorage, layoutManager: layoutManager)
    }
    return textView
  }
}

// MARK: - 内部实现

/// 兜底富文本块的 UITextView：自持 `linkTapHandler` 并作为自身 delegate，
/// 拦截 `.link` 点击后交还业务方（返回 `true` 表示已处理）。
final class InkAttributedBlockTextView: UITextView, UITextViewDelegate {

  var linkTapHandler: ((URL, UIView) -> Bool)? {
    didSet { delegate = linkTapHandler == nil ? nil : self }
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let targetWidth = size.width > 0 ? size.width : (bounds.width > 0 ? bounds.width : 320)
    guard targetWidth > 0, let layoutManager = textContainer.layoutManager else {
      return super.sizeThatFits(size)
    }
    let contentWidth = max(0, targetWidth - textContainerInset.left - textContainerInset.right)
    textContainer.size = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
    _ = layoutManager.glyphRange(for: textContainer)
    let rect = layoutManager.usedRect(for: textContainer)
    let calculatedHeight = ceil(rect.height + textContainerInset.top + textContainerInset.bottom)
    return CGSize(width: targetWidth, height: calculatedHeight)
  }

  override var intrinsicContentSize: CGSize {
    sizeThatFits(CGSize(width: bounds.width > 0 ? bounds.width : UIView.noIntrinsicMetric, height: .greatestFiniteMagnitude))
  }

  func textView(
    _ textView: UITextView,
    shouldInteractWith URL: URL,
    in characterRange: NSRange,
    interaction: UITextItemInteraction
  ) -> Bool {
    if let handler = linkTapHandler, handler(URL, self) {
      return false
    }
    return true
  }
}
