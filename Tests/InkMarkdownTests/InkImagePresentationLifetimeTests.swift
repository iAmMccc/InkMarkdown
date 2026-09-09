import Testing
import UIKit
@testable import InkMarkdown

@Suite("图片呈现释放与旧路径清理", .serialized)
@MainActor
struct InkImagePresentationLifetimeTests {

  @Test
  func releasingBlock_cancelsLastSubscription() async throws {
    let url = URL(string: "https://example.com/lifetime-block.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.backend = TestImageBackend(loader)

    let store = InkImageStore()
    var block: InkImageBlock? = InkImageBlock(
      source: ImageSource(url: url),
      rendering: rendering,
      store: store
    )
    weak var weakBlock = block
    block?.configure(containerWidth: 200, loader: loader)
    try await loader.waitUntilStarted(requestID: 1)

    block = nil
    for _ in 0..<40 { await Task.yield() }
    #expect(weakBlock == nil)
    #expect(loader.cancelledIDs.contains(1) || loader.pendingRequestIDs.isEmpty)
  }

  @Test
  func releasingAttachment_doesNotRetainAfterCancel() async throws {
    let url = URL(string: "https://example.com/lifetime-attach.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.backend = TestImageBackend(loader)

    let store = InkImageStore()
    var attachment: InkImageAttachment? = InkImageAttachment(
      source: ImageSource(url: url),
      rendering: rendering,
      store: store
    )
    weak var weakAttachment = attachment
    let resolved = store.loader(for: rendering, source: attachment!.source)
    attachment?.materialize(
      display: DisplayContext(maxPixelWidth: 200, scale: 2),
      loader: resolved
    )
    try await loader.waitUntilStarted(requestID: 1)

    attachment = nil
    for _ in 0..<40 { await Task.yield() }
    #expect(weakAttachment == nil)
    #expect(loader.cancelledIDs.contains(1))
  }

  @Test
  func independentPresentations_cancelOneDoesNotAffectOther() async throws {
    let url = URL(string: "https://example.com/lifetime-independent.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.backend = TestImageBackend(loader)
    let store = InkImageStore()
    let bound = store.loader(for: rendering)
    let display = DisplayContext(maxPixelWidth: 100, scale: 2)
    let source = ImageSource(url: url)

    let first = InkImagePresentationLoad()
    let second = InkImagePresentationLoad()
    var secondDone = false

    first.start(
      source: source,
      display: display,
      loader: bound,
      store: store,
      onCompletion: { _ in }
    )
    second.start(
      source: source,
      display: display,
      loader: bound,
      store: store,
      onCompletion: { _ in secondDone = true }
    )
    try await loader.waitUntilLoadCount(2)

    first.cancel()
    try? await Task.sleep(nanoseconds: 20_000_000)
    #expect(loader.cancelledIDs.contains(1))
    #expect(!secondDone)

    loader.succeed(2)
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(secondDone)
  }
}
