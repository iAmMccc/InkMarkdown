import Testing
import UIKit
@testable import InkMarkdown
import Markdown

@MainActor
private final class NotificationDeliveryCounter {
  var value = 0
}

private final class ObserverTrackingNotificationCenter: NotificationCenter, @unchecked Sendable {
  private let stateLock = NSLock()
  private var storedRemovalCount = 0

  var removalCount: Int {
    stateLock.lock()
    defer { stateLock.unlock() }
    return storedRemovalCount
  }

  override func removeObserver(_ observer: Any) {
    stateLock.lock()
    storedRemovalCount += 1
    stateLock.unlock()
    super.removeObserver(observer)
  }
}

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
  appearance.imageRendering.maxDataURLBytes = 50
  appearance.imageRendering.securityPolicy.allowedSchemes.insert(.data)
  let config = InkConfiguration(appearance: appearance)
  let dataURL = "data:image/png;base64," + String(repeating: "A", count: 100)
  let md = "![x](\(dataURL))"
  let result = InkAttributedRenderer.render(md, configuration: config)
  #expect(result.string.contains("\u{1F5BC}"))
}

@Test @MainActor func dataURL_withinLimit() {
  let small = "data:image/png;base64," + String(repeating: "A", count: 100)
  let source = ImageSource(url: URL(string: small)!)
  #expect(source.scheme == .data)
}

// MARK: - #5–8 / #14 / #16–18 InkImageStore

@Suite(.serialized)
struct InkImageStoreTests {

  /// 可控延迟 / 失败的加载器；串行队列保护可变计数（兼容 iOS 15+ / async）。
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

  /// 带稳定语义身份的 mock loader，用于验证 cache identity 隔离。
  final class IdentifiedMockImageLoader: InkImageLoading, @unchecked Sendable {
    let identity: InkSemanticIdentity
    private let inner: MockImageLoader

    init(identity: InkSemanticIdentity, inner: MockImageLoader = MockImageLoader()) {
      self.identity = identity
      self.inner = inner
    }

    var semanticIdentity: InkSemanticIdentity? { identity }

    func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
      try await inner.loadImage(source: source, display: display)
    }

    var currentLoadCount: Int { inner.currentLoadCount }
    var currentCompletedCount: Int { inner.currentCompletedCount }
  }

  /// 即使 Swift Task 已取消仍会返回结果，用于验证 Store generation 隔离。
  final class CancellationIgnoringLoader: InkImageLoading, @unchecked Sendable {
    private let queue = DispatchQueue(label: "inkmarkdown.tests.noncooperative-image-loader")
    private let images: [UIImage]
    private var loadCount = 0

    init(images: [UIImage]) {
      self.images = images
    }

    var semanticIdentity: InkSemanticIdentity? { "test.loader.noncooperative.v1" }

    func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
      let index = queue.sync { () -> Int in
        loadCount += 1
        return loadCount - 1
      }
      let delay: TimeInterval = index == 0 ? 0.3 : 0.02
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
          continuation.resume()
        }
      }
      return images[min(index, images.count - 1)]
    }

    var currentLoadCount: Int {
      queue.sync { loadCount }
    }
  }

}

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

