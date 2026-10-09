import UIKit
import InkMarkdown

@MainActor
final class PartialReuseImageBackend: InkImageBackend {
  let loader: any InkImageLoading
  init(loader: any InkImageLoading) { self.loader = loader }
  func image(for request: InkImageRequest) async throws -> UIImage {
    try await loader.loadImage(source: request.source, display: request.display)
  }
}
