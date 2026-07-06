import UIKit

/// 行内 `$...$` 标签：浅紫圆角背景 + 文本 + ` ›` 箭头，自绘成 UIImage 嵌入文本流。
///
/// 这是 **业务侧（ExampleApp）** 的自定义行内语法示例，演示如何在不修改 InkMarkdown
/// 核心库的前提下，通过 `InkInlineSyntax` 扩展点接入自定义语法。核心库不含任何此类约定。
public final class TagInlineAttachment: NSTextAttachment {

  /// 自定义 URL scheme，供 UITextView delegate 拦截点击。
  public static let urlScheme = "inkmd-tag"

  public let text: String

  public init(text: String, fontSize: CGFloat) {
    self.text = text
    super.init(data: nil, ofType: nil)
    let rendered = Self.render(text: text, fontSize: fontSize)
    image = rendered.image
    bounds = rendered.bounds
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public static func url(for text: String) -> URL? {
    var components = URLComponents()
    components.scheme = urlScheme
    components.host = "tap"
    components.queryItems = [URLQueryItem(name: "text", value: text)]
    return components.url
  }

  // MARK: - Rendering

  private struct RenderedTag {
    let image: UIImage
    let bounds: CGRect
  }

  private static func render(text: String, fontSize: CGFloat) -> RenderedTag {
    let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
    let textColor = UIColor.label
    let arrowColor = UIColor.tertiaryLabel
    let backgroundColor = UIColor(red: 0.93, green: 0.92, blue: 1.0, alpha: 1)

    let arrow = " ›"
    let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
    let arrowAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: arrowColor]

    let textSize = (text as NSString).size(withAttributes: textAttrs)
    let arrowSize = (arrow as NSString).size(withAttributes: arrowAttrs)
    let horizontalPadding: CGFloat = 10
    let verticalPadding: CGFloat = 3
    let cornerRadius: CGFloat = 6

    let totalWidth = textSize.width + arrowSize.width + horizontalPadding * 2
    let contentHeight = max(textSize.height, arrowSize.height)
    let totalHeight = contentHeight + verticalPadding * 2
    let canvasSize = CGSize(width: ceil(totalWidth), height: ceil(totalHeight))

    let renderer = UIGraphicsImageRenderer(size: canvasSize)
    let image = renderer.image { context in
      let cg = context.cgContext
      let rect = CGRect(origin: .zero, size: canvasSize)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
      cg.setFillColor(backgroundColor.cgColor)
      path.fill()

      let textPoint = CGPoint(
        x: horizontalPadding,
        y: (canvasSize.height - textSize.height) / 2
      )
      (text as NSString).draw(at: textPoint, withAttributes: textAttrs)

      let arrowPoint = CGPoint(
        x: horizontalPadding + textSize.width,
        y: (canvasSize.height - arrowSize.height) / 2
      )
      (arrow as NSString).draw(at: arrowPoint, withAttributes: arrowAttrs)
    }

    let descender = font.descender
    let bounds = CGRect(
      x: 0,
      y: descender - verticalPadding,
      width: canvasSize.width,
      height: canvasSize.height
    )
    return RenderedTag(image: image, bounds: bounds)
  }
}
