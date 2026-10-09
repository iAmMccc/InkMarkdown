import UIKit
import Kingfisher

/// PNG/JPEG 不保留 UIImage 的点尺寸；与图片数据一起保存实际 scale，确保磁盘往返不改变布局。
struct InkImageCacheSerializer: CacheSerializer {
  private struct Entry: Codable {
    let scale: Double
    let imageData: Data
  }

  func data(with image: UIImage, original: Data?) -> Data? {
    guard let data = DefaultCacheSerializer.default.data(with: image, original: original) else { return nil }
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    return try? encoder.encode(Entry(scale: Double(image.scale), imageData: data))
  }

  func image(with data: Data, options: KingfisherParsedOptionsInfo) -> UIImage? {
    guard let entry = try? PropertyListDecoder().decode(Entry.self, from: data),
          entry.scale.isFinite, entry.scale > 0 else { return nil }
    var options = options
    options.scaleFactor = CGFloat(entry.scale)
    return DefaultCacheSerializer.default.image(with: entry.imageData, options: options)
  }
}
