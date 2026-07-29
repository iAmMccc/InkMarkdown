import UIKit

/// 图片内存缓存键：来源 ID + 量化宽度 + scale。
///
/// 宽度按 64pt 桶量化，避免相近布局产生大量近似尺寸的重复缓存。
public struct DisplayKey: Hashable, Sendable {

  /// 图片来源的规范化 ID。
  public let sourceID: String

  /// 量化后的目标宽度（pt），为 64 的整数倍。
  public let bucketedWidth: Int

  /// 屏幕 scale factor 的整数表示（1 / 2 / 3）。
  public let scale: Int

  /// 内容模式同样影响生成型图片输出，必须参与缓存身份。
  public let contentMode: DisplayContext.ContentMode

  /// 由来源与显示上下文构造缓存键。
  public init(source: ImageSource, display: DisplayContext) {
    self.sourceID = source.canonicalID
    self.bucketedWidth = Int((display.maxPixelWidth / 64).rounded(.up)) * 64
    self.scale = Int(display.scale)
    self.contentMode = display.contentMode
  }

  /// 供 `NSCache` 使用的字符串键。
  var cacheKey: NSString {
    "\(sourceID)|\(bucketedWidth)|\(scale)|\(contentMode)" as NSString
  }
}

extension UIImage {

  /// 解码后位图在内存中的近似占用（字节）。
  var memoryCost: Int {
    guard let cg = cgImage else { return 0 }
    return cg.bytesPerRow * cg.height
  }
}
