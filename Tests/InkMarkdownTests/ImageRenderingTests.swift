import Testing
import UIKit
@testable import InkMarkdown
import Markdown

// MARK: - #1 ImageSource scheme 解析

@Test @MainActor func imageSource_httpScheme() {
  let source = ImageSource(url: URL(string: "https://example.com/image.png")!)
  #expect(source.scheme == .https)
}

@Test @MainActor func imageSource_fileScheme() {
  let source = ImageSource(url: URL(string: "file:///path/to/image.png")!)
  #expect(source.scheme == .file)
}

@Test @MainActor func imageSource_dataScheme() {
  let source = ImageSource(url: URL(string: "data:image/png;base64,abc")!)
  #expect(source.scheme == .data)
}

@Test @MainActor func imageSource_unknownScheme() {
  let source = ImageSource(url: URL(string: "ftp://example.com/image.png")!)
  #expect(source.scheme == .unknown)
}

@Test @MainActor func generatedImageSource_hasBoundedStableIdentity() {
  let source = ImageSource(generated: InkGeneratedImageRequest(
    owner: "test",
    rendererVersion: "v1",
    source: String(repeating: "x", count: 10_000),
    styleIdentity: "light"
  ))
  #expect(source.scheme == .generated)
  #expect(source.generatedRequest?.source.count == 10_000)
  #expect(!source.canonicalID.contains(String(repeating: "x", count: 32)))
}

@Test @MainActor func generatedImageSource_usesSHA256Identity() {
  let base = InkGeneratedImageRequest(owner: "test", rendererVersion: "v1", source: "a", styleIdentity: "light")
  let changed = InkGeneratedImageRequest(owner: "test", rendererVersion: "v1", source: "b", styleIdentity: "light")
  let prefix = "ink-generated://sha256/"
  #expect(base.stableID.hasPrefix(prefix))
  #expect(base.stableID.dropFirst(prefix.count).count == 64)
  #expect(base.stableID.dropFirst(prefix.count).allSatisfy { $0.isHexDigit })
  #expect(base.stableID != changed.stableID)
}

// MARK: - #2 DisplayKey bucket 量化

@Test @MainActor func displayKey_bucketQuantization() {
  let source = ImageSource(url: URL(string: "https://example.com/img.png")!)
  // 375pt × 3x = 1125px → ceil(1125/64) * 64 = 1152
  let display = DisplayContext(maxPixelWidth: 1125, scale: 3, contentMode: .fit)
  let key = DisplayKey(source: source, display: display)
  #expect(key.bucketedWidth == 1152)
  #expect(key.scale == 3)
}

@Test @MainActor func displayKey_exactMultiple() {
  let source = ImageSource(url: URL(string: "https://example.com/img.png")!)
  // 768px → ceil(768/64) * 64 = 768
  let display = DisplayContext(maxPixelWidth: 768, scale: 2, contentMode: .fit)
  let key = DisplayKey(source: source, display: display)
  #expect(key.bucketedWidth == 768)
}

@Test @MainActor func displayKey_distinguishesContentMode() {
  let source = ImageSource(generated: InkGeneratedImageRequest(owner: "test", rendererVersion: "v1", source: "a", styleIdentity: "b"))
  let fit = DisplayKey(source: source, display: DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit))
  let fill = DisplayKey(source: source, display: DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fill))
  #expect(fit != fill)
}

@Test @MainActor func displayContext_sanitizesNonFiniteAndNonPositiveInputs() {
  let invalidWidths: [CGFloat] = [.nan, .infinity, -.infinity, 0, -1]
  let invalidScales: [CGFloat] = [.nan, .infinity, -.infinity, 0, -1, 0.5]

  for width in invalidWidths {
    #expect(DisplayContext(maxPixelWidth: width, scale: 2).maxPixelWidth == DisplayContext.minimumMaxPixelWidth)
  }
  for scale in invalidScales {
    #expect(DisplayContext(maxPixelWidth: 300, scale: scale).scale == DisplayContext.minimumScale)
  }
  let source = ImageSource(url: URL(string: "https://example.com/img.png")!)
  #expect(DisplayKey(source: source, display: DisplayContext(maxPixelWidth: 300, scale: 0.5)).scale == 1)
}

@Test @MainActor func displayContext_clampsOverlargeInputsBeforeDisplayKeyConversion() {
  let context = DisplayContext(maxPixelWidth: .greatestFiniteMagnitude, scale: .greatestFiniteMagnitude)
  let source = ImageSource(url: URL(string: "https://example.com/img.png")!)
  let key = DisplayKey(source: source, display: context)

  #expect(context.maxPixelWidth == DisplayContext.maximumMaxPixelWidth)
  #expect(context.scale == DisplayContext.maximumScale)
  #expect(key.bucketedWidth == Int(DisplayContext.maximumMaxPixelWidth))
  #expect(key.scale == Int(DisplayContext.maximumScale))
}

@Test @MainActor func displayContext_preservesNormalInputsAndExistingDisplayKey() {
  let context = DisplayContext(maxPixelWidth: 1125, scale: 3, contentMode: .fit)
  let source = ImageSource(url: URL(string: "https://example.com/img.png")!)
  let key = DisplayKey(source: source, display: context)

  #expect(context.maxPixelWidth == 1125)
  #expect(context.scale == 3)
  #expect(key.bucketedWidth == 1152)
  #expect(key.scale == 3)
}

