import InkMarkdown
import UIKit

#if canImport(Kingfisher)
#error("Core-only consumer must not compile Kingfisher")
#endif

@MainActor
private final class HostImages: InkImageBackend {
  func image(for request: InkImageRequest) async throws -> UIImage {
    throw ImageLoadError.assetNotFound("host-owned-image")
  }
}

public enum CoreConsumerProbe {
  public static var configuration: InkConfiguration { .standard }
  @MainActor public static func customImages() -> InkConfiguration {
    var result = InkConfiguration.standard
    result.appearance.imageRendering.backend = HostImages()
    return result
  }
}
