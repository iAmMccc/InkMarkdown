import UIKit
import InkMarkdown

/// `$...$` 行内标签语法——**业务侧自定义语法的示例实现**。
///
/// 通过实现核心库的 `InkInlineSyntax` 扩展点，在不修改 InkMarkdown 的前提下，
/// 把文本流里的 `$标签$` 渲染成浅紫圆角胶囊（`TagInlineAttachment`）。
///
/// 用法：
/// ```swift
/// var config = InkConfiguration()
/// config.inlineSyntaxes = [TagInlineSyntax()]
/// let attributed = InkAttributedRenderer.render(markdown, configuration: config)
/// ```
public struct TagInlineSyntax: InkInlineSyntax {

  public init() {}

  /// 扫描纯文本中的 `$...$`，命中则整段渲染为带标签胶囊的属性字符串；
  /// 文本中不含 `$` 时返回 `nil`，交还核心默认渲染。
  public func render(text: String, context: InkInlineContext) -> NSAttributedString? {
    guard text.contains("$") else { return nil }
    return Self.renderInlineTags(in: text, context: context)
  }

  private static func renderInlineTags(in source: String, context: InkInlineContext) -> NSAttributedString {
    let baseFont = context.baseFont
    let baseFontSize = baseFont.pointSize
    let baseAttrs: [NSAttributedString.Key: Any] = [
      .font: baseFont,
      .foregroundColor: context.textColor,
    ]
    let result = NSMutableAttributedString()
    var cursor = source.startIndex

    while cursor < source.endIndex {
      guard let openDollar = source[cursor...].firstIndex(of: "$") else {
        result.append(NSAttributedString(string: String(source[cursor...]), attributes: baseAttrs))
        break
      }
      if openDollar > cursor {
        result.append(NSAttributedString(string: String(source[cursor..<openDollar]), attributes: baseAttrs))
      }

      let afterOpen = source.index(after: openDollar)
      let lineEnd = source[afterOpen...].firstIndex(of: "\n") ?? source.endIndex
      let scanRange = afterOpen..<lineEnd
      guard let closeDollar = source[scanRange].firstIndex(of: "$"), closeDollar > afterOpen else {
        result.append(NSAttributedString(string: "$", attributes: baseAttrs))
        cursor = afterOpen
        continue
      }

      let rawTagText = String(source[afterOpen..<closeDollar])
      let trimmed = rawTagText.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        result.append(NSAttributedString(string: "$\(rawTagText)$", attributes: baseAttrs))
        cursor = source.index(after: closeDollar)
        continue
      }

      let attachment = TagInlineAttachment(text: trimmed, fontSize: baseFontSize)
      let attachmentString = NSMutableAttributedString(attachment: attachment)
      let tagRange = NSRange(location: 0, length: attachmentString.length)
      if let url = TagInlineAttachment.url(for: trimmed) {
        attachmentString.addAttribute(.link, value: url, range: tagRange)
      }
      result.append(attachmentString)
      cursor = source.index(after: closeDollar)
    }

    return result
  }
}