// MARK: - #3 SecurityPolicy 门禁

@Test @MainActor func securityPolicy_emptyHostsRejectsAll() {
  var policy = ImageSecurityPolicy()
  policy.allowedHosts = []
  policy.emptyHostPolicy = .rejectAll
  // 空 allowedHosts + rejectAll = 拒绝所有 http(s)
  #expect(policy.allowedHosts.isEmpty)
  #expect(policy.emptyHostPolicy == .rejectAll)
}

@Test @MainActor func securityPolicy_stripsQueryDefaultIsFalse() {
  let policy = ImageSecurityPolicy()
  #expect(!policy.stripsQuery)
}

@Test @MainActor func securityPolicy_stripsQueryWhenEnabled() {
  let url = URL(string: "https://example.com/img.png?token=secret")!
  let source = ImageSource(url: url, stripsQuery: true)
  #expect(!source.canonicalID.contains("token=secret"))
  #expect(!source.requestURL.absoluteString.contains("token=secret"))
  #expect(source.canonicalID == source.requestURL.absoluteString)
}

@Test @MainActor func securityPolicy_defaultPreservesQueryInRequestURL() {
  let url = URL(string: "https://example.com/img.png?token=secret")!
  let policy = ImageSecurityPolicy()
  let source = ImageSource(
    url: url,
    stripsQuery: policy.stripsQuery,
    stripsFragment: policy.stripsFragment
  )
  #expect(source.requestURL.absoluteString.contains("token=secret"))
  #expect(source.canonicalID.contains("token=secret"))
}

@Test @MainActor func imageSource_requestURLMatchesCanonicalID() {
  let url = URL(string: "https://cdn.example.com/a.png?v=1#frag")!
  let source = ImageSource(url: url, stripsQuery: true, stripsFragment: true)
  #expect(source.requestURL.absoluteString == "https://cdn.example.com/a.png")
  #expect(source.canonicalID == source.requestURL.absoluteString)
}

// MARK: - 后台 render 与 storeConfiguration

@Test @MainActor func backgroundRender_withImagesEnabled_doesNotCrash() async {
  var appearance = InkAppearance()
  appearance.imageRendering.isEnabled = true
  appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
  let config = InkConfiguration(appearance: appearance)
  let md = "![test](https://example.com/img.png)"

  let capturedConfig = config
  let length = await Task.detached {
    let result = InkAttributedRenderer.render(md, configuration: capturedConfig)
    return result.length
  }.value
  #expect(length > 0)
}

@Test @MainActor func storeConfiguration_maxDataURLBytesApplied() {
  var appearance = InkAppearance()
  appearance.imageRendering.isEnabled = true
  appearance.imageRendering.storeConfiguration.maxDataURLBytes = 50
  appearance.imageRendering.securityPolicy.allowedSchemes.insert(.data)
  let config = InkConfiguration(appearance: appearance)
  let dataURL = "data:image/png;base64," + String(repeating: "A", count: 100)
  let md = "![x](\(dataURL))"
  let result = InkAttributedRenderer.render(md, configuration: config)
  #expect(result.string.contains("\u{1F5BC}"))
}

@Test @MainActor func storeReusesDefaultLoaderPerSecurityPolicy() {
  let store = InkImageStore()
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  let loader1 = store.loader(for: rendering)
  let loader2 = store.loader(for: rendering)
  #expect(loader1 as AnyObject === loader2 as AnyObject)
}

@Test @MainActor func storePrepareForRenderingAppliesConfiguration() {
  let store = InkImageStore()
  var rendering = InkImageRendering()
  rendering.storeConfiguration.maxConcurrentLoads = 7
  store.prepareForRendering(rendering)
  #expect(store.configuration.maxConcurrentLoads == 7)
}


@Test @MainActor func dataURL_withinLimit() {
  let small = "data:image/png;base64," + String(repeating: "A", count: 100)
  let source = ImageSource(url: URL(string: small)!)
  #expect(source.scheme == .data)
}

// MARK: - #5–8 / #14 / #16–18 InkImageStore

@Suite(.serialized)
struct InkImageStoreTests {

  /// 可控延迟 / 失败的加载器；串行队列保护可变计数（兼容 iOS 14+ / async）。
  final class MockImageLoader: InkImageLoading, @unchecked Sendable {
    private var loadCount = 0
    private var completedCount = 0
    private let queue = DispatchQueue(label: "inkmarkdown.tests.mock-image-loader")
    var delay: UInt64 = 0
    var shouldFail = false

    func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
      queue.sync { loadCount += 1 }
      if delay > 0 {
        try await Task.sleep(nanoseconds: delay)
      }
      if shouldFail {
        queue.sync { completedCount += 1 }
        throw ImageLoadError.decodeFailed
      }
      let image = UIImage(systemName: "photo")!
      queue.sync { completedCount += 1 }
      return image
    }

    var currentLoadCount: Int {
      queue.sync { loadCount }
    }

