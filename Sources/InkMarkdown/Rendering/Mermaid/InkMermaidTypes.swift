import CryptoKit
import Foundation
import UIKit

/// Mermaid fenced-code 的识别规则。
///
/// 仅接受 Markdown 解析器原样给出的 `mermaid` 标记；不做大小写兼容，避免意外接管
/// 其他代码块语言。
public enum InkMermaidFence {
  public static func isMermaid(language: String?) -> Bool {
    language == "mermaid"
  }
}

/// Mermaid 的配色语义。调用方应以宿主的实际界面风格构造该值。
public enum InkMermaidTheme: String, Hashable, Sendable {
  case light
  case dark
}

/// 影响 Mermaid 位图结果的显示上下文。
public struct InkMermaidDisplayContext: Hashable, Sendable {
  public let maxPixelWidth: CGFloat
  public let scale: CGFloat
  public let theme: InkMermaidTheme

  public init(maxPixelWidth: CGFloat, scale: CGFloat, theme: InkMermaidTheme) {
    self.maxPixelWidth = maxPixelWidth
    self.scale = scale
    self.theme = theme
  }
}

/// Mermaid 渲染限制。所有值均在进入 WebKit 前进行校验或截断。
public struct InkMermaidRenderLimits: Hashable, Sendable {
  public var maximumSourceCharacters: Int
  public var minimumPixelWidth: CGFloat
  public var maximumPixelWidth: CGFloat
  public var maximumPixelHeight: CGFloat
  public var timeout: TimeInterval

  public init(
    maximumSourceCharacters: Int = 50_000,
    minimumPixelWidth: CGFloat = 1,
    maximumPixelWidth: CGFloat = 4_096,
    maximumPixelHeight: CGFloat = 4_096,
    timeout: TimeInterval = 8
  ) {
    self.maximumSourceCharacters = maximumSourceCharacters
    self.minimumPixelWidth = minimumPixelWidth
    self.maximumPixelWidth = maximumPixelWidth
    self.maximumPixelHeight = maximumPixelHeight
    self.timeout = timeout
  }
}

/// 给生成图片管线的请求值。此类型不负责缓存；`cacheIdentity` 仅用于由调用方管理的缓存。
public struct InkMermaidRenderRequest: Hashable, Sendable {
  public let source: String
  public let display: InkMermaidDisplayContext

  public init(source: String, display: InkMermaidDisplayContext) {
    self.source = source
    self.display = display
  }
}

/// 成功渲染后的位图及其 PNG 编码。
@MainActor
public struct InkMermaidRenderResult {
  public let image: UIImage
  public let pngData: Data
  public let cacheIdentity: String

  public init(image: UIImage, pngData: Data, cacheIdentity: String) {
    self.image = image
    self.pngData = pngData
    self.cacheIdentity = cacheIdentity
  }
}

/// 可以由上游按类别处理的 Mermaid 失败原因。
public enum InkMermaidRenderError: Error, Equatable, Sendable {
  case inputTooLarge(limit: Int)
  case invalidDisplaySize
  case invalidLimits
  case bundledResourceMissing
  case pageLoadFailed
  case pageProcessTerminated
  case javaScript(message: String)
  case invalidJavaScriptResponse
  case invalidDiagramSize
  case zeroSize
  case exceedsMaximumSize
  case snapshotFailed
  case pngEncodingFailed
  case timedOut
  /// 历史兼容 case：`InkMermaidRenderScheduler` 不再抛出；Mermaid 准入队列上限由图片后端控制。
  case queueFull(limit: Int)
}

public extension InkMermaidRenderRequest {
  /// 稳定、不可逆的缓存身份：源码、固定渲染器 / Mermaid 版本、显示大小和主题均参与计算。
  /// 不包含任何临时 WebKit 标识，因而可跨进程复用。
  func cacheIdentity(rendererVersion: String = InkMermaidImageRenderer.rendererVersion) -> String {
    let canonical = [
      "renderer=" + rendererVersion,
      "mermaid=" + InkMermaidImageRenderer.mermaidVersion,
      "width=" + String(format: "%.3f", Double(display.maxPixelWidth)),
      "scale=" + String(format: "%.3f", Double(display.scale)),
      "theme=" + display.theme.rawValue,
      "source=" + source
    ].joined(separator: "\n")
    return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}

/// Bridge 的 JSON / JavaScript 参数编码。保持为模块内部可测试 API，禁止把 Mermaid 源码拼入脚本。
enum InkMermaidBridgeEncoding {
  static func javaScriptStringLiteral(_ value: String) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: [value], options: [])
    guard let arrayLiteral = String(data: data, encoding: .utf8), arrayLiteral.count >= 2 else {
      throw InkMermaidRenderError.invalidJavaScriptResponse
    }
    return String(arrayLiteral.dropFirst().dropLast())
  }
}
