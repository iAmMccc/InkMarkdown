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
  func session_configurationIsSharedSnapshot() {
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
  func streamingView_loadsInUIHostingController() throws {
    let session = InkMarkdownRenderSession()
    session.append("## 流式测试标题\n分片1内容")

    let view = InkStreamMarkdownView(session: session)
    let host = renderInWindow(view)

    let container = try #require(findContainerView(in: host.view))
    #expect(container.subviews.contains(where: { $0 is UITextView }))
  }

  @Test("InkStreamMarkdownView body 驱动流式到终态生命周期")
  func streamView_streamingToPromotedLifecycle() async throws {
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
  func streamingThought_showsCollapsibleCard() throws {
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
  func streamingAppend_preservesCollapseInStreamView() async throws {
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

    let refreshedThought = try #require(container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)
    #expect(refreshedThought.isCollapsed == true)
    let collapsedSize = refreshedThought.sizeThatFits(CGSize(width: 320, height: 1000))
    #expect(collapsedSize.height <= 60)
  }

  @Test("promotion 后 InkStreamMarkdownView body 仍保留折叠态")
  func collapse_persistsAfterPromotionViaStreamViewBody() async throws {
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
  }

  @Test("无 PREFIX 思考时流式阶段仅单一 UITextView")
  func streamingView_withoutThoughtUsesSingleTextView() throws {
    let session = InkMarkdownRenderSession()
    session.append("## 普通流式\n正文")

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))

    #expect(container.subviews.filter { $0 is UITextView }.count == 1)
    #expect(container.subviews.contains(where: { $0 is InkThoughtBlockView }) == false)
  }

  @Test("挂载 Representable 后首次 append 思考标签即显示 thought 视图")
  func deferredThoughtAppend_showsThoughtViewAfterMount() throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    var hostDisplayUpdateCount = 0
    session.onDisplayUpdate = { hostDisplayUpdateCount += 1 }

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))
    #expect(container.subviews.contains(where: { $0 is InkThoughtBlockView }) == false)

    // 宿主可在 attachment 存续期间替换自己的公开 callback；adapter 观察者保持独立。
    session.onDisplayUpdate = { hostDisplayUpdateCount += 10 }
    session.append("<think>\n第一步分析")
    settleLayout(host)

    #expect(container.subviews.contains(where: { $0 is InkThoughtBlockView }))
    #expect(hostDisplayUpdateCount >= 10)
  }

  @Test("空会话不挂载 remainder，开始流式后挂载并保持")
  func insertingThought_mountsAndKeepsRemainderAttached() throws {
    let session = InkMarkdownRenderSession()
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container

    coordinator.updateStreaming(session: session)
    #expect(!container.subviews.contains(where: { type(of: $0) == UITextView.self }))

    session.append("<think>\n分析")
    #expect(container.subviews.contains(where: { $0 is InkThoughtBlockView }))
    #expect(container.subviews.contains(where: { type(of: $0) == UITextView.self }))

    session.append("\n</think>")
    #expect(container.subviews.contains(where: { type(of: $0) == UITextView.self }))

    session.append("\n\n正文")
    let remainder = try #require(
      container.subviews.first(where: { type(of: $0) == UITextView.self }) as? UITextView
    )
    #expect(remainder.superview === container)
  }

  @Test("同一 chunk 含 thought 与 remainder 同时挂载双槽")
  func mixedChunk_attachesThoughtAndRemainder() throws {
    let session = InkMarkdownRenderSession()
    session.append("<think>\n分析\n</think>\n\n## 回答")

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))
    settleLayout(host)

    #expect(container.subviews.contains(where: { $0 is InkThoughtBlockView }))
    #expect(container.subviews.contains(where: { $0 is UITextView }))
  }

  @Test("挂载后仅追加 thought 闭标签也刷新完成态")
  func closeOnlyThoughtChunk_refreshesCompletionState() throws {
    let session = InkMarkdownRenderSession()
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container

    session.append("<think>\n分析正文")
    coordinator.updateStreaming(session: session)
    let thoughtView = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    #expect(thoughtView.isComplete == false)

    session.append("</think>")

    let completedThoughtView = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    #expect(completedThoughtView.isComplete == true)
    #expect(
      completedThoughtView.headerContainer.accessibilityLabel
        == session.configuration.appearance.thought.completedTitle
    )
  }

  @Test("cancel 后流式 thought 视图被移除")
  func cancel_removesStreamingThoughtView() throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n分析")

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))
    settleLayout(host)
    #expect(container.subviews.contains(where: { $0 is InkThoughtBlockView }))

    session.cancel()
    settleLayout(host)

    #expect(container.subviews.contains(where: { $0 is InkThoughtBlockView }) == false)
  }

  @Test("session A→B 切换后折叠仅影响当前 session B")
  func sessionSwitch_collapseOnlyAffectsActiveSession() throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    config.appearance.thought.isInitiallyCollapsed = false

    let sessionA = InkMarkdownRenderSession(configuration: config)
    sessionA.append("<think>\n会话 A 思考")

    let sessionB = InkMarkdownRenderSession(configuration: config)
    sessionB.append("<think>\n会话 B 思考")

    let controller = SessionSwitchController(sessionA: sessionA, sessionB: sessionB)
    let host = renderInWindow(SessionSwitchHarness(controller: controller))
    let container = try #require(findContainerView(in: host.view))
    settleLayout(host)

    let thoughtA = try #require(container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)
    thoughtA.handleHeaderTap()
    #expect(thoughtA.isCollapsed)

    controller.useB = true
    settleLayout(host)

    let thoughtB = try #require(container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)
    #expect(thoughtB.isCollapsed == false)
    thoughtB.handleHeaderTap()
    #expect(thoughtB.isCollapsed)

    controller.useB = false
    settleLayout(host)
    let restoredThoughtA = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    #expect(restoredThoughtA.isCollapsed)
  }

  @Test("session A 切到空 B 会立即卸载复用 text view")
  func sessionSwitchToEmpty_unmountsReusedTextView() async {
    let sessionA = InkMarkdownRenderSession()
    sessionA.append("会话 A 正文")
    let sessionB = InkMarkdownRenderSession()
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container

    sessionA.renderer.charactersPerFrame = 100
    coordinator.updateStreaming(session: sessionA)
    let textView = container.subviews.first(where: { $0 is UITextView }) as? UITextView
    await waitForRunLoop { textView?.text.contains("会话 A") == true }
    #expect(textView?.text.contains("会话 A") == true)

    coordinator.updateStreaming(session: sessionB)

    #expect(!container.subviews.contains(where: { $0 is UITextView }))
  }

  @Test("session A 切到已有内容 B 后只显示并追加 B 内容")
  func sessionSwitchToNonEmpty_replacesReusedTextView() async {
    let sessionA = InkMarkdownRenderSession()
    sessionA.append("会话 A 正文")
    let sessionB = InkMarkdownRenderSession()
    sessionB.append("会话 B 正文")
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container

    sessionA.renderer.charactersPerFrame = 100
    coordinator.updateStreaming(session: sessionA)
    let textView = container.subviews.first(where: { $0 is UITextView }) as? UITextView
    await waitForRunLoop { textView?.text.contains("会话 A") == true }
    #expect(textView?.text.contains("会话 A") == true)

    sessionB.renderer.charactersPerFrame = 100
    coordinator.updateStreaming(session: sessionB)
    await waitForRunLoop {
      (container.subviews.first(where: { $0 is UITextView }) as? UITextView)?
        .text.contains("会话 B 正文") == true
    }
    var currentTextView = container.subviews.first(where: { $0 is UITextView }) as? UITextView
    #expect(currentTextView?.text.contains("会话 A") == false)
    #expect(currentTextView?.text.contains("会话 B 正文") == true)

    sessionB.append("，继续 B")
    await waitForRunLoop {
      (container.subviews.first(where: { $0 is UITextView }) as? UITextView)?
        .text.contains("会话 B 正文，继续 B") == true
    }
    currentTextView = container.subviews.first(where: { $0 is UITextView }) as? UITextView
    #expect(currentTextView?.text.contains("会话 A") == false)
    #expect(currentTextView?.text.contains("会话 B 正文，继续 B") == true)
  }

  @Test("流式 updateRenderEnvironment 后 thought 可见高度随 Dynamic Type 变化")
  func streamingEnvironmentUpdate_changesThoughtHeight() throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = false
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n" + String(repeating: "思考正文行。\n", count: 8))

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))
    settleLayout(host)

    let thoughtView = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    let width: CGFloat = 320
    let baseHeight = thoughtView.sizeThatFits(CGSize(width: width, height: 1000)).height
    #expect(baseHeight > 20)

    session.updateRenderEnvironment(InkRenderEnvironment(contentSizeCategory: .accessibilityExtraLarge))
    settleLayout(host)

    let updatedThoughtView = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    let axHeight = updatedThoughtView.sizeThatFits(CGSize(width: width, height: 1000)).height
    #expect(axHeight > baseHeight)
  }

  @Test("promotion 后挂载流式视图在无新流式事件时响应环境更新")
  func promotedStreamView_refreshesMountedPresentationAfterEnvironmentUpdate() async throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    config.appearance.thought.isInitiallyCollapsed = false
    let session = InkMarkdownRenderSession(configuration: config)
    session.append(
      "<think>\n"
        + String(repeating: "思考正文行。\n", count: 8)
        + "</think>\n\n正文"
    )

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))
    settleLayout(host)

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await waitForRunLoop { session.isPromoted }
    settleLayout(host)

    let promotedThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    let width: CGFloat = 320
    let baseHeight = promotedThought.sizeThatFits(
      CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    ).height
    let sourceBeforeEnvironmentUpdate = session.currentText

    session.updateRenderEnvironment(
      InkRenderEnvironment(contentSizeCategory: .accessibilityExtraLarge)
    )
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()

    let updatedThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    let updatedHeight = updatedThought.sizeThatFits(
      CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    ).height

    #expect(session.isPromoted)
    #expect(session.currentText == sourceBeforeEnvironmentUpdate)
    #expect(
      updatedThought.renderConfiguration.renderEnvironment.contentSizeCategory
        == .accessibilityExtraLarge
    )
    #expect(updatedThought.isCollapsed == false)
    #expect(updatedHeight > baseHeight)
    #expect(
      container.currentConfiguration?.renderEnvironment.contentSizeCategory
        == .accessibilityExtraLarge
    )
  }

  @Test("复用 Coordinator 时不同终态内容不会命中陈旧 block 缓存")
  func reusedCoordinator_rendersLatestBlocks() throws {
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

  private func settleLayout<V: View>(_ host: UIHostingController<V>) {
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
  }

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

@MainActor
private final class SessionSwitchController: ObservableObject {
  @Published var useB: Bool
  let sessionA: InkMarkdownRenderSession
  let sessionB: InkMarkdownRenderSession

  init(sessionA: InkMarkdownRenderSession, sessionB: InkMarkdownRenderSession, useB: Bool = false) {
    self.sessionA = sessionA
    self.sessionB = sessionB
    self.useB = useB
  }
}

private struct SessionSwitchHarness: View {
  @ObservedObject var controller: SessionSwitchController

  var body: some View {
    InkStreamMarkdownView(session: controller.useB ? controller.sessionB : controller.sessionA)
  }
}
