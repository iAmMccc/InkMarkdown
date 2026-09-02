import Foundation
import Testing
import UIKit
import InkMarkdown
import InkMarkdownSemanticCorpus
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

// MARK: - linkTapHandler 跨形态契约（ticket 04）
//
// 正文块、表格单元格（见 InkCorpusTableTracerTests）与 SwiftUI streaming text
// 在未 finish、finish 与 promotion 后使用同一 handler 契约：
// 返回 `true` 表示宿主已处理并阻止系统默认行为；未配置或返回 `false` 保留默认。
// 不通过 UIApplication / Safari / UI automation 判断成功。

@Suite("linkTapHandler 统一交互契约")
@MainActor
struct InkLinkInteractionContractTests {

  private let streamURL = URL(string: "https://example.com/stream")!

  /// 流式未 finish 阶段：remainder 文本视图已连接 configuration 的 handler。
  @Test("streaming 未完成阶段立即连接 handler")
  func streamingBeforeFinish_connectsHandlerImmediately() async throws {
    let handlerSpy = LinkHandlerSpy()
    var configuration = InkConfiguration.standard
    configuration.setLinkTapHandler(handlerSpy.handler, semanticIdentity: "test.streaming.v1")

    let session = InkMarkdownRenderSession(configuration: configuration)
    session.append("[流式链接](https://example.com/stream) 后续内容")
    let (container, coordinator) = try attachStreaming(session: session)

    // 等待流式解析产出链接文本（handler 接线本身在 reconcile 同步完成）。
    let textView = try await waitForStreamTextView(in: container, coordinator: coordinator)
    #expect(textView.attributedText.string.contains("流式链接"))

    try assertDelegateAsksHandler(
      textView: textView,
      linkText: "流式链接",
      expectedURL: streamURL,
      spy: handlerSpy
    )
  }

  /// handler 返回 `false`：委托交还系统默认行为（delegate 返回 true）。
  @Test("handler 返回 false 保留系统默认行为")
  func handlerReturningFalse_preservesSystemDefault() async throws {
    let handlerSpy = LinkHandlerSpy(shouldHandle: false)
    var configuration = InkConfiguration.standard
    configuration.setLinkTapHandler(handlerSpy.handler, semanticIdentity: "test.false.v1")

    let session = InkMarkdownRenderSession(configuration: configuration)
    session.append("[流式链接](https://example.com/stream) 内容")
    let (container, coordinator) = try attachStreaming(session: session)
    let textView = try await waitForStreamTextView(in: container, coordinator: coordinator)

    let range = (textView.attributedText.string as NSString).range(of: "流式链接")
    #expect(range.location != NSNotFound)
    let result = textView.delegate?.textView?(
      textView,
      shouldInteractWith: streamURL,
      in: range,
      interaction: .invokeDefaultAction
    )
    #expect(result == true, "handler 返回 false 时应交还系统默认处理")
    #expect(handlerSpy.recordedURLs == [streamURL])
  }

  /// finish 与 promotion 后：终态块沿用同一 handler，不保留陈旧 callback。
  @Test("promotion 后终态块沿用同一 handler")
  func promotedBlocks_keepSameHandler() async throws {
    let handlerSpy = LinkHandlerSpy()
    var configuration = InkConfiguration.standard
    configuration.setLinkTapHandler(handlerSpy.handler, semanticIdentity: "test.promote.v1")

    let session = InkMarkdownRenderSession(configuration: configuration)
    session.append("[流式链接](https://example.com/stream) 结束前内容")
    session.finish()
    await waitForPromotion(session)
    #expect(session.isPromoted)

    // 终态块携带同一 handler：直接调用块上的 handler 等价于视图命中链接后的委托路径。
    let textBlocks = session.blocks.compactMap { $0 as? InkAttributedTextBlock }
    #expect(!textBlocks.isEmpty)
    for block in textBlocks {
      let handled = block.linkTapHandler?(streamURL, UIView())
      #expect(handled == true)
    }
    #expect(handlerSpy.recordedURLs.contains(streamURL))
  }

