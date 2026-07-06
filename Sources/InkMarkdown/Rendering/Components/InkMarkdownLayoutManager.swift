import UIKit

/// 自定义 attribute key：标记行内代码区域，由 LayoutManager 绘制圆角背景。
public extension NSAttributedString.Key {
  static let inkInlineCodeBackground = NSAttributedString.Key("inkInlineCodeBackground")
  static let inkBlockquoteBar = NSAttributedString.Key("inkBlockquoteBar")
}

/// 行内代码背景配置（存储在 attribute value 中）
public struct InkInlineCodeBackgroundInfo {
  public let color: UIColor
  public let cornerRadius: CGFloat
  /// 内边距：背景向文字两侧扩展的距离
  public let insets: CGFloat
  /// 背景高度（nil 则使用行框高度）
  public let height: CGFloat?

  public init(color: UIColor, cornerRadius: CGFloat, insets: CGFloat, height: CGFloat? = nil) {
    self.color = color
    self.cornerRadius = cornerRadius
    self.insets = insets
    self.height = height
  }
}

/// 引用块竖线配置（存储在 attribute value 中）
public struct InkBlockquoteBarInfo {
  public let color: UIColor
  public let width: CGFloat
  public let cornerRadius: CGFloat

  public init(color: UIColor, width: CGFloat, cornerRadius: CGFloat = 1.5) {
    self.color = color
    self.width = width
    self.cornerRadius = cornerRadius
  }
}

/// 自定义 NSLayoutManager：
/// - 对标记了 `.inkInlineCodeBackground` 的文字绘制圆角背景
/// - 对标记了 `.inkBlockquoteBar` 的段落绘制左侧灰色竖线
public final class InkMarkdownLayoutManager: NSLayoutManager {

  public override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
    drawBlockquoteBars(forGlyphRange: glyphsToShow, at: origin)
  }

  public override func fillBackgroundRectArray(
    _ rectArray: UnsafePointer<CGRect>,
    count rectCount: Int,
    forCharacterRange charRange: NSRange,
    color: UIColor
  ) {
    guard let textStorage = textStorage else {
      super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
      return
    }

    var info: InkInlineCodeBackgroundInfo?
    textStorage.enumerateAttribute(.inkInlineCodeBackground, in: charRange, options: []) { value, _, _ in
      if let bg = value as? InkInlineCodeBackgroundInfo {
        info = bg
      }
    }

    guard let bgInfo = info, let context = UIGraphicsGetCurrentContext() else {
      super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
      return
    }

    context.saveGState()
    bgInfo.color.setFill()

    for i in 0..<rectCount {
      var rect = rectArray[i]
      rect.origin.x -= bgInfo.insets
      rect.size.width += bgInfo.insets * 2
      if let h = bgInfo.height, h < rect.height {
        let delta = rect.height - h
        rect.origin.y += delta / 2
        rect.size.height = h
      }
      let path = UIBezierPath(roundedRect: rect, cornerRadius: bgInfo.cornerRadius)
      path.fill()
    }

    context.restoreGState()
  }

  // MARK: - Blockquote Bar

  private func drawBlockquoteBars(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    guard let textStorage = textStorage, let textContainer = textContainers.first else { return }
    guard let context = UIGraphicsGetCurrentContext() else { return }

    let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)

    var barRanges: [(range: NSRange, info: InkBlockquoteBarInfo)] = []
    textStorage.enumerateAttribute(.inkBlockquoteBar, in: charRange, options: []) { value, range, _ in
      guard let info = value as? InkBlockquoteBarInfo else { return }
      barRanges.append((range, info))
    }

    guard !barRanges.isEmpty else { return }

    context.saveGState()

    for (range, info) in barRanges {
      let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
      var minY: CGFloat = .greatestFiniteMagnitude
      var maxY: CGFloat = 0

      enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
        minY = min(minY, usedRect.origin.y)
        maxY = max(maxY, usedRect.origin.y + usedRect.size.height)
      }

      guard minY < maxY else { continue }

      let barRect = CGRect(
        x: origin.x + textContainer.lineFragmentPadding,
        y: origin.y + minY,
        width: info.width,
        height: maxY - minY
      )

      info.color.setFill()
      let path = UIBezierPath(roundedRect: barRect, cornerRadius: info.cornerRadius)
      path.fill()
    }

    context.restoreGState()
  }
}
