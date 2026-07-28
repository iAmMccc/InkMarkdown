import CoreGraphics

/// 根据最大宽度与高度策略计算图片的最终显示尺寸。
///
/// - Parameters:
///   - size: 原始图片尺寸（逻辑 pt）。
///   - maxWidth: 允许的最大宽度。
///   - upscales: 小图是否放大至 `maxWidth`。
///   - minPlaceholder: 尺寸未知时的占位高度。
///   - maxHeight: 可选的最大高度上限。
/// - Returns: 适配后的显示尺寸。
func fitted(
  _ size: CGSize,
  maxWidth: CGFloat,
  upscales: Bool,
  minPlaceholder: CGFloat,
  maxHeight: CGFloat? = nil
) -> CGSize {
  guard size.width > 0, size.height > 0 else {
    return CGSize(width: maxWidth, height: minPlaceholder)
  }

  let targetWidth: CGFloat
  if size.width <= maxWidth && !upscales {
    targetWidth = size.width
  } else {
    targetWidth = maxWidth
  }

  let ratio = size.height / size.width
  var height = targetWidth * ratio
  if let maxH = maxHeight {
    height = min(height, maxH)
  }
  return CGSize(width: targetWidth, height: height)
}
