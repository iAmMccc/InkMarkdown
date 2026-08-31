//
//  InkPartialBlockReuseTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

private struct TestReusableLabelBlock: InkReusableBlock {
  let text: String

  @MainActor
  func makeView() -> UIView {
    let label = UILabel()
    label.text = text
    return label
  }

  @MainActor
  func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    (previous as? TestReusableLabelBlock)?.text == text
  }

  @MainActor
  func updateExistingView(_ view: UIView) -> Bool {
    guard let label = view as? UILabel else { return false }
    label.text = text
    return true
  }
}

private final class TestDelayedImageLoader: InkImageLoading, @unchecked Sendable {
  struct Response {
    let delayNanoseconds: UInt64
    let image: UIImage
  }

  private let responses: [URL: Response]

  init(responses: [URL: Response]) {
    self.responses = responses
  }

  func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    guard let response = responses[source.rawURL] else { throw ImageLoadError.decodeFailed }
    try await Task.sleep(nanoseconds: response.delayNanoseconds)
    return response.image
  }
}

private final class TestWeakReference<Value: AnyObject> {
  weak var value: Value?

  init(_ value: Value?) {
    self.value = value
  }
}

@Suite("块级视图局部复用")
@MainActor
struct InkPartialBlockReuseTests {

  @Test("第三方 InkReusableBlock 内容变化后显示最新内容")
  func customReusableBlockUpdatesExistingView() throws {
    let container = InkMarkdownContainerView()
    let coordinator = makeCoordinator(for: container)
    let configuration = InkConfiguration.standard

    coordinator.updateBlocks([TestReusableLabelBlock(text: "before")], configuration: configuration)
    let original = try #require(container.subviews.first as? UILabel)
    #expect(original.text == "before")

    coordinator.updateBlocks([TestReusableLabelBlock(text: "after")], configuration: configuration)
    let updated = try #require(container.subviews.first as? UILabel)
    #expect(updated.text == "after")
  }

  @Test("InkCodeBlock 三参数 initializer 保留自定义样式")
  func codeBlockThreeArgumentInitializerAppliesConfiguration() throws {
    var style = InkAppearance.CodeBlock()
    style.backgroundColor = .systemPink
    style.fontSize = 23

    let block = InkCodeBlock(code: "let value = 1", language: "swift", config: style)
    let view = block.makeView()
    let label = try #require(descendants(of: UILabel.self, in: view).first)

    #expect(block.config.backgroundColor == .systemPink)
    #expect(block.config.fontSize == 23)
    #expect(view.subviews.first?.backgroundColor == .systemPink)
    #expect((label.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize == 23)
  }

  @Test("富文本后缀、样式或链接变化会更新完整 attributed 语义")
  func attributedContentChangesUpdateTextView() throws {
    let container = InkMarkdownContainerView()
    let coordinator = makeCoordinator(for: container)
    let prefix = String(repeating: "A", count: 65)
    let first = NSMutableAttributedString(string: prefix + "X")
    first.addAttribute(.link, value: URL(string: "https://a.example")!, range: NSRange(location: 0, length: 1))
    let second = NSMutableAttributedString(string: prefix + "Y")
    second.addAttributes([
      .link: URL(string: "https://b.example")!,
      .font: UIFont.italicSystemFont(ofSize: 17),
    ], range: NSRange(location: 0, length: 1))

    coordinator.updateBlocks(
      [InkAttributedTextBlock(attributedText: first)],
      configuration: .standard
    )
    let originalView = try #require(container.subviews.first as? UITextView)
    #expect(originalView.attributedText.string == prefix + "X")

    coordinator.updateBlocks(
      [InkAttributedTextBlock(attributedText: second)],
      configuration: .standard
    )
    let updatedView = try #require(container.subviews.first as? UITextView)

    #expect(updatedView.attributedText.string == prefix + "Y")
    #expect(updatedView.attributedText.attribute(.link, at: 0, effectiveRange: nil) as? URL == URL(string: "https://b.example"))
    #expect(updatedView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == UIFont.italicSystemFont(ofSize: 17))
  }

