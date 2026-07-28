import CoreGraphics

/// 单次图片加载与解码的目标显示参数。
///
/// 参与 `DisplayKey` 量化，使同一来源在不同布局宽度下可缓存独立尺寸的位图。
public struct DisplayContext: Hashable, Sendable {

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
  ///   - maxPixelWidth: 目标最大像素宽度。
  ///   - scale: 屏幕 scale factor。
  ///   - contentMode: 缩放模式，默认 `.fit`。
  public init(
    maxPixelWidth: CGFloat,
    scale: CGFloat,
    contentMode: ContentMode = .fit
  ) {
    self.maxPixelWidth = maxPixelWidth
    self.scale = scale
    self.contentMode = contentMode
  }
}