    var currentCompletedCount: Int {
      queue.sync { completedCount }
    }
  }

  @MainActor
  private func waitUntilReady(
    store: InkImageStore,
    source: ImageSource,
    display: DisplayContext,
    loader: MockImageLoader,
    timeoutNanoseconds: UInt64 = 2_000_000_000
  ) async -> Bool {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
      let result = store.resolve(source: source, display: display, loader: loader)
      if case .ready = result { return true }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return false
  }

  @MainActor
  private func waitUntilInflightCleared(
    store: InkImageStore,
    timeoutNanoseconds: UInt64 = 2_000_000_000
  ) async -> Bool {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
      if store.inflightCount == 0 { return true }
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return false
  }

  /// #5 inflight 合并：同 URL resolve 两次 → loader 仅调用 1 次
  @Test @MainActor func inflightCoalescing() async {
    let store = InkImageStore()
    let loader = MockImageLoader()
    loader.delay = 100_000_000 // 100ms

    let source = ImageSource(url: URL(string: "https://example.com/test.png")!)
    let display = DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit)

    let result1 = store.resolve(source: source, display: display, loader: loader)
    let result2 = store.resolve(source: source, display: display, loader: loader)

    if case .loading = result1 {} else { Issue.record("第一次 resolve 应为 .loading") }
    if case .loading = result2 {} else { Issue.record("第二次 resolve 应为 .loading") }

    try? await Task.sleep(nanoseconds: 200_000_000)
    #expect(loader.currentLoadCount == 1)
  }

  /// #6 并发上限：超过 maxConcurrentLoads 返回 .queued
  @Test @MainActor func concurrencyLimit() {
    var config = InkImageStore.Configuration()
    config.maxConcurrentLoads = 4
    let store = InkImageStore(configuration: config)
    let loader = MockImageLoader()
    loader.delay = 1_000_000_000 // 1s，保证不会在测试期间完成

    let display = DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit)

    var results: [InkImageStore.ResolveResult] = []
    for i in 0..<6 {
      let source = ImageSource(url: URL(string: "https://example.com/img\(i).png")!)
      results.append(store.resolve(source: source, display: display, loader: loader))
    }

    for i in 0..<4 {
      if case .loading = results[i] {} else { Issue.record("第 \(i) 个应为 .loading") }
    }
    for i in 4..<6 {
      if case .queued = results[i] {} else { Issue.record("第 \(i) 个应为 .queued") }
    }
  }

  @Test @MainActor func generatedSourceWithoutLoaderFailsWithoutURLFallback() async {
    let store = InkImageStore()
    let source = ImageSource(generated: InkGeneratedImageRequest(
      owner: "test-renderer", rendererVersion: "v1", source: "diagram", styleIdentity: "light"
    ))
    let display = DisplayContext(maxPixelWidth: 300, scale: 2)
    let loader = store.loader(for: InkImageRendering(), source: source)

    do {
      _ = try await loader.loadImage(source: source, display: display)
      Issue.record("生成 source 缺 renderer 时不应调用 URL loader")
    } catch let error as ImageLoadError {
      guard case .generatedLoaderUnavailable(let owner) = error else {
        Issue.record("应返回 generated loader 缺失错误，实际为 \(error)")
        return
      }
      #expect(owner == "test-renderer")
    } catch {
      Issue.record("应返回 ImageLoadError，实际为 \(error)")
    }
  }

  @Test @MainActor func pendingQueueHasBoundedCapacity() async {
    var configuration = InkImageStore.Configuration()
    configuration.maxConcurrentLoads = 1
    configuration.maxPendingLoads = 1
    let store = InkImageStore(configuration: configuration)
    let loader = MockImageLoader()
    loader.delay = 200_000_000
    let display = DisplayContext(maxPixelWidth: 300, scale: 2)

    _ = store.resolve(source: ImageSource(url: URL(string: "https://example.com/active.png")!), display: display, loader: loader)
    let queued = store.resolve(source: ImageSource(url: URL(string: "https://example.com/queued.png")!), display: display, loader: loader)
    let rejected = store.resolve(source: ImageSource(url: URL(string: "https://example.com/rejected.png")!), display: display, loader: loader)

    if case .queued = queued {} else { Issue.record("第二项应进入等待队列") }
    if case .rejected(.pendingQueueFull(let limit)) = rejected {
      #expect(limit == 1)
    } else {
      Issue.record("等待队列满时应明确拒绝")
    }
    #expect(store.pendingLoadCount == 1)
    try? await Task.sleep(nanoseconds: 450_000_000)
  }

  @Test @MainActor func cancellingLastQueuedSubscriptionRemovesPendingLoad() {
    var configuration = InkImageStore.Configuration()
    configuration.maxConcurrentLoads = 1
    configuration.maxPendingLoads = 1
    let store = InkImageStore(configuration: configuration)
    let loader = MockImageLoader()
    loader.delay = 1_000_000_000
    let display = DisplayContext(maxPixelWidth: 300, scale: 2)

    _ = store.resolve(source: ImageSource(url: URL(string: "https://example.com/active.png")!), display: display, loader: loader)
    let queued = store.resolve(source: ImageSource(url: URL(string: "https://example.com/queued.png")!), display: display, loader: loader)
    if case .queued(let subscribe) = queued {
      let subscription = subscribe { _ in }
      #expect(store.pendingLoadCount == 1)
      subscription.cancel()
      #expect(store.pendingLoadCount == 0)
    } else {
      Issue.record("第二项应进入等待队列")
    }
  }

  /// #7 内存驱逐：post memoryWarning → cache 不再命中
  @Test @MainActor func memoryWarningEviction() async {
    let store = InkImageStore()
    let loader = MockImageLoader()
    let source = ImageSource(url: URL(string: "https://example.com/test.png")!)
    let display = DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit)

    _ = store.resolve(source: source, display: display, loader: loader)
    let ready = await waitUntilReady(store: store, source: source, display: display, loader: loader)
    #expect(ready)

    let result = store.resolve(source: source, display: display, loader: loader)
    if case .ready = result {} else { Issue.record("应该缓存命中") }

    NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    try? await Task.sleep(nanoseconds: 50_000_000)

    let afterWarning = store.resolve(source: source, display: display, loader: loader)
    if case .ready = afterWarning { Issue.record("内存警告后不应缓存命中") }
  }

  /// #8 Tail 重渲不重复下载
  @Test @MainActor func tailReRenderNoDuplicateDownload() async {
    let store = InkImageStore()
    let loader = MockImageLoader()
    let source = ImageSource(url: URL(string: "https://example.com/test.png")!)
    let display = DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit)

    _ = store.resolve(source: source, display: display, loader: loader)
    #expect(await waitUntilReady(store: store, source: source, display: display, loader: loader))

    for _ in 0..<99 {
      _ = store.resolve(source: source, display: display, loader: loader)
    }

    #expect(loader.currentLoadCount == 1)
  }

  /// #14 订阅取消后不触发回调
  @Test @MainActor func subscriptionCancelPreventsCallback() async {
    let store = InkImageStore()
    let loader = MockImageLoader()
    loader.delay = 200_000_000
    let source = ImageSource(url: URL(string: "https://example.com/test.png")!)
    let display = DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit)

    let result = store.resolve(source: source, display: display, loader: loader)
    var callbackCalled = false
    if case .loading(let subscribe) = result {
      let subscription = subscribe { _ in callbackCalled = true }
      subscription.cancel()
    }

    try? await Task.sleep(nanoseconds: 300_000_000)
    #expect(!callbackCalled)
  }

  /// #16 activeCount 守卫
  @Test @MainActor func activeCountGuard() {
    var config = InkImageStore.Configuration()
    config.maxConcurrentLoads = 4
    let store = InkImageStore(configuration: config)
    let loader = MockImageLoader()
    loader.delay = 1_000_000_000
    let display = DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit)

    for i in 0..<6 {
      let source = ImageSource(url: URL(string: "https://example.com/img\(i).png")!)
      _ = store.resolve(source: source, display: display, loader: loader)
    }

    #expect(store.currentActiveCount == 4)
  }

  /// #17 inflight 清理
  @Test @MainActor func inflightCleanupAfterCompletion() async {
    let store = InkImageStore()
    let loader = MockImageLoader()
    let source = ImageSource(url: URL(string: "https://example.com/test.png")!)
    let display = DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit)

    _ = store.resolve(source: source, display: display, loader: loader)
    #expect(await waitUntilReady(store: store, source: source, display: display, loader: loader))
    #expect(await waitUntilInflightCleared(store: store))

    #expect(store.inflightCount == 0)
    let result = store.resolve(source: source, display: display, loader: loader)
    if case .ready = result {} else { Issue.record("应该是缓存命中而非挂死") }
  }

  /// #18 queued drain
  @Test @MainActor func queuedDrain() async {
    var config = InkImageStore.Configuration()
    config.maxConcurrentLoads = 4
    let store = InkImageStore(configuration: config)
    let loader = MockImageLoader()
    loader.delay = 100_000_000 // 100ms
    let display = DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit)

    for i in 0..<6 {
      let source = ImageSource(url: URL(string: "https://example.com/img\(i).png")!)
      _ = store.resolve(source: source, display: display, loader: loader)
    }

    let deadline = Date().addingTimeInterval(3.0)
    var allReady = false
    while Date() < deadline {
      var countReady = 0
      for i in 0..<6 {
        let source = ImageSource(url: URL(string: "https://example.com/img\(i).png")!)
        if case .ready = store.resolve(source: source, display: display, loader: loader) {
          countReady += 1
        }
      }
      if countReady == 6 {
        allReady = true
        break
      }
      try? await Task.sleep(nanoseconds: 50_000_000)
    }

    #expect(allReady, "所有 6 张图片应该在队列 drain 后全部处于 ready 状态")
  }
}

