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
  public var color: InkLaTeXColor
  public var horizontalPadding: CGFloat
  public var verticalPadding: CGFloat
  public var maxPixelHeight: CGFloat

  public init(
    fontSize: CGFloat = 18,
    color: InkLaTeXColor = .init(red: 0, green: 0, blue: 0),
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

  /// 可放入生成图片 source identity 的稳定样式键；主题颜色和全部排版参数均参与计算。
  public var stableID: String {
    let identity = [
      String(format: "%.3f", fontSize),
      "\(color.red),\(color.green),\(color.blue),\(color.alpha)",
      String(format: "%.3f", horizontalPadding),
      String(format: "%.3f", verticalPadding),
      String(format: "%.3f", maxPixelHeight),
    ].joined(separator: "\u{1F}")
    return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
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
  public var stableID: String {
    let identity = [
      InkLaTeXImageRenderer.rendererVersion,
      latex,
      mode.rawValue,
      String(format: "%.3f", display.maxPixelWidth),
      String(format: "%.3f", display.scale),
      display.contentMode == .fit ? "fit" : "fill",
      style.stableID,
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
