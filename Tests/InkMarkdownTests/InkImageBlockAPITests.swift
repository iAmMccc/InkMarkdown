//
//  InkImageBlockAPITests.swift
//  InkMarkdownTests
//

import Testing
import UIKit
@_spi(InkMarkdown) import InkMarkdown

@Suite("InkImageBlock 公开 API 兼容")
@MainActor
struct InkImageBlockAPITests {

  @Test("Auto Layout 宿主在未加载时为图片保留高度")
  func imageBlock_reservesInitialAutoLayoutHeight() {
    let rendering = InkImageRendering()
    let block = InkImageBlock(
      source: ImageSource(url: URL(string: "https://example.com/layout.png")!),
      rendering: rendering
    )
    #expect(block.intrinsicContentSize.height == rendering.placeholderHeight)
    #expect(block.sizeThatFits(CGSize(width: 320, height: 1000)).height == rendering.placeholderHeight)
  }

  @Test("InkImageBlock 是 UIView 子类")
  func imageBlock_isUIViewSubclass() {
    #expect(InkImageBlock.isSubclass(of: UIView.self))
    let block = InkImageBlock(
      source: ImageSource(url: URL(string: "https://example.com/a.png")!),
      rendering: InkImageRendering()
    )
    #expect(block.isKind(of: UIView.self))
  }

  @available(*, deprecated)
  @Test("deprecated init(source:store:rendering:) 可编译并创建视图")
  func imageBlock_deprecatedStoreInitCompiles() {
    let store = InkImageStore()
    var rendering = InkImageRendering()
    rendering.isEnabled = true
    let block = InkImageBlock(
      source: ImageSource(url: URL(string: "https://example.com/legacy.png")!),
      store: store,
      rendering: rendering
    )
    #expect(block.source.rawURL.absoluteString.contains("legacy.png"))
  }

  @Test("makeView 返回原 InkImageBlock 实例")
  func imageBlock_makeViewReturnsSameBlock() {
    let block = InkImageBlock(
      source: ImageSource(url: URL(string: "https://example.com/b.png")!),
      rendering: InkImageRendering()
    )
    let view = block.makeView()
    #expect(view is InkImageBlock)
    #expect(view === block)
  }

  @available(*, deprecated)
  @Test("InkImageBlockView 为 InkImageBlock 兼容别名")
  func imageBlock_viewTypealias() {
    let legacy = InkImageBlockView(
      source: ImageSource(url: URL(string: "https://example.com/alias.png")!),
      store: InkImageStore(),
      rendering: InkImageRendering()
    )
    #expect(legacy.isKind(of: UIView.self))
    #expect(legacy.source.rawURL.absoluteString.contains("alias.png"))
  }
}