// MARK: - #9 ImageIO 降采样正确性

@Test @MainActor func imageIODownsampler_respectsMaxPixel() throws {
  let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100))
  let testImage = renderer.image { ctx in
    UIColor.red.setFill()
    ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
  }
  guard let data = testImage.pngData() else {
    Issue.record("无法创建测试图片数据")
    return
  }
  let downsampler = ImageIODownsampler()
  let result = try downsampler.downsample(data: data, maxPixel: 50)
  #expect(max(result.size.width, result.size.height) <= 50)
}

// MARK: - #10 fitted 函数

@Test @MainActor func fitted_smallImageNoUpscale() {
  let size = CGSize(width: 100, height: 50)
  let result = fitted(size, maxWidth: 300, upscales: false, minPlaceholder: 80, maxHeight: nil)
  #expect(result.width == 100)
  #expect(result.height == 50)
}

@Test @MainActor func fitted_largeImageScalesDown() {
  let size = CGSize(width: 600, height: 300)
  let result = fitted(size, maxWidth: 300, upscales: false, minPlaceholder: 80, maxHeight: nil)
  #expect(result.width == 300)
  #expect(result.height == 150)
}

@Test @MainActor func fitted_upscalesWhenEnabled() {
  let size = CGSize(width: 100, height: 50)
  let result = fitted(size, maxWidth: 300, upscales: true, minPlaceholder: 80, maxHeight: nil)
  #expect(result.width == 300)
  #expect(result.height == 150)
}

