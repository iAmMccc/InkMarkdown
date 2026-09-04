import UIKit
import InkMarkdown

/// 流式 remainder 富文本的承载视图：自持 `linkTapHandler` 并作为自身 delegate。
///
/// // 为什么 单独建子类而不复用 core 的 `InkAttributedBlockTextView`：
/// 那是 core 富文本兜底块的内部实现；本视图属于 SwiftUI adapter 的流式 attachment。
/// 契约保持一致——命中 `.link` 时先询问 handler，返回 `true` 表示宿主已处理并拦截
/// 系统默认行为；handler 为 `nil` 或返回 `false` 时交还系统默认（与正文块、表格单元格相同）。
///
/// Coordinator 在每次 reconcile 时用当前 configuration 的 handler 覆写此属性，
/// 因此 finish / promotion 前后以及 configuration 更新后都不会保留陈旧 callback。
final class InkStreamingTextView: UITextView, UITextViewDelegate {

  var linkTapHandler: ((URL, UIView) -> Bool)? {
    didSet { delegate = linkTapHandler == nil ? nil : self }
  }

  init() {
    let textContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    textContainer.lineFragmentPadding = 0
    let layoutManager = InkMarkdownLayoutManager()
    layoutManager.usesFontLeading = false
    layoutManager.addTextContainer(textContainer)
    let textStorage = NSTextStorage()
    textStorage.addLayoutManager(layoutManager)

    super.init(frame: .zero, textContainer: textContainer)
    isEditable = false
    isSelectable = true
    isScrollEnabled = false
    adjustsFontForContentSizeCategory = true
    backgroundColor = .clear
    textContainerInset = .zero
    // Markdown 文本在解析阶段已由引擎打上 .link 属性，无需系统数据探测器参与。
    dataDetectorTypes = []
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    // 流式 remainder 不提供编辑菜单；链接点击不受影响。
    false
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
