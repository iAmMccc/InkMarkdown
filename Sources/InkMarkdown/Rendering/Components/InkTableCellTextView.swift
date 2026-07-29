import UIKit

/// 表格单元格文本视图。
///
/// 用只读、不可滚动的 `UITextView` 替代 `UILabel`，以支持单元格内 `.link` 属性的点击
/// （`UILabel` 无法响应链接点击）。行内解析与正文共用同一套 `InkConfiguration`，
/// 因此加粗/斜体/行内代码/自定义 Directive 的标蓝、降级、隐藏三态表现与正文一致。
///
/// 点击命中 `.link` 时通过 `linkTapHandler` 交还业务方处理；返回 `true` 表示已处理。
final class InkTableCellTextView: UITextView, UITextViewDelegate {

  private let linkTapHandler: ((URL, UIView) -> Bool)?

  init(attributedText: NSAttributedString, linkColor: UIColor, linkTapHandler: ((URL, UIView) -> Bool)?) {
    self.linkTapHandler = linkTapHandler

    let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    let layoutManager = InkMarkdownLayoutManager()
    layoutManager.usesFontLeading = false
    layoutManager.addTextContainer(container)
    let storage = NSTextStorage(attributedString: attributedText)
    storage.addLayoutManager(layoutManager)

    super.init(frame: .zero, textContainer: container)

    isEditable = false
    isSelectable = true
    isScrollEnabled = false
    backgroundColor = .clear
    textContainerInset = .zero
    dataDetectorTypes = []
    linkTextAttributes = [.foregroundColor: linkColor]
    delegate = self
    MainActor.assumeIsolated {
      InkImageAttachment.bindAttachments(in: storage, layoutManager: layoutManager)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - 禁用选择菜单（保留链接点击）

  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    // 表格单元格不提供复制/粘贴等编辑菜单，避免与整表长按复制冲突；链接点击不受影响。
    return false
  }

  // MARK: - UITextViewDelegate

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
