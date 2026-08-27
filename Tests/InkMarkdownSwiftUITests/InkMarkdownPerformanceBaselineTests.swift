//
//  InkMarkdownPerformanceBaselineTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import SwiftUI
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("SwiftUI Adapter 性能基线回归")
@MainActor
struct InkMarkdownPerformanceBaselineTests {

  @Test("静态二次 updateStatic 复用块视图指针")
  func staticUpdateReusesBlockViews() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container

    let markdown = """
    # 标题
    正文段落。
    ```swift
    let x = 1
    ```
    """

    coordinator.updateStatic(markdown: markdown, configuration: .standard)
    let firstPointers = container.subviews.map { ObjectIdentifier($0) }

    coordinator.updateStatic(markdown: markdown, configuration: .standard)
    let secondPointers = container.subviews.map { ObjectIdentifier($0) }

    #expect(firstPointers == secondPointers)
  }

  @Test("流式 append 不触发 SwiftUI body 级 blocks 切换")
  func streamingAppendDoesNotPromoteEarly() {
    let session = InkMarkdownRenderSession()
    _ = InkStreamMarkdownView(session: session)

    session.append("第一片")
    session.append("第二片")

    #expect(session.isPromoted == false)
    #expect(session.state == .streaming)
  }

  @Test("promotion 后思考块视图 identity 连续")
  func promotedThoughtPreservesViewIdentity() async throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n分析中")

    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container
    coordinator.updateStreaming(session: session)

    let streamingThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    let streamingPointer = ObjectIdentifier(streamingThought)

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()

    try await waitForPromotion(session)

    coordinator.updateStreaming(session: session)
    let promotedThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )

    #expect(ObjectIdentifier(promotedThought) == streamingPointer)
    #expect(!container.subviews.contains(where: { type(of: $0) == UITextView.self && $0 !== streamingThought }))
  }

  @Test("Dynamic Type 档位变化触发 Coordinator 重测")
  func dynamicTypeChangeTriggersRemeasure() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container

    let markdown = "# Dynamic Type"

    var largeConfig = InkConfiguration.standard
    largeConfig.renderEnvironment = InkRenderEnvironment(contentSizeCategory: .large)
    coordinator.updateStatic(markdown: markdown, configuration: largeConfig)
    _ = container.sizeThatFits(CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude))

    var axConfig = InkConfiguration.standard
    axConfig.renderEnvironment = InkRenderEnvironment(contentSizeCategory: .accessibilityExtraExtraExtraLarge)
    #expect(!largeConfig.isSemanticallyEqualTo(axConfig))

    coordinator.updateStatic(markdown: markdown, configuration: axConfig)
    _ = container.sizeThatFits(CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude))

    #expect(container.blockMeasurementInvocationCount >= 1, "档位变化应触发至少一次块级重测")
  }

  private func waitForPromotion(_ session: InkMarkdownRenderSession) async throws {
    var elapsed: UInt64 = 0
    while !session.isPromoted, elapsed < 1_000_000_000 {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
          RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
          continuation.resume()
        }
      }
      try await Task.sleep(nanoseconds: 10_000_000)
      elapsed += 10_000_000
    }
    #expect(session.isPromoted)
  }
}
