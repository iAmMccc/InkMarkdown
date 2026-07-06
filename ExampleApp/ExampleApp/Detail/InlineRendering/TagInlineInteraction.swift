import UIKit

/// 行内 `$...$` 标签被点击时的回调协议（业务侧）。
public protocol TagInlineInteractionHandler: AnyObject {
  func tagInline(_ text: String, didTapInTextView textView: UITextView)
}

extension URL {
  /// 从 `inkmd-tag://` URL 中解析标签文本。
  public func tagInlineText() -> String? {
    guard scheme == TagInlineAttachment.urlScheme else { return nil }
    return URLComponents(url: self, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "text" })?.value
  }
}
