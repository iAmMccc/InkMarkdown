import UIKit

/// 图片加载器协议：将 ``ImageSource`` 解码为指定显示尺寸的 ``UIImage``。
///
/// 宿主可注入自定义实现（CDN 签名、鉴权 Header、本地数据库等）。
/// 为 `nil` 时 ``InkImageStore`` 回退到内置 `DefaultURLSessionImageLoader`。
public protocol InkImageLoading: Sendable, InkSemanticIdentityProviding {
  /// 异步加载并解码图片。
  ///
  /// - Parameters:
  ///   - source: 规范化后的图片来源。
  ///   - display: 目标显示上下文（宽度量化、scale）。
  /// - Returns: 解码后的位图；Animated 策略由上层根据 ``AnimatedImagePolicy`` 处理。
  func loadImage(
    source: ImageSource,
    display: DisplayContext
  ) async throws -> UIImage
}
