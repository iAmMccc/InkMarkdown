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
    // 有自定义 linkTapHandler 时关闭数据探测，避免系统自动识别与业务 scheme 抢占点击。
    textView.dataDetectorTypes = linkTapHandler == nil ? UIDataDetectorTypes.link : []
    textView.backgroundColor = UIColor.clear
    textView.isScrollEnabled = false
    textView.textContainerInset = insets
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