  @Test("富文本 attachment source 变化会更新 text view 内容")
  func attachmentChangeUpdatesTextView() throws {
    let container = InkMarkdownContainerView()
    let coordinator = makeCoordinator(for: container)
    var rendering = InkImageRendering()
    rendering.isEnabled = true
    let firstAttachment = InkImageAttachment(
      source: ImageSource(url: URL(string: "https://a.example/inline.png")!),
      rendering: rendering,
      store: nil
    )
    let secondAttachment = InkImageAttachment(
      source: ImageSource(url: URL(string: "https://b.example/inline.png")!),
      rendering: rendering,
      store: nil
    )

    coordinator.updateBlocks(
      [InkAttributedTextBlock(attributedText: NSAttributedString(attachment: firstAttachment))],
      configuration: .standard
    )
    let originalView = try #require(container.subviews.first as? UITextView)
    #expect(
      (originalView.attributedText.attribute(.attachment, at: 0, effectiveRange: nil)
        as? InkImageAttachment)?.source.rawURL == firstAttachment.source.rawURL
    )
    coordinator.updateBlocks(
      [InkAttributedTextBlock(attributedText: NSAttributedString(attachment: secondAttachment))],
      configuration: .standard
    )
    let updatedView = try #require(container.subviews.first as? UITextView)
    let updatedAttachment = try #require(
      updatedView.attributedText.attribute(.attachment, at: 0, effectiveRange: nil) as? InkImageAttachment
    )

    #expect(updatedAttachment.source.rawURL == URL(string: "https://b.example/inline.png"))
  }

  @Test("图片 source 变化后显示新 source")
  func imageSourceChangeDisplaysNewSource() throws {
    let container = InkMarkdownContainerView()
    let coordinator = makeCoordinator(for: container)
    var rendering = InkImageRendering()
    rendering.isEnabled = true
    let first = InkImageBlock(source: ImageSource(url: URL(string: "https://a.example/image.png")!), rendering: rendering)
    let second = InkImageBlock(source: ImageSource(url: URL(string: "https://b.example/image.png")!), rendering: rendering)

    coordinator.updateBlocks([first], configuration: .standard)
    _ = try #require(container.subviews.first as? InkImageBlock)
    coordinator.updateBlocks([second], configuration: .standard)
    let updatedView = try #require(container.subviews.first as? InkImageBlock)

    #expect(updatedView.source.rawURL == URL(string: "https://b.example/image.png"))
  }

  @Test("图片块注入不同 Store 时视图语义不等价")
  func imageStoreDifferenceChangesImageSemantics() {
    var rendering = InkImageRendering()
    rendering.isEnabled = true
    let source = ImageSource(url: URL(string: "https://example.com/image.png")!)
    let first = InkImageBlock(source: source, store: InkImageStore(), rendering: rendering)
    let second = InkImageBlock(source: source, store: InkImageStore(), rendering: rendering)

    #expect(!second.hasEquivalentContent(to: first))
  }

  @Test("图片 source 替换后取消旧订阅并只展示新请求结果")
  func replacingImageBlockCancelsOldSubscriptionAndShowsNewImage() async throws {
    let oldURL = URL(string: "https://example.com/old.png")!
    let newURL = URL(string: "https://example.com/new.png")!
    let oldImage = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 240)).image { context in
      UIColor.red.setFill()
      context.cgContext.fill(CGRect(x: 0, y: 0, width: 200, height: 240))
    }
    let newImage = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 80)).image { context in
      UIColor.blue.setFill()
      context.cgContext.fill(CGRect(x: 0, y: 0, width: 200, height: 80))
    }
    let loader = TestDelayedImageLoader(responses: [
      oldURL: .init(delayNanoseconds: 300_000_000, image: oldImage),
      newURL: .init(delayNanoseconds: 20_000_000, image: newImage),
    ])
    let store = InkImageStore()
    var oldCompletionCount = 0
    var newCompletionCount = 0

    var oldRendering = InkImageRendering()
    oldRendering.isEnabled = true
    oldRendering.setLoader(loader, semanticIdentity: "test.delayed-loader.v1")
    oldRendering.setLoadFinishedHandler({ _, _ in
      oldCompletionCount += 1
    }, semanticIdentity: "test.old-completion.v1")

    var newRendering = oldRendering
    newRendering.setLoadFinishedHandler({ _, image in
      if image != nil { newCompletionCount += 1 }
    }, semanticIdentity: "test.new-completion.v1")

    let container = InkMarkdownContainerView()
    let coordinator = makeCoordinator(for: container)
    var oldBlock: InkImageBlock? = InkImageBlock(
      source: ImageSource(url: oldURL),
      store: store,
      rendering: oldRendering
    )
    let releasedOldBlock = TestWeakReference(oldBlock)
    coordinator.updateBlocks([try #require(oldBlock)], configuration: .standard)
    oldBlock?.frame = CGRect(x: 0, y: 0, width: 200, height: 160)
    oldBlock?.layoutIfNeeded()

    let newBlock = InkImageBlock(
      source: ImageSource(url: newURL),
      store: store,
      rendering: newRendering
    )
    coordinator.updateBlocks([newBlock], configuration: .standard)
    newBlock.frame = CGRect(x: 0, y: 0, width: 200, height: 160)
    newBlock.layoutIfNeeded()
    oldBlock = nil

    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while newCompletionCount == 0, DispatchTime.now().uptimeNanoseconds < deadline {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    try await Task.sleep(nanoseconds: 350_000_000)

    #expect(releasedOldBlock.value == nil)
    #expect(oldCompletionCount == 0)
    #expect(newCompletionCount == 1)
    #expect(newBlock.source.rawURL == newURL)
    #expect(newBlock.sizeThatFits(
      CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
    ).height == 80)
  }

  @Test("LaTeX 与 Mermaid generated source 变化后均显示新 source")
  func generatedImageSourceChangesDisplayNewSource() throws {
    for owner in ["latex", "mermaid"] {
      let container = InkMarkdownContainerView()
      let coordinator = makeCoordinator(for: container)
      var rendering = InkImageRendering()
      rendering.isEnabled = true
      let firstRequest = InkGeneratedImageRequest(
        owner: owner,
        rendererVersion: "v1",
        source: "source-A",
        styleIdentity: "default"
      )
      let secondRequest = InkGeneratedImageRequest(
        owner: owner,
        rendererVersion: "v1",
        source: "source-B",
        styleIdentity: "default"
      )

      coordinator.updateBlocks(
        [InkImageBlock(source: ImageSource(generated: firstRequest), rendering: rendering)],
        configuration: .standard
      )
      _ = try #require(container.subviews.first as? InkImageBlock)
      coordinator.updateBlocks(
        [InkImageBlock(source: ImageSource(generated: secondRequest), rendering: rendering)],
        configuration: .standard
      )
      let updatedView = try #require(container.subviews.first as? InkImageBlock)

      #expect(updatedView.source.generatedRequest?.owner == owner)
      #expect(updatedView.source.generatedRequest?.source == "source-B")
    }
  }

  @Test("表格 alignment 与 layout mode 变化后更新可见层级")
  func tableLayoutChangesUpdateRenderedStructure() throws {
    let container = InkMarkdownContainerView()
    let coordinator = makeCoordinator(for: container)
    let first = InkTableBlock(
      headers: ["A", "B"],
      rows: [["1", "2"]],
      alignments: [.left, .right],
      layoutMode: .wrap
    )
    let second = InkTableBlock(
      headers: ["A", "B"],
      rows: [["1", "2"]],
      alignments: [.center, .right],
      layoutMode: .scroll
    )

    coordinator.updateBlocks([first], configuration: .standard)
    let tableView = try #require(container.subviews.first)
    #expect(scrollContainers(in: tableView).isEmpty)

    coordinator.updateBlocks([second], configuration: .standard)
    let updatedTableView = try #require(container.subviews.first)
    let firstCell = try #require(descendants(of: UITextView.self, in: updatedTableView).first)
    let paragraph = try #require(
      firstCell.attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
        as? NSParagraphStyle
    )

    #expect(updatedTableView.subviews.count == 1)
    #expect(scrollContainers(in: updatedTableView).count == 1)
    #expect(paragraph.alignment == .center)
  }

  private func makeCoordinator(for container: InkMarkdownContainerView) -> InkMarkdownCoordinator {
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    return coordinator
  }

  private func descendants<T: UIView>(of type: T.Type, in root: UIView) -> [T] {
    root.subviews.flatMap { view -> [T] in
      let current = (view as? T).map { [$0] } ?? []
      return current + descendants(of: type, in: view)
    }
  }

  private func scrollContainers(in root: UIView) -> [UIScrollView] {
    descendants(of: UIScrollView.self, in: root).filter { !($0 is UITextView) }
  }
}
