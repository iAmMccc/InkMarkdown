import CoreGraphics

/// 单次图片加载与解码的目标显示参数。
///
/// 参与 `DisplayKey` 量化，使同一来源在不同布局宽度下可缓存独立尺寸的位图。
public struct DisplayContext: Hashable, Sendable {

  /// 非法或非正宽度使用的最小安全像素宽度。
  public static let minimumMaxPixelWidth: CGFloat = 1
  /// 图片管线允许的最大请求宽度；同时保证 `DisplayKey` 的量化不会溢出 `Int`。
  public static let maximumMaxPixelWidth: CGFloat = 1_048_576
  /// iOS/UIKit display scale 的最小安全值；同时保证 `DisplayKey.scale` 至少为 1。
  public static let minimumScale: CGFloat = 1
  /// 图片管线允许的最大 scale，避免异常调用创建无意义的巨大位图。
  public static let maximumScale: CGFloat = 8

  /// 目标最大像素宽度（已乘以屏幕 scale）。
  public let maxPixelWidth: CGFloat

  /// 屏幕或目标视图的 scale factor（1x / 2x / 3x）。
  public let scale: CGFloat

  /// 内容缩放模式。
  public let contentMode: ContentMode

  /// 图片在容器内的缩放策略。
  public enum ContentMode: Hashable, Sendable {
    /// 等比缩放至不超过 `maxPixelWidth`。
    case fit
    /// 等比放大以填满宽度（可能超出原始尺寸）。
    case fill
  }

  /// - Parameters:
  ///   - maxPixelWidth: 目标最大像素宽度。NaN、无穷、零或负数规范化为
  ///     ``minimumMaxPixelWidth``；过大值钳制为 ``maximumMaxPixelWidth``。
  ///   - scale: 屏幕 scale factor。小于 1、NaN、无穷、零或负数规范化为
  ///     ``minimumScale``；过大值钳制为 ``maximumScale``。
  ///   - contentMode: 缩放模式，默认 `.fit`。
  public init(
    maxPixelWidth: CGFloat,
    scale: CGFloat,
    contentMode: ContentMode = .fit
  ) {
    self.maxPixelWidth = Self.sanitized(
      maxPixelWidth,
      minimum: Self.minimumMaxPixelWidth,
      maximum: Self.maximumMaxPixelWidth
    )
    self.scale = Self.sanitized(
      scale,
      minimum: Self.minimumScale,
      maximum: Self.maximumScale
    )
    self.contentMode = contentMode
  }

  private static func sanitized(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
    guard value.isFinite, value > 0 else { return minimum }
    return min(max(value, minimum), maximum)
  }
}