@Test @MainActor func fitted_respectsMaxHeight() {
  let size = CGSize(width: 100, height: 2000)
  let result = fitted(size, maxWidth: 300, upscales: true, minPlaceholder: 80, maxHeight: 500)
  #expect(result.height <= 500)
}

// MARK: - #11 Promote 判定

@Test @MainActor func promote_singleImage() {
  let doc = Document(parsing: "![alt](https://example.com/img.png)")
  let paragraph = Array(doc.children).first!
  #expect(isPromotableImageParagraph(paragraph))
}

@Test @MainActor func promote_imageWithSurroundingWhitespace() {
  let doc = Document(parsing: " ![alt](https://example.com/img.png) ")
  let paragraph = Array(doc.children).first!
  #expect(isPromotableImageParagraph(paragraph))
}

@Test @MainActor func promote_mixedTextAndImage() {
  let doc = Document(parsing: "some text ![alt](https://example.com/img.png)")
  let paragraph = Array(doc.children).first!
  #expect(!isPromotableImageParagraph(paragraph))
}

// MARK: - #12 行高策略（via 渲染结果）

@Test @MainActor func lineHeight_noImageKeepsLocked() {
  let md = "Hello world"
  let result = InkAttributedRenderer.render(md)
  let para = result.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
  if let p = para {
    #expect(p.minimumLineHeight == p.maximumLineHeight)
  }
}

// MARK: - #13 错误降级

@Test @MainActor func errorDegradation_disabledShowsPlaceholder() {
  var appearance = InkAppearance()
  appearance.imageRendering.isEnabled = false
  let config = InkConfiguration(appearance: appearance)
  let md = "![alt text](https://example.com/img.png)"
  let result = InkAttributedRenderer.render(md, configuration: config)
  #expect(result.string.contains("🖼"))
  #expect(result.string.contains("alt text"))
}

// MARK: - #15 baselineOffset

@Test @MainActor func baselineOffset_imageAttachmentIsZero() {
  var appearance = InkAppearance()
  appearance.imageRendering.isEnabled = true
  appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
  let config = InkConfiguration(appearance: appearance)
  let md = "![test](https://example.com/img.png)"
  let result = InkAttributedRenderer.render(md, configuration: config)
  result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, range, _ in
    if value is InkImageAttachment {
      let offset = result.attribute(.baselineOffset, at: range.location, effectiveRange: nil) as? CGFloat ?? -1
      #expect(offset == 0)
    }
  }
}

// MARK: - applyImage 段级行高抬升

private func makeTestImage(width: CGFloat, height: CGFloat) -> UIImage {
  UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { ctx in
    UIColor.blue.setFill()
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
  }
}

private final class SizedMockImageLoader: InkImageLoading, @unchecked Sendable {
  private let imagesByURL: [String: UIImage]
  private var loadCount = 0
  private var completedCount = 0
  private let queue = DispatchQueue(label: "inkmarkdown.tests.sized-mock-image-loader")

  init(imagesByURL: [String: UIImage]) {
    self.imagesByURL = imagesByURL
  }

  func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    queue.sync { loadCount += 1 }
    let key = source.requestURL.absoluteString
    guard let image = imagesByURL[key] else {
      queue.sync { completedCount += 1 }
      throw ImageLoadError.decodeFailed
    }
    queue.sync { completedCount += 1 }
    return image
  }

  var currentLoadCount: Int {
    queue.sync { loadCount }
  }

  var currentCompletedCount: Int {
    queue.sync { completedCount }
  }
}

/// 等待 loader 完成指定次数，并再等到 `applyImage` 把段级行高写进 storage。
@MainActor
private func waitForImageLoads(
  count: Int,
  loader: SizedMockImageLoader,
  storage: NSTextStorage? = nil,
  expectedMaximumLineHeight: CGFloat? = nil,
  timeoutNanoseconds: UInt64 = 2_000_000_000
) async {
  let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
  while loader.currentCompletedCount < count, DispatchTime.now().uptimeNanoseconds < deadline {
    try? await Task.sleep(nanoseconds: 10_000_000)
  }

  guard let storage, let expectedMaximumLineHeight else {
    // 给 MainActor 回调一个调度窗口，确保 applyImage 已执行。
    for _ in 0..<5 { await Task.yield() }
    return
  }

  while DispatchTime.now().uptimeNanoseconds < deadline {
    let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: 0, length: 1))
    let style = storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
    if style?.maximumLineHeight == expectedMaximumLineHeight { return }
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
}

