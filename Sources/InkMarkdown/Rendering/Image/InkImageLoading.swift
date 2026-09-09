import UIKit

/// 图片加载器协议：将 ``ImageSource`` 解码为指定显示尺寸的 ``UIImage``。
///
/// 用于生成图生产者及协调器请求桥接；完整图片管理应实现 ``InkImageBackend``。
/// 不提供隐式网络加载器，后端必须由宿主显式配置。
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