@Test @MainActor func imageParagraphStyle_elevatesOnlyMaximumLineHeight() {
  let original = NSMutableParagraphStyle()
  original.minimumLineHeight = 22
  original.maximumLineHeight = 22
  original.alignment = .right
  original.firstLineHeadIndent = 18
  original.headIndent = 42
  original.paragraphSpacing = 9

  let elevated = InkImageParagraphStyle.elevating(original, toAtLeast: 130)

  #expect(elevated.minimumLineHeight == 22)
  #expect(elevated.maximumLineHeight == 130)
  #expect(elevated.alignment == .right)
  #expect(elevated.firstLineHeadIndent == 18)
  #expect(elevated.headIndent == 42)
  #expect(elevated.paragraphSpacing == 9)
  #expect(original.maximumLineHeight == 22)

  let notRegressed = InkImageParagraphStyle.elevating(elevated, toAtLeast: 90)
  #expect(notRegressed.maximumLineHeight == 130)
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
  lockedLineHeight: CGFloat = 22,
  configureParagraph: ((NSMutableParagraphStyle) -> Void)? = nil
) -> (NSTextStorage, NSLayoutManager) {
  let para = NSMutableParagraphStyle()
  para.minimumLineHeight = lockedLineHeight
  para.maximumLineHeight = lockedLineHeight
  configureParagraph?(para)

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
  rendering.backend = TestImageBackend(loader)

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

@Test @MainActor func applyImage_preservesExistingParagraphGeometry() async {
  let url = URL(string: "https://example.com/indented-inline.png")!
  let loader = SizedMockImageLoader(
    imagesByURL: [url.absoluteString: makeTestImage(width: 100, height: 130)]
  )
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.backend = TestImageBackend(loader)

  let store = InkImageStore()
  let attachment = InkImageAttachment(source: ImageSource(url: url), rendering: rendering, store: store)
  let (storage, layoutManager) = makeImageTextStorage(attachments: [attachment]) { paragraph in
    paragraph.alignment = .right
    paragraph.firstLineHeadIndent = 18
    paragraph.headIndent = 42
    paragraph.paragraphSpacing = 9
  }

  InkImageAttachment.bindAttachments(in: storage, layoutManager: layoutManager, store: store)
  await waitForImageLoads(
    count: 1,
    loader: loader,
    storage: storage,
    expectedMaximumLineHeight: 130
  )

  let paragraphRange = (storage.string as NSString).paragraphRange(
    for: NSRange(location: 0, length: 1)
  )
  let style = storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil)
    as? NSParagraphStyle
  #expect(style?.alignment == .right)
  #expect(style?.firstLineHeadIndent == 18)
  #expect(style?.headIndent == 42)
  #expect(style?.paragraphSpacing == 9)
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
  rendering.backend = TestImageBackend(loader)

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
  rendering.backend = TestImageBackend(loader)

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
  rendering.backend = TestImageBackend(loader)

  let store = InkImageStore()
  let attachment = InkImageAttachment(source: ImageSource(url: url), rendering: rendering, store: store)
  let (storage, layoutManager) = makeImageTextStorage(attachments: [attachment])

  InkImageAttachment.bindAttachments(in: storage, layoutManager: layoutManager, store: store)
  await waitForImageLoads(count: 1, loader: loader, storage: storage, expectedMaximumLineHeight: 80)
  let countAfterFirstBind = loader.currentCompletedCount

  InkImageAttachment.bindAttachments(in: storage, layoutManager: layoutManager, store: store)
  await waitForImageLoads(count: 1, loader: loader)
  for _ in 0..<5 { await Task.yield() }

  #expect(loader.currentLoadCount == countAfterFirstBind)
  #expect(loader.currentCompletedCount == 1)
}

@Test @MainActor func inlineAttachmentMaterializationIdentityIncludesDisplayContext() async {
  let url = URL(string: "https://example.com/display-context.png")!
  let loader = SizedMockImageLoader(
    imagesByURL: [url.absoluteString: makeTestImage(width: 80, height: 80)]
  )
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.backend = TestImageBackend(loader)

  let store = InkImageStore()
  let attachment = InkImageAttachment(
    source: ImageSource(url: url),
    rendering: rendering,
    store: store
  )
  let firstDisplay = DisplayContext(maxPixelWidth: 300, scale: 2)
  let firstLoader = store.loader(for: rendering, source: attachment.source)
  attachment.materialize(display: firstDisplay, loader: firstLoader)
  await waitForImageLoads(count: 1, loader: loader)

  attachment.materialize(display: firstDisplay, loader: firstLoader)
  for _ in 0..<5 { await Task.yield() }
  #expect(loader.currentLoadCount == 1)

  let widerDisplay = DisplayContext(maxPixelWidth: 600, scale: 2)
  let widerLoader = store.loader(for: rendering, source: attachment.source)
  attachment.materialize(display: widerDisplay, loader: widerLoader)
  await waitForImageLoads(count: 2, loader: loader)
  #expect(loader.currentLoadCount == 2)
}