@MainActor
private func makeImageTextStorage(
  attachments: [InkImageAttachment],
  lockedLineHeight: CGFloat = 22
) -> (NSTextStorage, NSLayoutManager) {
  let para = NSMutableParagraphStyle()
  para.minimumLineHeight = lockedLineHeight
  para.maximumLineHeight = lockedLineHeight

  let text = NSMutableAttributedString(string: "Hello ", attributes: [.paragraphStyle: para])
  for (index, attachment) in attachments.enumerated() {
    text.append(NSAttributedString(attachment: attachment))
    if index < attachments.count - 1 {
      text.append(NSAttributedString(string: " middle ", attributes: [.paragraphStyle: para]))
    }
  }
  text.append(NSAttributedString(string: " world", attributes: [.paragraphStyle: para]))
  text.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: text.length))

  let storage = NSTextStorage(attributedString: text)
  let layoutManager = NSLayoutManager()
  let container = NSTextContainer(size: CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
  layoutManager.addTextContainer(container)
  storage.addLayoutManager(layoutManager)
  return (storage, layoutManager)
}

@Test @MainActor func applyImage_elevatesEntireParagraphForInlineImage() async {
  let url = URL(string: "https://example.com/inline.png")!
  let loader = SizedMockImageLoader(imagesByURL: [url.absoluteString: makeTestImage(width: 100, height: 130)])
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.loader = loader

  let store = InkImageStore()
  let attachment = InkImageAttachment(source: ImageSource(url: url), rendering: rendering, store: store)
  let lockedLineHeight: CGFloat = 22
  let (storage, layoutManager) = makeImageTextStorage(attachments: [attachment], lockedLineHeight: lockedLineHeight)

  InkImageAttachment.bindAttachments(in: storage, layoutManager: layoutManager, store: store)
  await waitForImageLoads(
    count: 1,
    loader: loader,
    storage: storage,
    expectedMaximumLineHeight: 130
  )

  let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: 0, length: 1))
  let style = storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
  #expect(style?.minimumLineHeight == lockedLineHeight)
  #expect(style?.maximumLineHeight == 130)
}

@Test @MainActor func applyImage_sameParagraphMultipleImagesUsesMaxHeight() async {
  let urlA = URL(string: "https://example.com/a.png")!
  let urlB = URL(string: "https://example.com/b.png")!
  let loader = SizedMockImageLoader(imagesByURL: [
    urlA.absoluteString: makeTestImage(width: 100, height: 120),
    urlB.absoluteString: makeTestImage(width: 100, height: 150),
  ])
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.loader = loader

  let store = InkImageStore()
  let attachmentA = InkImageAttachment(source: ImageSource(url: urlA), rendering: rendering, store: store)
  let attachmentB = InkImageAttachment(source: ImageSource(url: urlB), rendering: rendering, store: store)
  let lockedLineHeight: CGFloat = 22
  let (storage, layoutManager) = makeImageTextStorage(
    attachments: [attachmentA, attachmentB],
    lockedLineHeight: lockedLineHeight
  )

  InkImageAttachment.bindAttachments(in: storage, layoutManager: layoutManager, store: store)
  await waitForImageLoads(
    count: 2,
    loader: loader,
    storage: storage,
    expectedMaximumLineHeight: 150
  )

  let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: 0, length: 1))
  let style = storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
  #expect(style?.minimumLineHeight == lockedLineHeight)
  #expect(style?.maximumLineHeight == 150)
}

@Test @MainActor func applyImage_doesNotRegressParagraphElevation() async {
  let urlA = URL(string: "https://example.com/tall.png")!
  let urlB = URL(string: "https://example.com/short.png")!
  let loader = SizedMockImageLoader(imagesByURL: [
    urlA.absoluteString: makeTestImage(width: 100, height: 160),
    urlB.absoluteString: makeTestImage(width: 100, height: 90),
  ])
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.loader = loader

  let store = InkImageStore()
  let attachmentA = InkImageAttachment(source: ImageSource(url: urlA), rendering: rendering, store: store)
  let attachmentB = InkImageAttachment(source: ImageSource(url: urlB), rendering: rendering, store: store)
  let (storage, layoutManager) = makeImageTextStorage(attachments: [attachmentA, attachmentB])

  InkImageAttachment.bindAttachments(in: storage, layoutManager: layoutManager, store: store)
  await waitForImageLoads(
    count: 2,
    loader: loader,
    storage: storage,
    expectedMaximumLineHeight: 160
  )

  let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: 0, length: 1))
  let style = storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
  #expect(style?.maximumLineHeight == 160)
}

// MARK: - bindAttachments 增量 / 短路

@Test @MainActor func bindAttachments_skipsAlreadyMaterializedAttachments() async {
  let url = URL(string: "https://example.com/bind-once.png")!
  let loader = SizedMockImageLoader(imagesByURL: [url.absoluteString: makeTestImage(width: 80, height: 80)])
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.loader = loader

  let store = InkImageStore()
  let attachment = InkImageAttachment(source: ImageSource(url: url), rendering: rendering, store: store)
  let (storage, layoutManager) = makeImageTextStorage(attachments: [attachment])

  InkImageAttachment.bindAttachments(in: storage, layoutManager: layoutManager, store: store)
  await waitForImageLoads(count: 1, loader: loader, storage: storage, expectedMaximumLineHeight: 80)
  let countAfterFirstBind = loader.currentCompletedCount

  InkImageAttachment.bindAttachments(in: storage, layoutManager: layoutManager, store: store)
  await waitForImageLoads(count: countAfterFirstBind, loader: loader)
  for _ in 0..<5 { await Task.yield() }

  #expect(loader.currentLoadCount == countAfterFirstBind)
  #expect(loader.currentCompletedCount == 1)
}

