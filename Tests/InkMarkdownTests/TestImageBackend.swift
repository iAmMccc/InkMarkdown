import UIKit
@testable import InkMarkdown

/// 呈现测试专用后端：可控图片生产者与同步命中，不依赖网络或 Kingfisher。
@MainActor
final class TestImageBackend: InkImageBackend {
  let loader: any InkImageLoading
  private var cache: [String: UIImage] = [:]
  init(_ loader: any InkImageLoading) { self.loader = loader }
  func cachedImage(for request: InkImageRequest) -> UIImage? { cache[request.cacheKey] }
  func image(for request: InkImageRequest) async throws -> UIImage {
    if let image = cachedImage(for: request) { return image }
    let image = try await (request.generator ?? loader).loadImage(source: request.source, display: request.display)
    try Task.checkCancellation()
    cache[request.cacheKey] = image
    return image
  }
}
