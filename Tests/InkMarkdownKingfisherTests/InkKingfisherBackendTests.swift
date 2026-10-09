import Testing
import UIKit
import InkMarkdown
import Kingfisher
@testable import InkMarkdownKingfisher

private actor Generator: InkImageLoading {
  var count = 0
  let delay: UInt64
  let scale: CGFloat
  init(delay: UInt64 = 0, scale: CGFloat = 1) { self.delay = delay; self.scale = scale }
  func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    count += 1
    try await Task.sleep(nanoseconds: delay)
    return await MainActor.run {
      let format = UIGraphicsImageRendererFormat()
      format.scale = scale
      return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: format).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
      }
    }
  }
}

@Suite @MainActor
struct InkKingfisherBackendTests {
  @Test(arguments: [1.0, 2.0, 3.0], [12.0, 64.0])
  func assetDownsamplingPreservesScaleAndPixelBudget(scale: Double, pixelLimit: Double) throws {
    let format = UIGraphicsImageRendererFormat()
    format.scale = CGFloat(scale)
    let asset = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 8), format: format).image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 16, height: 8))
    }
    let output = try InkKingfisherImageBackend.downsampleAsset(asset, maxPixelWidth: CGFloat(pixelLimit))
    #expect(output.scale == CGFloat(scale))
    if pixelLimit == 64 {
      #expect(output.size == CGSize(width: 16, height: 8))
      #expect(output.cgImage?.width == asset.cgImage?.width)
      #expect(output.cgImage?.height == asset.cgImage?.height)
    } else {
      #expect(output.cgImage?.width == 12)
      #expect(output.cgImage?.height == 6)
      #expect(abs(output.size.width - CGFloat(12 / scale)) < 0.001)
      #expect(abs(output.size.height - CGFloat(6 / scale)) < 0.001)
    }
  }

  private func request(_ generator: Generator, name: String = "x", width: CGFloat = 64) -> InkImageRequest {
    InkImageRequest(source: ImageSource(generated: InkGeneratedImageRequest(
      owner: "test", rendererVersion: "1", source: name, styleIdentity: "1")),
      display: DisplayContext(maxPixelWidth: width, scale: 1), generator: generator,
      generatorIdentity: "test.generator.1")
  }

  @Test func ignoresLegacyAssetDiskEntriesWithoutDeletingThem() async throws {
    var config = InkKingfisherImageBackend.Configuration()
    config.usesDiskCache = true
    let name = UUID().uuidString
    let source = ImageSource(url: try #require(URL(string: "asset://missing-\(name)")))
    let r = InkImageRequest(source: source, display: DisplayContext(maxPixelWidth: 64, scale: 3))
    let legacy = ImageCache(name: "InkMarkdown." + name + ".v2.pixels-\(config.maxPixelSize)")
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let wrongScale = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 24), format: format).image { _ in }
    try await legacy.store(wrongScale, forKey: r.cacheKey, cacheSerializer: InkImageCacheSerializer())
    legacy.clearMemoryCache()
    #expect(try await legacy.retrieveImageInDiskCache(forKey: r.cacheKey,
      options: [.cacheSerializer(InkImageCacheSerializer())]) != nil)

    let backend = InkKingfisherImageBackend(configuration: config, cacheName: name)
    // 旧缓存不得短路真实资源查找，也不能被回填到后端内存。
    do {
      _ = try await backend.image(for: r)
      Issue.record("Legacy asset cache bypassed resource lookup")
    } catch ImageLoadError.assetNotFound(let missingName) {
      #expect(missingName == "missing-\(name)")
    }
    #expect(backend.cachedImage(for: r) == nil)
    #expect(try await legacy.retrieveImageInDiskCache(forKey: r.cacheKey,
      options: [.cacheSerializer(InkImageCacheSerializer())]) != nil)
    await legacy.clearDiskCache()
  }

  @Test func mergesAndCachesGeneratedImages() async throws {
    let backend = InkKingfisherImageBackend()
    let generator = Generator(delay: 20_000_000)
    let r = request(generator)
    async let first = backend.image(for: r)
    async let second = backend.image(for: r)
    _ = try await (first, second)
    #expect(await generator.count == 1)
    #expect(backend.cachedImage(for: r) != nil)
    _ = try await backend.image(for: r)
    #expect(await generator.count == 1)
    backend.clearMemoryCache()
    #expect(backend.cachedImage(for: r) == nil)
  }

  @Test func cancellationOfOneSubscriberPreservesOther() async throws {
    let backend = InkKingfisherImageBackend()
    let generator = Generator(delay: 100_000_000)
    let r = request(generator)
    let first = Task { try await backend.image(for: r) }
    let second = Task { try await backend.image(for: r) }
    try await Task.sleep(nanoseconds: 20_000_000)
    first.cancel()
    _ = try await second.value
    do { _ = try await first.value; Issue.record("Cancelled subscriber succeeded") } catch {}
    #expect(await generator.count == 1)
    #expect(backend.cachedImage(for: r) != nil)
  }

  @Test func lastSubscriberCancellationDoesNotCache() async throws {
    let backend = InkKingfisherImageBackend()
    let generator = Generator(delay: 100_000_000)
    let r = request(generator)
    let task = Task { try await backend.image(for: r) }
    try await Task.sleep(nanoseconds: 20_000_000)
    task.cancel()
    _ = await task.result
    try await Task.sleep(nanoseconds: 30_000_000)
    #expect(backend.cachedImage(for: r) == nil)
    _ = try await backend.image(for: r)
    #expect(await generator.count == 2)
  }

  @Test func boundedQueueRejectsOverflowAndDrains() async throws {
    var config = InkKingfisherImageBackend.Configuration()
    config.maxConcurrentLoads = 1
    config.maxPendingLoads = 1
    let backend = InkKingfisherImageBackend(configuration: config)
    let generator = Generator(delay: 100_000_000)
    let first = Task { try await backend.image(for: request(generator, name: "1")) }
    try await Task.sleep(nanoseconds: 10_000_000)
    let second = Task { try await backend.image(for: request(generator, name: "2")) }
    try await Task.sleep(nanoseconds: 10_000_000)
    await #expect(throws: ImageLoadError.self) {
      _ = try await backend.image(for: request(generator, name: "3"))
    }
    _ = try await first.value
    _ = try await second.value
    #expect(await generator.count == 2)
  }

  @Test func displayAndGeneratorIdentityIsolateCache() async throws {
    let backend = InkKingfisherImageBackend()
    let generator = Generator()
    _ = try await backend.image(for: request(generator, width: 64))
    #expect(backend.cachedImage(for: request(generator, width: 128)) == nil)
    _ = try await backend.image(for: request(generator, width: 128))
    #expect(await generator.count == 2)
  }

  @Test func dataURLUsesKingfisherDecodeAndCache() async throws {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50)).image { _ in }
    let data = try #require(image.pngData())
    let source = ImageSource(url: try #require(URL(string: "data:image/png;base64," + data.base64EncodedString())))
    var policy = ImageSecurityPolicy()
    policy.allowedSchemes.insert(.data)
    let r = InkImageRequest(source: source, display: DisplayContext(maxPixelWidth: 32, scale: 1), securityPolicy: policy)
    let backend = InkKingfisherImageBackend()
    let loaded = try await backend.image(for: r)
    #expect(loaded.size.width <= 32)
    #expect(backend.cachedImage(for: r) != nil)
    let denied = InkImageRequest(source: source, display: r.display)
    await #expect(throws: ImageLoadError.self) { _ = try await backend.image(for: denied) }
  }

  @Test func cancellationBeforeStartDoesNotInvokeGenerator() async {
    let backend = InkKingfisherImageBackend()
    let generator = Generator()
    let r = request(generator)
    let task = Task { try await backend.image(for: r) }
    task.cancel()
    _ = await task.result
    #expect(await generator.count == 0)
    #expect(backend.cachedImage(for: r) == nil)
  }

  @Test func cancellingQueuedRequestDoesNotGenerateIt() async throws {
    var config = InkKingfisherImageBackend.Configuration()
    config.maxConcurrentLoads = 1
    let backend = InkKingfisherImageBackend(configuration: config)
    let generator = Generator(delay: 100_000_000)
    let first = Task { try await backend.image(for: request(generator, name: "first")) }
    try await Task.sleep(nanoseconds: 20_000_000)
    let queued = Task { try await backend.image(for: request(generator, name: "queued")) }
    try await Task.sleep(nanoseconds: 20_000_000)
    queued.cancel()
    _ = await queued.result
    _ = try await first.value
    #expect(await generator.count == 1)
    #expect(backend.cachedImage(for: request(generator, name: "queued")) == nil)
  }

  @Test func memoryOnlyCacheDoesNotPersistBetweenInstances() async throws {
    let name = UUID().uuidString
    let generator = Generator()
    let first = InkKingfisherImageBackend(cacheName: name)
    _ = try await first.image(for: request(generator))
    let second = InkKingfisherImageBackend(cacheName: name)
    _ = try await second.image(for: request(generator))
    #expect(await generator.count == 2)
  }

  @Test func diskCacheRespectsDecodeBudgetNamespace() async throws {
    let name = UUID().uuidString
    var config = InkKingfisherImageBackend.Configuration()
    config.usesDiskCache = true
    config.maxPixelSize = 128
    let generator = Generator()
    let first = InkKingfisherImageBackend(configuration: config, cacheName: name)
    _ = try await first.image(for: request(generator))
    first.clearMemoryCache()
    // 同一缓存的磁盘读取排在写入之后，确认持久化完成且未再次生图。
    _ = try await first.image(for: request(generator))
    #expect(await generator.count == 1)
    config.maxPixelSize = 64
    let second = InkKingfisherImageBackend(configuration: config, cacheName: name)
    _ = try await second.image(for: request(generator))
    #expect(await generator.count == 2)
    await first.clearDiskCache()
    await second.clearDiskCache()
  }

  @Test(arguments: [1.0, 2.0, 3.0])
  func diskCachePreservesGeneratedImageGeometry(scale: Double) async throws {
    var config = InkKingfisherImageBackend.Configuration()
    config.usesDiskCache = true
    let name = UUID().uuidString
    let backend = InkKingfisherImageBackend(configuration: config, cacheName: name)
    let generator = Generator(scale: CGFloat(scale))
    let r = request(generator)
    let original = try await backend.image(for: r)
    #expect(original.scale == CGFloat(scale))
    #expect(original.size == CGSize(width: 8, height: 8))
    backend.clearMemoryCache()
    let disk = try await backend.image(for: r)
    #expect(disk.scale == original.scale)
    #expect(disk.size == original.size)
    #expect(disk.cgImage?.width == original.cgImage?.width)
    #expect(disk.cgImage?.height == original.cgImage?.height)
    // 第二个实例必须从磁盘恢复元数据，不能依赖第一个实例的内存侧表。
    let reopened = InkKingfisherImageBackend(configuration: config, cacheName: name)
    let restored = try await reopened.image(for: r)
    #expect(restored.scale == original.scale)
    #expect(restored.size == original.size)
    #expect(await generator.count == 1)
    await backend.clearDiskCache()
  }
}