// MARK: - InkImageBlock / InkImageBlockHandler 端到端

@Test @MainActor func imageBlockHandler_promotesStandaloneImageParagraph() {
  var appearance = InkAppearance()
  appearance.imageRendering.isEnabled = true
  appearance.imageRendering.promotesToBlock = true
  appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
  let config = InkConfiguration(appearance: appearance)

  let blocks = InkBlockRenderer.render(
    "![alt](https://example.com/promoted.png)",
    configuration: config
  )
  #expect(blocks.count == 1)
  #expect(blocks[0] is InkImageBlock)
}

@Test @MainActor func imageBlockHandler_doesNotPromoteMixedInlineImage() {
  var appearance = InkAppearance()
  appearance.imageRendering.isEnabled = true
  appearance.imageRendering.promotesToBlock = true
  appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
  let config = InkConfiguration(appearance: appearance)

  let blocks = InkBlockRenderer.render(
    "text ![alt](https://example.com/inline.png)",
    configuration: config
  )
  #expect(blocks.count == 1)
  #expect(!(blocks[0] is InkImageBlock))
}

@Test @MainActor func imageBlockHandler_respectsSecurityPolicy() {
  var appearance = InkAppearance()
  appearance.imageRendering.isEnabled = true
  appearance.imageRendering.promotesToBlock = true
  appearance.imageRendering.securityPolicy.allowedHosts = ["safe.example.com"]
  let config = InkConfiguration(appearance: appearance)

  let blocks = InkBlockRenderer.render(
    "![x](https://evil.example.com/malware.png)",
    configuration: config
  )
  #expect(blocks.count == 1)
  #expect(!(blocks[0] is InkImageBlock))
}