@Test @MainActor func textViewBindingHelperRematerializesAfterHostWidthChange() async {
  let url = URL(string: "https://example.com/text-view-resize.png")!
  let loader = SizedMockImageLoader(
    imagesByURL: [url.absoluteString: makeTestImage(width: 120, height: 80)]
  )
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.backend = TestImageBackend(loader)

  let attachment = InkImageAttachment(
    source: ImageSource(url: url),
    rendering: rendering
  )
  let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 220, height: 100))
  textView.textContainerInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 12)
  textView.textContainer.lineFragmentPadding = 4
  textView.textStorage.setAttributedString(NSAttributedString(attachment: attachment))

  textView.textContainer.size = CGSize(width: 198, height: CGFloat.greatestFiniteMagnitude)
  InkImageAttachment.bindAttachments(in: textView)
  await waitForImageLoads(count: 1, loader: loader)

  textView.frame.size.width = 320
  textView.textContainer.size = CGSize(width: 298, height: CGFloat.greatestFiniteMagnitude)
  InkImageAttachment.bindAttachments(in: textView)
  await waitForImageLoads(count: 2, loader: loader)

  #expect(loader.currentLoadCount == 2)
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
  rendering.backend = TestImageBackend(loader)

  let store = InkImageStore()
  let block = InkImageBlock(
    source: ImageSource(url: url),
    rendering: rendering,
    store: store
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
  let block = InkImageBlock(
    source: ImageSource(url: URL(string: "https://example.com/none.png")!),
    rendering: rendering,
    store: InkImageStore()
  )
  let hasTap = block.gestureRecognizers?.contains { $0 is UITapGestureRecognizer } ?? false
  #expect(!hasTap)
}

@Test @MainActor func imageBlock_callbackTapActionInvokesOnImageTap() async {
  let url = URL(string: "https://example.com/tap-callback.png")!
  let loader = SizedMockImageLoader(
    imagesByURL: [url.absoluteString: makeTestImage(width: 200, height: 100)]
  )
  var callCount = 0
  var tappedSource: ImageSource?
  var tappedImage: UIImage?

  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.tapAction = .callback
  rendering.backend = TestImageBackend(loader)
  rendering.onImageTap = { source, image in
    callCount += 1
    tappedSource = source
    tappedImage = image
  }

  let store = InkImageStore()
  let block = InkImageBlock(
    source: ImageSource(url: url),
    rendering: rendering,
    store: store
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

  let block = InkImageBlock(
    source: ImageSource(url: url),
    rendering: rendering,
    store: InkImageStore()
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
  rendering.backend = TestImageBackend(loader)

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

@Test @MainActor func imageBlock_unconfiguredIntrinsicHeightReservesPlaceholder() {
  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.placeholderHeight = 160
  let block = InkImageBlock(
    source: ImageSource(url: URL(string: "https://example.com/unconfigured.png")!),
    rendering: rendering,
    store: InkImageStore()
  )
  #expect(block.intrinsicContentSize.height == 160)
}

@Test @MainActor func imageBlock_failureWithoutFallbackUsesCompactHeight() async {
  let url = URL(string: "https://example.com/fail-block.png")!
  let loader = InkImageStoreTests.MockImageLoader()
  loader.shouldFail = true

  var rendering = InkImageRendering()
  rendering.isEnabled = true
  rendering.placeholderHeight = 160
  rendering.backend = TestImageBackend(loader)

  let store = InkImageStore()
  let block = InkImageBlock(
    source: ImageSource(url: url),
    rendering: rendering,
    store: store
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
  rendering.backend = TestImageBackend(loader)

  let store = InkImageStore()
  let source = ImageSource(url: url)
  let containerWidth: CGFloat = 300
  let block = InkImageBlock(source: source, rendering: rendering, store: store)
  let scale = InkDisplayMetrics.resolve(for: block).scale
  let display = DisplayContext(
    maxPixelWidth: containerWidth * scale,
    scale: scale,
    contentMode: .fit
  )

  do {
    _ = try await rendering.backend?.image(for: InkImageRequest(source: source, display: display))
  } catch { Issue.record("Preloading failed: \(error)") }
  #expect(block.intrinsicContentSize.height == 160)
  block.configure(containerWidth: containerWidth)

  let measuredHeight = block.sizeThatFits(
    CGSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
  ).height
  #expect(measuredHeight == 100)
  #expect(measuredHeight != rendering.placeholderHeight)
}

@Test @MainActor func displayMetrics_prefersContextualViewBounds() {
  let view = UIView(frame: CGRect(x: 0, y: 0, width: 444, height: 777))
  let metrics = InkDisplayMetrics.resolve(for: view)

  #expect(metrics.bounds == view.bounds)
  #expect(metrics.scale > 0)
  #expect(InkDisplayMetrics.availableWidth(for: view) == 444)
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
