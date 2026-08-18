import Testing
import UIKit
@testable import InkMarkdown

// MARK: - Test helpers

private struct FailingGeneratedImageLoader: InkGeneratedImageLoading {
  func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage {
    throw ImageLoadError.decodeFailed
  }
}

private final class FailingURLImageLoader: InkImageLoading, @unchecked Sendable {
  private var completedCount = 0
  private let queue = DispatchQueue(label: "inkmarkdown.tests.failing-url-loader")

  func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    queue.sync { completedCount += 1 }
    throw ImageLoadError.decodeFailed
  }

  var currentCompletedCount: Int {
    queue.sync { completedCount }
  }
}

private final class SizedGeneratedImageLoader: InkGeneratedImageLoading, @unchecked Sendable {
  private var completedCount = 0
  private let queue = DispatchQueue(label: "inkmarkdown.tests.sized-generated-loader")
  let image: UIImage

  init(image: UIImage) {
    self.image = image
  }

  func loadGeneratedImage(
    request: InkGeneratedImageRequest,
    display: DisplayContext
  ) async throws -> UIImage {
    queue.sync { completedCount += 1 }
    return image
  }

  var currentCompletedCount: Int {
    queue.sync { completedCount }
  }
}

private func makeTestImage(width: CGFloat, height: CGFloat) -> UIImage {
  let format = UIGraphicsImageRendererFormat()
  format.scale = 1
  return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
    UIColor.systemBlue.setFill()
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
  }
}

private final class DelayedURLImageLoader: InkImageLoading, @unchecked Sendable {
  var delay: UInt64 = 0

  func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    if delay > 0 {
      try await Task.sleep(nanoseconds: delay)
    }
    return UIImage(systemName: "photo")!
  }
}

@MainActor
private func collectLabelTexts(in view: UIView) -> [String] {
  var texts: [String] = []
  if let label = view as? UILabel {
    if let text = label.text, !text.isEmpty {
      texts.append(text)
    } else if let text = label.attributedText?.string, !text.isEmpty {
      texts.append(text)
    }
  }
  for subview in view.subviews {
    texts.append(contentsOf: collectLabelTexts(in: subview))
  }
  return texts
}

@MainActor
private func expectedCodeBlockHeight(lineCount: Int, style: InkAppearance.CodeBlock = .init()) -> CGFloat {
  style.verticalPadding * 2 + style.lineHeight * CGFloat(lineCount) + style.spacingToText
}

@MainActor
private func hasVisibleGrayPlaceholder(in view: UIView) -> Bool {
  if view.backgroundColor == UIColor.systemGray5, !view.isHidden {
    return true
  }
  return view.subviews.contains { hasVisibleGrayPlaceholder(in: $0) }
}