  /// 静态通道 configuration 更新：新 handler 生效，旧 handler 不再收到点击。
  @Test("configuration 更新后新 handler 生效")
  func configurationUpdate_installsNewHandler() throws {
    let oldSpy = LinkHandlerSpy()
    let newSpy = LinkHandlerSpy()

    var oldConfiguration = InkConfiguration.standard
    oldConfiguration.setLinkTapHandler(oldSpy.handler, semanticIdentity: "test.old.v1")
    var newConfiguration = InkConfiguration.standard
    newConfiguration.setLinkTapHandler(newSpy.handler, semanticIdentity: "test.new.v1")

    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    defer { coordinator.teardown(from: container) }

    coordinator.updateStatic(markdown: "[链接](https://example.com/a)", configuration: oldConfiguration)
    coordinator.updateStatic(markdown: "[链接](https://example.com/b)", configuration: newConfiguration)

    let textViews = allTextViews(in: container)
    #expect(!textViews.isEmpty)

    // 旧配置产生的视图已被替换；当前视图的委托走新 handler。
    var invokedOld = false
    var invokedNew = false
    oldSpy.onInvoke = { invokedOld = true }
    newSpy.onInvoke = { invokedNew = true }
    for textView in textViews {
      _ = textView.delegate?.textView?(
        textView,
        shouldInteractWith: URL(string: "https://example.com/b")!,
        in: NSRange(location: 0, length: 2),
        interaction: .invokeDefaultAction
      )
    }
    #expect(invokedNew)
    #expect(!invokedOld)
  }

  // MARK: - Helpers

  private func allTextViews(in view: UIView) -> [UITextView] {
    var result: [UITextView] = []
    if let textView = view as? UITextView {
      result.append(textView)
    }
    for subview in view.subviews {
      result.append(contentsOf: allTextViews(in: subview))
    }
    return result
  }

  private func attachStreaming(
    session: InkMarkdownRenderSession
  ) throws -> (InkMarkdownContainerView, InkMarkdownCoordinator) {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    coordinator.updateStreaming(session: session)
    return (container, coordinator)
  }

  /// 等待流式 remainder 文本视图挂载并出现链接文本。
  private func waitForStreamTextView(
    in container: InkMarkdownContainerView,
    coordinator: InkMarkdownCoordinator
  ) async throws -> UITextView {
    var elapsed: UInt64 = 0
    let stepNanoseconds: UInt64 = 10_000_000
    while elapsed < 2_000_000_000 {
      if let textView = findStreamTextView(in: container),
         textView.attributedText.string.contains("流式链接") {
        return textView
      }
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
          RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
          continuation.resume()
        }
      }
      elapsed += stepNanoseconds
    }
    throw TestFailure("流式文本视图未在超时前产出链接内容")
  }

  private func findStreamTextView(in view: UIView) -> UITextView? {
    if let textView = view as? UITextView, textView.attributedText.length > 0 {
      return textView
    }
    for subview in view.subviews {
      if let found = findStreamTextView(in: subview) {
        return found
      }
    }
    return nil
  }

  private func assertDelegateAsksHandler(
    textView: UITextView,
    linkText: String,
    expectedURL: URL,
    spy: LinkHandlerSpy
  ) throws {
    let nsString = textView.attributedText.string as NSString
    let range = nsString.range(of: linkText)
    try #require(range.location != NSNotFound)
    let attributedURL = try #require(
      textView.attributedText.attribute(.link, at: range.location, effectiveRange: nil) as? URL
    )
    #expect(attributedURL == expectedURL)

    let intercepted = textView.delegate?.textView?(
      textView,
      shouldInteractWith: expectedURL,
      in: range,
      interaction: .invokeDefaultAction
    )
    #expect(intercepted == false, "handler 返回 true 时应阻止系统默认行为")
    #expect(spy.recordedURLs.contains(expectedURL))
  }

  private func waitForPromotion(
    _ session: InkMarkdownRenderSession,
    timeoutNanoseconds: UInt64 = 3_000_000_000
  ) async {
    var elapsed: UInt64 = 0
    let stepNanoseconds: UInt64 = 10_000_000
    while !session.isPromoted, elapsed < timeoutNanoseconds {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
          RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
          continuation.resume()
        }
      }
      elapsed += stepNanoseconds
    }
  }
}

/// handler 间谍：记录回调 URL 并按配置返回是否接管。
@MainActor
private final class LinkHandlerSpy {
  var shouldHandle: Bool = true
  private(set) var recordedURLs: [URL] = []
  var onInvoke: (() -> Void)?

  init(shouldHandle: Bool = true) {
    self.shouldHandle = shouldHandle
  }

  var handler: @MainActor @Sendable (URL, UIView) -> Bool {
    let recorder = self
    return { [recorder] url, _ in
      recorder.recordedURLs.append(url)
      recorder.onInvoke?()
      return recorder.shouldHandle
    }
  }
}

private struct TestFailure: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}
