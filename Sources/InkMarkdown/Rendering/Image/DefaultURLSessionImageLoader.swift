import UIKit

/// 内置默认图片加载器：支持 HTTP(S)、本地文件、Data URL、Asset 与 Bundle 路径。
///
/// 远程请求通过 ``ImageSecurityPolicy`` 控制 scheme、主机白名单与重定向校验；
/// 解码阶段使用 ``ImageIODownsampler`` 按 ``DisplayContext/maxPixelWidth`` 降采样。
public final class DefaultURLSessionImageLoader: InkImageLoading, @unchecked Sendable {

  private let session: URLSession
  /// 须强引用：``URLSession`` 对 delegate 仅弱引用。
  private let redirectValidator: RedirectValidator
  private let downsampleHelper = ImageIODownsampler()

  /// 使用指定安全策略创建加载器。
  public init(securityPolicy: ImageSecurityPolicy = ImageSecurityPolicy()) {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 15
    configuration.timeoutIntervalForResource = 60
    configuration.waitsForConnectivity = false
    configuration.httpMaximumConnectionsPerHost = 4
    let redirectValidator = RedirectValidator(policy: securityPolicy)
    self.redirectValidator = redirectValidator
    self.session = URLSession(
      configuration: configuration,
      delegate: redirectValidator,
      delegateQueue: nil
    )
  }

  deinit {
    session.invalidateAndCancel()
  }

  public func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    switch source.scheme {
    case .http, .https:
      let (data, response) = try await session.inkData(from: source.requestURL)
      guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
        throw ImageLoadError.invalidResponse
      }
      guard isImageData(data) else {
        throw ImageLoadError.notImageData
      }
      return try downsampleHelper.downsample(data: data, maxPixel: display.maxPixelWidth)

    case .file:
      let data = try Data(contentsOf: source.requestURL)
      return try downsampleHelper.downsample(data: data, maxPixel: display.maxPixelWidth)

    case .data:
      guard let dataString = source.requestURL.absoluteString.components(separatedBy: ",").last,
            let data = Data(base64Encoded: dataString) else {
        throw ImageLoadError.invalidBase64
      }
      return try downsampleHelper.downsample(data: data, maxPixel: display.maxPixelWidth)

    case .asset:
      let name = source.requestURL.host ?? source.requestURL.lastPathComponent
      guard let image = UIImage(named: name) else {
        throw ImageLoadError.assetNotFound(name)
      }
      return image

    case .bundle:
      let path = source.requestURL.path
      guard let image = UIImage(contentsOfFile: path) else {
        throw ImageLoadError.bundleNotFound(path)
      }
      return try downsampleHelper.downsample(image: image, maxPixel: display.maxPixelWidth)

    case .relative, .unknown:
      throw ImageLoadError.unsupportedScheme
    }
  }

  /// 通过文件头魔数校验是否为图片数据，不依赖 Content-Type。
  private func isImageData(_ data: Data) -> Bool {
    guard data.count >= 4 else { return false }
    let bytes = [UInt8](data.prefix(4))
    // JPEG: FF D8 FF
    if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF { return true }
    // PNG: 89 50 4E 47
    if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 { return true }
    // GIF: 47 49 46
    if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 { return true }
    // WebP: RIFF + WEBP（需 12 bytes）
    if data.count >= 12 {
      let riff = bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46
      let webpBytes = [UInt8](data[8..<12])
      let webp = webpBytes[0] == 0x57 && webpBytes[1] == 0x45 && webpBytes[2] == 0x42 && webpBytes[3] == 0x50
      if riff && webp { return true }
    }
    // BMP: 42 4D
    if bytes[0] == 0x42 && bytes[1] == 0x4D { return true }
    return false
  }
}
