import ImageIO
import UIKit

/// 使用 ImageIO 在解码阶段直接生成目标像素尺寸的缩略图，避免全尺寸解码占用内存。
struct ImageIODownsampler {

  /// 从原始图片数据降采样至指定最大像素边长。
  func downsample(data: Data, maxPixel: CGFloat) throws -> UIImage {
    let options: [CFString: Any] = [
      kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
      throw ImageLoadError.decodeFailed
    }

    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixel
    ]

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
      throw ImageLoadError.decodeFailed
    }
    return UIImage(cgImage: cgImage)
  }

  /// 对已有 ``UIImage`` 再降采样（loader 返回超尺寸时使用）。
  func downsample(image: UIImage, maxPixel: CGFloat) throws -> UIImage {
    guard let data = image.pngData() else {
      throw ImageLoadError.decodeFailed
    }
    return try downsample(data: data, maxPixel: maxPixel)
  }
}
