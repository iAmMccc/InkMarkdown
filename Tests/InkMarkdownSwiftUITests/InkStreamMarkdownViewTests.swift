//
//  InkStreamMarkdownViewTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import SwiftUI
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("InkStreamMarkdownView 流式视图契约与集成测试")
@MainActor
struct InkStreamMarkdownViewTests {

  /// 等待 deferred @Published 写入在下一 runloop 生效。
  private func waitForRunLoop(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    stepNanoseconds: UInt64 = 10_000_000,
    _ condition: () -> Bool
  ) async {
    var elapsed: UInt64 = 0
    while !condition(), elapsed < timeoutNanoseconds {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
          RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
          continuation.resume()
        }
      }
      try? await Task.sleep(nanoseconds: stepNanoseconds)
      elapsed += stepNanoseconds
    }
  }

  @Test("InkStreamMarkdownView 绑定 session 并共享唯一配置真相")
  func sessionConfigurationIsSharedSnapshot() {
    var config = InkConfiguration.standard
    config.appearance.text.fontSize = 21
    let session = InkMarkdownRenderSession(configuration: config)
    _ = InkStreamMarkdownView(session: session)

    #expect(session.configuration.appearance.text.fontSize == 21)
    #expect(session.renderer.configuration.appearance.text.fontSize == 21)
    #expect(session.isPromoted == false)
    #expect(session.state == .idle)
  }

  @Test("InkStreamMarkdownView 在 UIHostingController 中完成流式装载")
  func streamingViewLoadsInUIHostingController() throws {
    let session = InkMarkdownRenderSession()
    session.append("## 流式测试标题\n分片1内容")

    let view = InkStreamMarkdownView(session: session)
    let host = renderInWindow(view)

    let container = try #require(findContainerView(in: host.view))
    #expect(container.subviews.contains(where: { $0 is UITextView }))
  }

  @Test("InkStreamMarkdownView body 驱动流式到终态生命周期")
  func streamViewBodyStreamingToPromotedLifecycle() async throws {
    let session = InkMarkdownRenderSession()
    session.append("## 实时标题\n内容第一段")

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))
    #expect(container.subviews.contains(where: { $0 is UITextView }))

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()

    await waitForRunLoop { session.state == .finished && session.isPromoted }
    #expect(session.isPromoted == true)
    #expect(!session.blocks.isEmpty)

    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    #expect(container.hasBlocks == true)
    #expect(!container.subviews.contains(where: { type(of: $0) == UITextView.self }))
  }

  @Test("PREFIX 思考流式阶段挂载可折叠 InkThoughtBlockView")
  func streamingThoughtPrefixShowsCollapsibleCard() throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n第一步分析")

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))

    let thoughtView = try #require(container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)
    #expect(thoughtView.isComplete == false)
    #expect(thoughtView.config.isCollapsible == true)
  }

  @Test("流式 append 后 InkStreamMarkdownView 仍保留折叠态")
  func streamingAppendPreservesCollapseInStreamView() async throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    config.appearance.thought.isInitiallyCollapsed = false
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n深度分析")

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))
    let thoughtView = try #require(container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)
    #expect(thoughtView.isCollapsed == false)

    thoughtView.handleHeaderTap()
    session.append("\n追加思考")
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    #expect(session.streamingThought?.isCollapsed == true)
    let refreshedThought = try #require(container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)
    #expect(refreshedThought.isCollapsed == true)
    let collapsedSize = refreshedThought.sizeThatFits(CGSize(width: 320, height: 1000))
    #expect(collapsedSize.height <= 60)
  }

  @Test("promotion 后 InkStreamMarkdownView body 仍保留折叠态")
  func collapsePreservedAfterPromotionViaStreamViewBody() async throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    config.appearance.thought.isInitiallyCollapsed = false
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n深度分析\n</think>\n\n## 回答\n正文")

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))
    let thoughtView = try #require(container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)
    #expect(thoughtView.isCollapsed == false)

    thoughtView.handleHeaderTap()
    #expect(session.streamingThought?.isCollapsed == true)

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await waitForRunLoop { session.isPromoted }

    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    let promotedThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    #expect(promotedThought.isCollapsed == true)
    if let block = session.blocks.first as? InkThoughtBlock {
      #expect(block.isCollapsed == true)
    }
  }

  @Test("无 PREFIX 思考时流式阶段仅单一 UITextView")
  func streamingWithoutThoughtUsesSingleTextView() throws {
    let session = InkMarkdownRenderSession()
    session.append("## 普通流式\n正文")

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))

    #expect(container.subviews.filter { $0 is UITextView }.count == 1)
    #expect(container.subviews.contains(where: { $0 is InkThoughtBlockView }) == false)
  }

  @Test("复用 Coordinator 时不同终态内容不会命中陈旧 block 缓存")
  func reusedCoordinatorRendersLatestBlocks() throws {
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container

    coordinator.updateBlocks(InkBlockRenderer.render("第一条消息"), configuration: .standard)
    coordinator.updateBlocks(InkBlockRenderer.render("第二条消息"), configuration: .standard)

    let textView = try #require(container.subviews.first(where: { $0 is UITextView }) as? UITextView)
    #expect(textView.attributedText.string.contains("第二条消息"))
    #expect(!textView.attributedText.string.contains("第一条消息"))
  }

  // MARK: - Helpers

  private func renderInWindow<V: View>(_ view: V) -> UIHostingController<V> {
    let host = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    return host
  }

  private func findContainerView(in view: UIView) -> InkMarkdownContainerView? {
    if let container = view as? InkMarkdownContainerView {
      return container
    }
    for sub in view.subviews {
      if let found = findContainerView(in: sub) {
        return found
      }
    }
    return nil
  }
}