@MainActor
private func waitForLoaderCompletion(
  count: Int,
  loader: FailingURLImageLoader,
  timeoutNanoseconds: UInt64 = 2_000_000_000
) async {
  let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
  while loader.currentCompletedCount < count, DispatchTime.now().uptimeNanoseconds < deadline {
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
  for _ in 0..<10 { await Task.yield() }
}

@MainActor
private func waitForGeneratedLoaderCompletion(
  count: Int,
  loader: SizedGeneratedImageLoader,
  timeoutNanoseconds: UInt64 = 2_000_000_000
) async {
  let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
  while loader.currentCompletedCount < count, DispatchTime.now().uptimeNanoseconds < deadline {
    try? await Task.sleep(nanoseconds: 10_000_000)
  }
  for _ in 0..<10 { await Task.yield() }
}

// MARK: - Mermaid failure fallback

@Suite @MainActor struct InkMermaidFailureFallbackTests {

  @Test func mermaidBlockHandler_injectsSourceCodeFallback() async {
    var appearance = InkAppearance()
    appearance.mermaidRendering.isEnabled = true
    appearance.imageRendering.isEnabled = true
    let config = InkConfiguration(appearance: appearance)

    let blocks = InkBlockRenderer.render(
      """
      ```mermaid
      graph TD
          A-->B
      ```
      """,
      configuration: config
    )
    guard let block = blocks.first as? InkImageBlock else {
      Issue.record("应生成 InkImageBlock")
      return
    }

    #expect(blocks.count == 1)

    let failingLoader = FailingGeneratedImageLoader()
    block.configure(containerWidth: 320, loader: failingLoader)

    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while collectLabelTexts(in: block).isEmpty, DispatchTime.now().uptimeNanoseconds < deadline {
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    for _ in 0..<10 { await Task.yield() }

    let texts = collectLabelTexts(in: block)
    #expect(texts.contains { $0.contains("graph TD") && $0.contains("A-->B") })
    #expect(!hasVisibleGrayPlaceholder(in: block))
    let codeBlockStyle = InkAppearance().codeBlock
    let expectedHeight = expectedCodeBlockHeight(lineCount: 2, style: codeBlockStyle)
    #expect(block.intrinsicContentSize.height >= expectedHeight - 1)
    #expect(block.intrinsicContentSize.height < config.appearance.imageRendering.placeholderHeight)
  }

  @Test func mermaidBlockRejectedShowsSourceCodeImmediately() {
    var storeConfig = InkImageStore.Configuration()
    storeConfig.maxConcurrentLoads = 1
    storeConfig.maxPendingLoads = 0
    let store = InkImageStore(configuration: storeConfig)

    let slowLoader = DelayedURLImageLoader()
    slowLoader.delay = 1_000_000_000
    let display = DisplayContext(maxPixelWidth: 300, scale: 2)
    _ = store.resolve(
      source: ImageSource(url: URL(string: "https://example.com/blocker.png")!),
      display: display,
      loader: slowLoader
    )

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.failureFallback = .sourceCode("sequenceDiagram\n  A->>B: hi", language: "mermaid")
    rendering.failureCodeBlockStyle = InkAppearance().codeBlock

    let source = ImageSource(generated: InkGeneratedImageRequest(
      owner: "mermaid",
      rendererVersion: "test",
      source: "sequenceDiagram\n  A->>B: hi",
      styleIdentity: "light"
    ))
    let block = InkImageBlock(source: source, store: store, rendering: rendering)
    block.configure(containerWidth: 280, loader: slowLoader)

    let texts = collectLabelTexts(in: block)
    #expect(texts.contains { $0.contains("sequenceDiagram") && $0.contains("A->>B: hi") })
    #expect(!hasVisibleGrayPlaceholder(in: block))
    let expectedHeight = expectedCodeBlockHeight(lineCount: 2, style: rendering.failureCodeBlockStyle)
    #expect(block.intrinsicContentSize.height >= expectedHeight - 1)
  }

  @Test func imageBlockFailureWithoutFallbackShowsCompactLabel() async {
    let url = URL(string: "https://example.com/fail.png")!
    let loader = FailingURLImageLoader()
    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.loader = loader

    let block = InkImageBlock(
      source: ImageSource(url: url),
      store: InkImageStore(),
      rendering: rendering
    )
    block.configure(containerWidth: 300, loader: loader)
    await waitForLoaderCompletion(count: 1, loader: loader)

    #expect(collectLabelTexts(in: block).contains("[🖼 image]"))
    #expect(!hasVisibleGrayPlaceholder(in: block))
    #expect(block.intrinsicContentSize.height < rendering.placeholderHeight)
  }

  @Test func imageBlockReuseClearsFailureFallbackAfterSuccess() async {
    let mermaidSource = "graph LR\n  X-->Y"
    let generatedSource = ImageSource(generated: InkGeneratedImageRequest(
      owner: "mermaid",
      rendererVersion: "test",
      source: mermaidSource,
      styleIdentity: "light"
    ))

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.failureFallback = .sourceCode(mermaidSource, language: "mermaid")

    let store = InkImageStore()
    let block = InkImageBlock(source: generatedSource, store: store, rendering: rendering)

    let failingLoader = FailingGeneratedImageLoader()
    block.configure(containerWidth: 300, loader: failingLoader)

    let failureDeadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while collectLabelTexts(in: block).isEmpty, DispatchTime.now().uptimeNanoseconds < failureDeadline {
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    for _ in 0..<10 { await Task.yield() }
    #expect(collectLabelTexts(in: block).contains { $0.contains("graph LR") })

    let successLoader = SizedGeneratedImageLoader(image: makeTestImage(width: 120, height: 60))
    block.configure(containerWidth: 300, loader: successLoader)
    await waitForGeneratedLoaderCompletion(count: 1, loader: successLoader)

    #expect(collectLabelTexts(in: block).isEmpty)
    #expect(!hasVisibleGrayPlaceholder(in: block))
    #expect(block.intrinsicContentSize.height == 60 || block.frame.height == 60)
  }

  @Test func imageBlockPrepareForReuseRemovesFailureFallback() async {
    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.failureFallback = .sourceCode("flowchart TD\n  Q-->R", language: "mermaid")

    let source = ImageSource(generated: InkGeneratedImageRequest(
      owner: "mermaid",
      rendererVersion: "test",
      source: "flowchart TD\n  Q-->R",
      styleIdentity: "light"
    ))
    let block = InkImageBlock(source: source, store: InkImageStore(), rendering: rendering)
    block.configure(containerWidth: 260, loader: FailingGeneratedImageLoader())

    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while collectLabelTexts(in: block).isEmpty, DispatchTime.now().uptimeNanoseconds < deadline {
      try? await Task.sleep(nanoseconds: 10_000_000)
    }
    for _ in 0..<10 { await Task.yield() }
    #expect(!collectLabelTexts(in: block).isEmpty)

    block.prepareForReuse()
    #expect(collectLabelTexts(in: block).isEmpty)
    #expect(!hasVisibleGrayPlaceholder(in: block))
    #expect(block.intrinsicContentSize.height == 0)
  }
}
