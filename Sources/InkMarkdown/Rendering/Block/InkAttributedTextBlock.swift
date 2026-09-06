import UIKit

/// 兜底块：把非自定义 UIView 的部分塞回 NSAttributedString，用 UITextView 渲染。
public struct InkAttributedTextBlock: InkRenderableBlock, InkReusableBlock, @unchecked Sendable {
  nonisolated(unsafe) public let attributedText: NSAttributedString
  /// 文本容器内边距。
  nonisolated public let insets: UIEdgeInsets
  /// 链接点击回调。命中 `.link` 属性时交还业务方处理；返回 `true` 拦截默认行为。
  /// 与表格单元格 `InkTableCellTextView` 共用同一套 `linkTapHandler` 语义，
  /// 使富文本兜底块里的链接（含业务自定义 scheme，如 `$标签$`）也能被拦截。
  nonisolated(unsafe) public let linkTapHandler: ((URL, UIView) -> Bool)?
  nonisolated private let linkTapSemanticIdentity: InkSemanticIdentity?

  nonisolated public init(
    attributedText: NSAttributedString,
    linkTapHandler: ((URL, UIView) -> Bool)? = nil
  ) {
    self.init(
      attributedText: attributedText,
      insets: InkAppearance.shared.text.blockInsets,
      linkTapHandler: linkTapHandler,
      linkTapSemanticIdentity: linkTapHandler == nil ? nil : .unique()
    )
  }

  nonisolated public init(
    attributedText: NSAttributedString,
    insets: UIEdgeInsets,
    linkTapHandler: ((URL, UIView) -> Bool)? = nil
  ) {
    self.init(
      attributedText: attributedText,
      insets: insets,
      linkTapHandler: linkTapHandler,
      linkTapSemanticIdentity: linkTapHandler == nil ? nil : .unique()
    )
  }

  nonisolated init(
    attributedText: NSAttributedString,
    insets: UIEdgeInsets,
    linkTapHandler: ((URL, UIView) -> Bool)?,
    linkTapSemanticIdentity: InkSemanticIdentity?
  ) {
    self.attributedText = attributedText
    self.insets = insets
    self.linkTapHandler = linkTapHandler
    self.linkTapSemanticIdentity = linkTapSemanticIdentity
  }

  @MainActor public func makeView() -> UIView {
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
    textView.adjustsFontForContentSizeCategory = true
    textView.textContainerInset = insets
    textView.bindInlineImageAttachments()
    return textView
  }

  @MainActor
  public func updateExistingView(_ view: UIView) -> Bool {
    guard let textView = view as? InkAttributedBlockTextView else { return false }
    textView.linkTapHandler = linkTapHandler
    textView.textStorage.setAttributedString(attributedText)
    textView.textContainerInset = insets
    textView.bindInlineImageAttachments()
    textView.invalidateIntrinsicContentSize()
    return true
  }

  @MainActor
  public func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    guard let previous = previous as? InkAttributedTextBlock else { return false }
    return attributedText.isEqual(to: previous.attributedText)
      && insets == previous.insets
      && linkTapSemanticIdentity == previous.linkTapSemanticIdentity
  }
}

// MARK: - 内部实现

/// 兜底富文本块的 UITextView：自持 `linkTapHandler` 并作为自身 delegate，
/// 拦截 `.link` 点击后交还业务方（返回 `true` 表示已处理）。
final class InkAttributedBlockTextView: UITextView, UITextViewDelegate {

  var linkTapHandler: ((URL, UIView) -> Bool)? {
    didSet { delegate = linkTapHandler == nil ? nil : self }
  }

  /// 宿主接收异步图片引起的高度变化；自身先失效文本测量。
  var onInlineImageHeightChange: (() -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    bindInlineImageAttachments()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    bindInlineImageAttachments()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard previousTraitCollection?.displayScale != traitCollection.displayScale else { return }
    bindInlineImageAttachments()
  }

  func bindInlineImageAttachments() {
    InkImageAttachment.bindAttachments(in: self, onHeightChange: { [weak self] in
      guard let self else { return }
      self.invalidateIntrinsicContentSize()
      self.setNeedsLayout()
      self.onInlineImageHeightChange?()
    })
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let targetWidth = size.width > 0 ? size.width : (bounds.width > 0 ? bounds.width : 320)
    guard targetWidth > 0, let layoutManager = textContainer.layoutManager else {
      return super.sizeThatFits(size)
    }
    let contentWidth = max(0, targetWidth - textContainerInset.left - textContainerInset.right)
    textContainer.size = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
    bindInlineImageAttachments()
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
