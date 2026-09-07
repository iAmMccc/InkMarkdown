import UIKit

/// 生成型图片 loader 的统一约定。
///
/// 实现者只生成位图；它不应维护任何图片缓存、订阅或下载队列。这些职责由
/// ``InkImageBackend`` 统一承担。
public protocol InkGeneratedImageLoading: InkImageLoading {
  func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage
}

public extension InkGeneratedImageLoading {
  func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    guard let request = source.generatedRequest else {
      throw ImageLoadError.decodeFailed
    }
    return try await loadGeneratedImage(request: request, display: display)
  }
}