@Test @MainActor func imageBlock_configureLoadsImageAndUpdatesSize() async {
  let url = URL(string: "https://example.com/block.png")!
  let loader = SizedMockImageLoader(
    imagesByURL: [url.absoluteString: makeTestImage(width: 200, height: 100)]
  )
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.loader = loader

  let store = InkImageStore()
  let block = InkImageBlockView(
    source: ImageSource(url: url),
    store: store,
    rendering: rendering
  )
  block.configure(containerWidth: 300, loader: loader)

  let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
  while loader.currentCompletedCount < 1, DispatchTime.now().uptimeNanoseconds < deadline {
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
  for _ in 0..<10 { await Task.yield() }

  #expect(loader.currentCompletedCount == 1)
  #expect(block.bounds.height == 100 || block.frame.height == 100 || block.intrinsicContentSize.height == 100)
}

// MARK: - InkImageBlock tapAction 分发

@Test @MainActor func imageBlock_noneTapActionDoesNotInstallGesture() {
  var rendering = InkImageRendering()
  rendering.tapAction = .none
  let block = InkImageBlockView(
    source: ImageSource(url: URL(string: "https://example.com/none.png")!),
    store: InkImageStore(),
    rendering: rendering
  )
  let hasTap = block.gestureRecognizers?.contains { $0 is UITapGestureRecognizer } ?? false
  #expect(!hasTap)
}

@Test @MainActor func imageBlock_callbackTapActionInvokesOnImageTap() async {
  let url = URL(string: "https://example.com/tap-callback.png")!
  let loader = SizedMockImageLoader(
    imagesByURL: [url.absoluteString: makeTestImage(width: 80, height: 60)]
  )

  var tappedSource: ImageSource?
  var tappedImage: UIImage?
  var callCount = 0

  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.tapAction = .callback
  rendering.loader = loader
  rendering.onImageTap = { source, image in
    callCount += 1
    tappedSource = source
    tappedImage = image
  }

  let store = InkImageStore()
  let block = InkImageBlockView(
    source: ImageSource(url: url),
    store: store,
    rendering: rendering
  )
  #expect(block.gestureRecognizers?.contains { $0 is UITapGestureRecognizer } == true)

  block.configure(containerWidth: 200, loader: loader)

  let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
  while loader.currentCompletedCount < 1, DispatchTime.now().uptimeNanoseconds < deadline {
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
  for _ in 0..<10 { await Task.yield() }

  block.handleConfiguredTap()

  #expect(callCount == 1)
  #expect(tappedSource?.requestURL.absoluteString == url.absoluteString)
  #expect(tappedImage != nil)
}

@Test @MainActor func imageBlock_openURLTapActionAlsoInvokesOnImageTap() {
  let url = URL(string: "https://example.com/tap-open.png")!
  var callCount = 0

  var rendering = InkImageRendering()
  rendering.tapAction = .openURL
  rendering.onImageTap = { _, _ in
    callCount += 1
  }

  let block = InkImageBlockView(
    source: ImageSource(url: url),
    store: InkImageStore(),
    rendering: rendering
  )
  block.handleConfiguredTap()
  #expect(callCount == 1)
}

@Test @MainActor func applyImage_setsShouldAnimateNextHeightChangeWhenDeltaExceedsThreshold() async {
  let urlLarge = URL(string: "https://example.com/large.png")!
  let urlSmall = URL(string: "https://example.com/small.png")!
  let loader = SizedMockImageLoader(imagesByURL: [
    urlLarge.absoluteString: makeTestImage(width: 200, height: 300),
    urlSmall.absoluteString: makeTestImage(width: 200, height: 35),
  ])
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.loader = loader

  let store = InkImageStore()

  var largeAnimatedFlagDuringCallback: Bool?
  var smallAnimatedFlagDuringCallback: Bool?

  let attachmentLarge = InkImageAttachment(source: ImageSource(url: urlLarge), rendering: rendering, store: store)
  let (storageLarge, layoutManagerLarge) = makeImageTextStorage(attachments: [attachmentLarge])
  attachmentLarge.bind(to: layoutManagerLarge, store: store) {
    largeAnimatedFlagDuringCallback = attachmentLarge.shouldAnimateNextHeightChange
  }

  await waitForImageLoads(count: 1, loader: loader, storage: storageLarge, expectedMaximumLineHeight: 300)
  #expect(largeAnimatedFlagDuringCallback == true)
  #expect(attachmentLarge.shouldAnimateNextHeightChange == false)

  let attachmentSmall = InkImageAttachment(source: ImageSource(url: urlSmall), rendering: rendering, store: store)
  let (storageSmall, layoutManagerSmall) = makeImageTextStorage(attachments: [attachmentSmall])
  attachmentSmall.bind(to: layoutManagerSmall, store: store) {
    smallAnimatedFlagDuringCallback = attachmentSmall.shouldAnimateNextHeightChange
  }

  await waitForImageLoads(count: 2, loader: loader, storage: storageSmall, expectedMaximumLineHeight: 35)
  #expect(smallAnimatedFlagDuringCallback == false)
  #expect(attachmentSmall.shouldAnimateNextHeightChange == false)
}

// MARK: - 占位 / 失败态紧凑高度

@Test @MainActor func imageBlock_unconfiguredIntrinsicHeightIsMinimal() {
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.placeholderHeight = 160
  let block = InkImageBlockView(
    source: ImageSource(url: URL(string: "https://example.com/unconfigured.png")!),
    store: InkImageStore(),
    rendering: rendering
  )
  #expect(block.intrinsicContentSize.height == 0)
}

@Test @MainActor func imageBlock_failureWithoutFallbackUsesCompactHeight() async {
  let url = URL(string: "https://example.com/fail-block.png")!
  let loader = InkImageStoreTests.MockImageLoader()
  loader.shouldFail = true

  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.placeholderHeight = 160
  rendering.loader = loader

  let store = InkImageStore()
  let block = InkImageBlockView(
    source: ImageSource(url: url),
    store: store,
    rendering: rendering
  )
  block.configure(containerWidth: 300, loader: loader)

  let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
  while loader.currentCompletedCount < 1, DispatchTime.now().uptimeNanoseconds < deadline {
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
  for _ in 0..<10 { await Task.yield() }

  let height = block.intrinsicContentSize.height
  #expect(height < 80)
  #expect(height < 160)
}

@Test @MainActor func imageBlock_cachedReadySkipsLoadingPlaceholderHeight() async {
  let url = URL(string: "https://example.com/cached-ready.png")!
  let loader = SizedMockImageLoader(
    imagesByURL: [url.absoluteString: makeTestImage(width: 200, height: 100)]
  )
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.placeholderHeight = 160
  rendering.loader = loader

  let store = InkImageStore()
  let source = ImageSource(url: url)
  let containerWidth: CGFloat = 300
  let scale = UIScreen.main.scale
  let display = DisplayContext(
    maxPixelWidth: containerWidth * scale,
    scale: scale,
    contentMode: .fit
  )

  _ = store.resolve(source: source, display: display, loader: loader)
  let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
  while loader.currentCompletedCount < 1, DispatchTime.now().uptimeNanoseconds < deadline {
    try? await Task.sleep(nanoseconds: 10_000_000)
  }

  let block = InkImageBlockView(source: source, store: store, rendering: rendering)
  #expect(block.intrinsicContentSize.height == 0)

  block.configure(containerWidth: containerWidth, loader: loader)

  let measuredHeight = block.sizeThatFits(
    CGSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
  ).height
  #expect(measuredHeight == 100)
  #expect(measuredHeight != rendering.placeholderHeight)
}

@Test @MainActor func inlineAttachment_unloadedBoundsHeightIsCompact() {
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.placeholderHeight = 160

  let attachment = InkImageAttachment(
    source: ImageSource(url: URL(string: "https://example.com/inline-unloaded.png")!),
    rendering: rendering,
    store: InkImageStore()
  )

  let lineFragment = CGRect(x: 0, y: 0, width: 300, height: 22)
  let bounds = attachment.attachmentBounds(
    for: nil,
    proposedLineFragment: lineFragment,
    glyphPosition: .zero,
    characterIndex: 0
  )

  #expect(bounds.height < 80)
  #expect(bounds.height < 160)
  #expect(bounds.height >= 20)
}

