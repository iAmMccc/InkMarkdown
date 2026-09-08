import Testing
import UIKit
@testable import InkMarkdown

@Suite("InkImageAttachment PresentationLoad adapter", .serialized)
@MainActor
struct InkImageAttachmentPresentationAdapterTests {

  @Test
  func sameIdentity_doesNotRestartLoad() async throws {
    let url = URL(string: "https://example.com/attach-same.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.backend = TestImageBackend(loader)

    let store = InkImageStore()
    let attachment = InkImageAttachment(
      source: ImageSource(url: url),
      rendering: rendering,
      store: store
    )
    let display = DisplayContext(maxPixelWidth: 300, scale: 2)
    let resolvedLoader = store.loader(for: rendering, source: attachment.source)

    attachment.materialize(display: display, loader: resolvedLoader)
    try await loader.waitUntilStarted(requestID: 1)
    loader.succeed(1, image: makeAttachImage(width: 80, height: 80))
    for _ in 0..<20 { await Task.yield() }

    let loads = loader.loadCount
    attachment.materialize(display: display, loader: resolvedLoader)
    for _ in 0..<10 { await Task.yield() }
    #expect(loader.loadCount == loads)
  }

  @Test
  func displayChange_restartsLoad() async throws {
    let url = URL(string: "https://example.com/attach-resize.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.backend = TestImageBackend(loader)

    let store = InkImageStore()
    let attachment = InkImageAttachment(
      source: ImageSource(url: url),
      rendering: rendering,
      store: store
    )
    let resolvedLoader = store.loader(for: rendering, source: attachment.source)

    attachment.materialize(
      display: DisplayContext(maxPixelWidth: 200, scale: 2),
      loader: resolvedLoader
    )
    try await loader.waitUntilStarted(requestID: 1)
    loader.succeed(1, image: makeAttachImage(width: 60, height: 60))
    for _ in 0..<20 { await Task.yield() }

    attachment.materialize(
      display: DisplayContext(maxPixelWidth: 400, scale: 2),
      loader: resolvedLoader
    )
    try await loader.waitUntilStarted(requestID: 2)
    loader.succeed(2, image: makeAttachImage(width: 90, height: 90))
    for _ in 0..<20 { await Task.yield() }
    #expect(loader.loadCount == 2)
  }

  @Test
  func constructWithoutBind_doesNotStartLoader() {
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.placeholderHeight = 160
    rendering.backend = TestImageBackend(loader)

    let attachment = InkImageAttachment(
      source: ImageSource(url: URL(string: "https://example.com/attach-unbound.png")!),
      rendering: rendering,
      store: InkImageStore()
    )
    let bounds = attachment.attachmentBounds(
      for: nil,
      proposedLineFragment: CGRect(x: 0, y: 0, width: 300, height: 22),
      glyphPosition: .zero,
      characterIndex: 0
    )
    #expect(bounds.height < 80)
    #expect(loader.loadCount == 0)
  }

  @Test
  func lateAAfterRematerializeB_doesNotApply() async throws {
    let url = URL(string: "https://example.com/attach-late.png")!
    let loader = InkControlledImageLoader(cancellationBehavior: .ignoreCancel)
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.backend = TestImageBackend(loader)

    let store = InkImageStore()
    let attachment = InkImageAttachment(
      source: ImageSource(url: url),
      rendering: rendering,
      store: store
    )
    let resolvedLoader = store.loader(for: rendering, source: attachment.source)

    attachment.materialize(
      display: DisplayContext(maxPixelWidth: 180, scale: 2),
      loader: resolvedLoader
    )
    try await loader.waitUntilStarted(requestID: 1)

    attachment.materialize(
      display: DisplayContext(maxPixelWidth: 360, scale: 2),
      loader: resolvedLoader
    )
    try await loader.waitUntilStarted(requestID: 2)

    loader.succeed(1, image: makeAttachImage(width: 50, height: 50))
    for _ in 0..<15 { await Task.yield() }
    #expect(attachment.bounds.height != 50)

    loader.succeed(2, image: makeAttachImage(width: 70, height: 70))
    for _ in 0..<20 { await Task.yield() }
    #expect(attachment.bounds.height == 70 || attachment.image?.size.height == 70)
  }
}

private func makeAttachImage(width: CGFloat, height: CGFloat) -> UIImage {
  let size = CGSize(width: width, height: height)
  let renderer = UIGraphicsImageRenderer(size: size)
  return renderer.image { context in
    UIColor.systemGreen.setFill()
    context.fill(CGRect(origin: .zero, size: size))
  }
}
