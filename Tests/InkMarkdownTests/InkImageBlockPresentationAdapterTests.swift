import Foundation
import Testing
import UIKit
@testable import InkMarkdown

@Suite("InkImageBlock PresentationLoad adapter", .serialized)
@MainActor
struct InkImageBlockPresentationAdapterTests {

  @Test
  func cachedReady_skipsLoadingPlaceholderHeight() async throws {
    let url = URL(string: "https://example.com/block-ready.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.placeholderHeight = 160
    rendering.backend = TestImageBackend(loader)

    let store = InkImageStore()
    let source = ImageSource(url: url)
    let block = InkImageBlock(source: source, rendering: rendering, store: store)
    let containerWidth: CGFloat = 300
    let scale = InkDisplayMetrics.resolve(for: block).scale
    let display = DisplayContext(
      maxPixelWidth: containerWidth * scale,
      scale: scale,
      contentMode: .fit
    )

    let warm = store.resolve(source: source, display: display, loader: store.loader(for: rendering))
    if case .loading(let subscribe) = warm {
      let sub = subscribe { _ in }
      try await loader.waitUntilStarted(requestID: 1)
      loader.succeed(1, image: makeSolidImage(width: 200, height: 100))
      for _ in 0..<20 { await Task.yield() }
      sub.cancel()
    } else if case .ready = warm {
      // already warm
    } else {
      Issue.record("预热应进入 loading 或 ready")
      return
    }

    block.configure(containerWidth: containerWidth, loader: store.loader(for: rendering))
    let height = block.sizeThatFits(
      CGSize(width: containerWidth, height: CGFloat.greatestFiniteMagnitude)
    ).height
    #expect(height == 100)
    #expect(height != rendering.placeholderHeight)
    #expect(loader.loadCount == 1)
  }

  @Test
  func prepareForReuse_suppressesLateA_thenBCompletes() async throws {
    let urlA = URL(string: "https://example.com/block-a.png")!
    let urlB = URL(string: "https://example.com/block-b.png")!
    let loader = InkControlledImageLoader(cancellationBehavior: .ignoreCancel)
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.placeholderHeight = 120
    rendering.backend = TestImageBackend(loader)

    let store = InkImageStore()
    let blockA = InkImageBlock(
      source: ImageSource(url: urlA),
      rendering: rendering,
      store: store
    )
    blockA.configure(containerWidth: 240, loader: store.loader(for: rendering))
    try await loader.waitUntilStarted(requestID: 1)
    #expect(
      blockA.sizeThatFits(CGSize(width: 240, height: CGFloat.greatestFiniteMagnitude)).height
        == rendering.placeholderHeight
    )

    blockA.prepareForReuse()
    #expect(blockA.intrinsicContentSize.height == rendering.placeholderHeight)
    #expect(
      blockA.sizeThatFits(CGSize(width: 240, height: CGFloat.greatestFiniteMagnitude)).height == rendering.placeholderHeight
    )

    loader.succeed(1, image: makeSolidImage(width: 200, height: 80))
    for _ in 0..<20 { await Task.yield() }
    #expect(blockA.intrinsicContentSize.height == rendering.placeholderHeight)

    let blockB = InkImageBlock(
      source: ImageSource(url: urlB),
      rendering: rendering,
      store: store
    )
    blockB.configure(containerWidth: 240, loader: store.loader(for: rendering))
    try await loader.waitUntilStarted(requestID: 2)
    loader.succeed(2, image: makeSolidImage(width: 200, height: 90))
    for _ in 0..<20 { await Task.yield() }

    let heightB = blockB.sizeThatFits(
      CGSize(width: 240, height: CGFloat.greatestFiniteMagnitude)
    ).height
    #expect(heightB == 90)
    #expect(blockA.intrinsicContentSize.height == rendering.placeholderHeight)
  }

  @Test
  func failureFallback_and_tapCallbackRemain() async throws {
    let url = URL(string: "https://example.com/block-fail-tap.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var tapCount = 0
    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.placeholderHeight = 160
    rendering.tapAction = .callback
    rendering.backend = TestImageBackend(loader)
    rendering.onImageTap = { _, _ in tapCount += 1 }

    let store = InkImageStore()
    let block = InkImageBlock(
      source: ImageSource(url: url),
      rendering: rendering,
      store: store
    )
    #expect(block.gestureRecognizers?.contains { $0 is UITapGestureRecognizer } == true)

    block.configure(containerWidth: 280, loader: store.loader(for: rendering))
    try await loader.waitUntilStarted(requestID: 1)
    loader.fail(1)
    for _ in 0..<20 { await Task.yield() }

    let height = block.intrinsicContentSize.height
    #expect(height < 80)
    #expect(height < 160)

    block.handleConfiguredTap()
    #expect(tapCount == 1)
  }

  @Test
  func updateExistingView_sameSourcePreservesLoadedImage() async throws {
    let url = URL(string: "https://example.com/preserve-image.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var rendering1 = InkImageRendering()
    rendering1.isEnabled = true
    rendering1.backend = TestImageBackend(loader)

    let store = InkImageStore()
    let source = ImageSource(url: url)
    let block1 = InkImageBlock(source: source, rendering: rendering1, store: store)
    block1.configure(containerWidth: 300, loader: store.loader(for: rendering1))

    try await loader.waitUntilStarted(requestID: 1)
    let testImage = makeSolidImage(width: 200, height: 120)
    loader.succeed(1, image: testImage)
    for _ in 0..<20 { await Task.yield() }

    #expect(block1.sizeThatFits(CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude)).height == 120)

    // Same instance
    #expect(block1.updateExistingView(block1) == true)

    // Different instance, same source & store
    var rendering2 = rendering1
    rendering2.placeholderHeight = 200
    let block2 = InkImageBlock(source: source, rendering: rendering2, store: store)
    #expect(block2.updateExistingView(block1) == true)
    // The image on block1 should be retained!
    #expect(block1.sizeThatFits(CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude)).height == 120)

    // Different source
    let block3 = InkImageBlock(source: ImageSource(url: URL(string: "https://example.com/other.png")!), rendering: rendering1, store: store)
    #expect(block3.updateExistingView(block1) == false)
  }
}

private func makeSolidImage(width: CGFloat, height: CGFloat) -> UIImage {
  let size = CGSize(width: width, height: height)
  let renderer = UIGraphicsImageRenderer(size: size)
  return renderer.image { context in
    UIColor.darkGray.setFill()
    context.fill(CGRect(origin: .zero, size: size))
  }
}
