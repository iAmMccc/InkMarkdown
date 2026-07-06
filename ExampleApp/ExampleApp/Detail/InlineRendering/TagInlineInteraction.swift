import UIKit

extension URL {
  /// 从 `inkmd-tag://` URL 中解析标签文本。
  public func tagInlineText() -> String? {
    guard scheme == TagInlineAttachment.urlScheme else { return nil }
    return URLComponents(url: self, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "text" })?.value
  }
}
