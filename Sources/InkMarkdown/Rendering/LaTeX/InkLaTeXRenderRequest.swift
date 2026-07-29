import CryptoKit
import Foundation
import UIKit

/// LaTeX 公式的显示模式。
public enum InkLaTeXRenderMode: String, Hashable, Sendable {
  case inline
  case block
}

/// 可跨任务传递的 RGBA 颜色值，避免让 UIKit 颜色进入缓存身份。
public struct InkLaTeXColor: Hashable, Sendable {
  public let red: UInt8
  public let green: UInt8
  public let blue: UInt8
  public let alpha: UInt8

  public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }

  /// 从 UIKit 颜色提取 RGBA；须在主线程调用，等价于 ``init(resolving:environment:)`` 且环境为 ``InkRenderEnvironment/current``。
  @MainActor
  public init(_ uiColor: UIColor) {
    self.init(resolving: uiColor, environment: .current)
  }

  /// 在指定 trait 快照下把（可动态的）`UIColor` 解析为 Sendable RGBA，供后台渲染路径使用。
  ///
  /// 动态色须先 ``UIColor/resolvedColor(with:)`` 再取分量；``getRed(_:green:blue:alpha:)``
  /// 仅在颜色可转换到 RGB 时才返回 `true`，否则分量指针不变
  ///（[Apple 文档](https://developer.apple.com/documentation/uikit/uicolor/getred(_:green:blue:alpha:) )）。
  public init(resolving uiColor: UIColor, environment: InkRenderEnvironment) {
    let resolved = uiColor.resolvedColor(with: environment.traitCollection)
    let components = Self.rgbaComponents(from: resolved)
    self.red = components.red
    self.green = components.green
    self.blue = components.blue
    self.alpha = components.alpha
  }

  private static func rgbaComponents(from color: UIColor) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 1
    if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
      return quantized(red: red, green: green, blue: blue, alpha: alpha)
    }
    var white: CGFloat = 0
    if color.getWhite(&white, alpha: &alpha) {
      return quantized(red: white, green: white, blue: white, alpha: alpha)
    }
    if let cgComponents = color.cgColor.components, !cgComponents.isEmpty {
      let count = cgComponents.count
      let r = cgComponents[0]
      let g = count > 1 ? cgComponents[1] : r
      let b = count > 2 ? cgComponents[2] : r
      let a = count > 3 ? cgComponents[3] : CGFloat(color.cgColor.alpha)
      return quantized(red: r, green: g, blue: b, alpha: a)
    }
    // 仍无法转换时使用中性灰，避免把失败误当作纯黑。
    return (red: 128, green: 128, blue: 128, alpha: 255)
  }

  private static func quantized(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> (UInt8, UInt8, UInt8, UInt8) {
    (
      UInt8(clamping: Int((red * 255).rounded())),
      UInt8(clamping: Int((green * 255).rounded())),
      UInt8(clamping: Int((blue * 255).rounded())),
      UInt8(clamping: Int((alpha * 255).rounded()))
    )
  }

  @MainActor
  var uiColor: UIColor {
    UIColor(
      red: CGFloat(red) / 255,
      green: CGFloat(green) / 255,
      blue: CGFloat(blue) / 255,
      alpha: CGFloat(alpha) / 255
    )
  }
}

/// 影响 LaTeX 图片内容和缓存身份的视觉样式。
public struct InkLaTeXStyle: Hashable, Sendable {
  public var fontSize: CGFloat
  /// 公式颜色。`nil` 表示跟随渲染上下文的前景色（行内跟随 ``InkInlineContext/textColor``，
  /// 块级跟随 ``InkAppearance/Text/color``）；显式设色则始终使用该色。
  public var color: InkLaTeXColor?
  public var horizontalPadding: CGFloat
  public var verticalPadding: CGFloat
  public var maxPixelHeight: CGFloat

  public init(
    fontSize: CGFloat = 18,
    color: InkLaTeXColor? = nil,
    horizontalPadding: CGFloat = 2,
    verticalPadding: CGFloat = 2,
    maxPixelHeight: CGFloat = 2_048
  ) {
    self.fontSize = fontSize
    self.color = color
    self.horizontalPadding = horizontalPadding
    self.verticalPadding = verticalPadding
    self.maxPixelHeight = maxPixelHeight
  }

  /// 可放入生成图片 source identity 的稳定样式键；`color` 为 `nil` 时必须传入已解析的实际颜色。
  public func stableID(resolvedColor: InkLaTeXColor) -> String {
    let effectiveColor = color ?? resolvedColor
    let identity = [
      String(format: "%.3f", fontSize),
      color == nil ? "ctx" : "explicit",
      "\(effectiveColor.red),\(effectiveColor.green),\(effectiveColor.blue),\(effectiveColor.alpha)",
      String(format: "%.3f", horizontalPadding),
      String(format: "%.3f", verticalPadding),
      String(format: "%.3f", maxPixelHeight),
    ].joined(separator: "\u{1F}")
    return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  /// 返回带上已解析颜色的样式副本，供渲染器与 loader 使用。
  func resolved(with color: InkLaTeXColor) -> InkLaTeXStyle {
    var copy = self
    copy.color = self.color ?? color
    return copy
  }
}

/// 交给 ``InkLaTeXImageRenderer`` 的单次图片渲染请求。
public struct InkLaTeXRenderRequest: Hashable, Sendable {
  /// 已移除 Markdown 分隔符的 LaTeX 源码。
  public let latex: String
  public let mode: InkLaTeXRenderMode
  public let display: DisplayContext
  public let style: InkLaTeXStyle

  public init(
    latex: String,
    mode: InkLaTeXRenderMode,
    display: DisplayContext,
    style: InkLaTeXStyle = .init()
  ) {
    self.latex = Self.normalizedLatex(latex)
    self.mode = mode
    self.display = display
    self.style = style
  }

  /// 可作为生成图片源 identity 的稳定键；改变内容、显示上下文、主题/样式或 renderer 版本都会改变它。
  /// - Parameter resolvedColor: 当 ``InkLaTeXStyle/color`` 为 `nil` 时传入已解析的实际上色。
  public func stableID(resolvedColor: InkLaTeXColor) -> String {
    let identity = [
      InkLaTeXImageRenderer.rendererVersion,
      latex,
      mode.rawValue,
      String(format: "%.3f", display.maxPixelWidth),
      String(format: "%.3f", display.scale),
      display.contentMode == .fit ? "fit" : "fill",
      style.stableID(resolvedColor: resolvedColor),
    ].joined(separator: "\u{1F}")
    return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  /// 生成图片 source identity 前使用同一规范化规则，避免缓存键与实际渲染内容不一致。
  public static func normalizedLatex(_ latex: String) -> String {
    latex
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
