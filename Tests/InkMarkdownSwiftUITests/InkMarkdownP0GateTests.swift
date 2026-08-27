//
//  InkMarkdownP0GateTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import SwiftUI
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("SwiftUI Adapter P0 闸门")
@MainActor
struct InkMarkdownP0GateTests {

  @Test("静态长文 sizeThatFits 次数不超过块数且 layout 不再 sizeThatFits")
  func staticLongDocumentMeasureOncePerBlock() throws {
    let markdown = Self.longStaticFixture
    let blocks = InkBlockRenderer.render(markdown, configuration: .standard)
    let container = InkMarkdownContainerView()
    container.updateBlocks(blocks, configuration: .standard, documentEpoch: InkDocumentEpoch.hash(markdown))

    let width: CGFloat = 360
    _ = container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    #expect(container.blockMeasurementInvocationCount <= blocks.count)

    let beforeLayout = container.blockMeasurementInvocationCount
    container.frame = CGRect(x: 0, y: 0, width: width, height: container.cachedTotalHeightForTesting)
    container.setNeedsLayout()
    container.layoutIfNeeded()

    #expect(container.blockMeasurementInvocationCount == beforeLayout)
    #expect(container.layoutSubviewsICSInvalidateCount == 0)
  }

  @Test("宽度变化仅在前缀 measure 入口重测一次")
  func widthChangeRemeasuresAtMeasureEntryOnly() {
    let blocks = InkBlockRenderer.render("# Title\n\nBody paragraph.", configuration: .standard)
    let container = InkMarkdownContainerView()
    container.updateBlocks(blocks, configuration: .standard)

    _ = container.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
    let count320 = container.blockMeasurementInvocationCount
    #expect(count320 <= blocks.count)
    #expect(count320 >= 1)

    _ = container.sizeThatFits(CGSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
    let count400 = container.blockMeasurementInvocationCount
    #expect(count400 <= blocks.count)
    #expect(count400 >= count320)

    container.frame = CGRect(x: 0, y: 0, width: 400, height: container.cachedTotalHeightForTesting)
    container.resetLayoutSubviewsICSInvalidateCountForTesting()
    container.layoutIfNeeded()

    #expect(container.blockMeasurementInvocationCount == count400)
    #expect(container.layoutSubviewsICSInvalidateCount == 0)
  }

  @Test("流式后缀 append 仅重测 stream text 槽")
  func streamingSuffixAppendMeasuresSingleSlot() throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container

    session.append(
      "<think>\n分析步骤\n</think>\n\n# Stream\n\nPrefix paragraph with enough text to establish a measurable baseline."
    )
    coordinator.updateStreaming(session: session)

    let width: CGFloat = 360
    let thoughtIdentity = try #require(session.streamingThought?.blockIdentity)
    let textIdentity = InkBlockIdentity(
      documentEpoch: session.streamingSlotEpoch,
      blockIndex: -1,
      kind: InkStreamingSlotKind.streamText
    )

    var prefixHeight: CGFloat = 0
    let settleDeadline = Date().addingTimeInterval(3)
    while Date() < settleDeadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
      coordinator.updateStreaming(session: session)
      prefixHeight = container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
      if prefixHeight > 40 { break }
    }
    #expect(prefixHeight > 40)

    let prefixCount = container.blockMeasurementInvocationCount
    #expect(prefixCount >= 2)

    let prefixThoughtHeight = try #require(container.cachedSlotHeight(for: thoughtIdentity, width: width))
    let prefixTextHeight = try #require(container.cachedSlotHeight(for: textIdentity, width: width))
    let reservedUpdatesBefore = container.reservedHeightSlotUpdateCount

    session.append("\n\nSuffix paragraph adds another block line.")
    coordinator.updateStreaming(session: session)

    let textView = try #require(
      container.subviews.compactMap { $0 as? UITextView }.first
    )
    let contentDeadline = Date().addingTimeInterval(5)
    while !textView.text.contains("Suffix paragraph"), Date() < contentDeadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }
    #expect(textView.text.contains("Suffix paragraph"))

    let updateDeadline = Date().addingTimeInterval(5)
    while container.reservedHeightSlotUpdateCount <= reservedUpdatesBefore, Date() < updateDeadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
      coordinator.updateStreaming(session: session)
    }
    #expect(container.reservedHeightSlotUpdateCount > reservedUpdatesBefore)

    let growDeadline = Date().addingTimeInterval(5)
    var suffixHeight = prefixHeight
    var suffixTextHeight = prefixTextHeight
    while Date() < growDeadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
      coordinator.updateStreaming(session: session)
      suffixHeight = container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
      suffixTextHeight = container.cachedSlotHeight(for: textIdentity, width: width) ?? suffixTextHeight
      if suffixHeight > prefixHeight, suffixTextHeight > prefixTextHeight { break }
    }
    #expect(suffixHeight > prefixHeight)

    let suffixCount = container.blockMeasurementInvocationCount
    #expect(suffixCount <= 1)
    #expect(prefixCount >= suffixCount)

    let suffixThoughtHeight = try #require(container.cachedSlotHeight(for: thoughtIdentity, width: width))
    #expect(suffixThoughtHeight == prefixThoughtHeight)
    #expect(suffixTextHeight > prefixTextHeight)
  }

  @Test("非首块 thought 在 updateBlocks identity diff 中复用视图")
  func nonFirstThoughtBlockReusesViewOnSecondUpdate() throws {
    let markdown = """
    前置段落文本。

    <think>
    分析步骤
    </think>
    """
    let epoch = InkDocumentEpoch.hash(markdown)
    let blocks = InkBlockRenderer.render(markdown, configuration: .standard)
    let thoughtIndex = try #require(blocks.firstIndex(where: { $0 is InkThoughtBlock }))
    #expect(thoughtIndex > 0)

    let container = InkMarkdownContainerView()
    container.updateBlocks(blocks, configuration: .standard, documentEpoch: epoch)

    let thoughtView = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    let pointer = ObjectIdentifier(thoughtView)

    container.updateBlocks(blocks, configuration: .standard, documentEpoch: epoch)

    let reusedThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    #expect(ObjectIdentifier(reusedThought) == pointer)
  }

  @Test("promotion 后 PREFIX thought 视图指针连续")
  func promotedPrefixThoughtPreservesIdentity() async throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n分析步骤")

    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container
    coordinator.updateStreaming(session: session)

    let streamingThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    let pointer = ObjectIdentifier(streamingThought)

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    try await waitForPromotion(session)

    coordinator.updateStreaming(session: session)

    let promotedThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    #expect(ObjectIdentifier(promotedThought) == pointer)
  }

  @Test("流式 append 不触发 isPromoted")
  func streamingAppendDoesNotPromote() {
    let session = InkMarkdownRenderSession()
    _ = InkStreamMarkdownView(session: session)
    session.append("delta-1")
    session.append("delta-2")
    #expect(session.isPromoted == false)
    #expect(session.state == .streaming)
  }

  @Test("Trait 变化触发一次前缀重测")
  func traitChangeTriggersPrefixRemeasure() {
    let markdown = "# Trait"
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container

    var large = InkConfiguration.standard
    large.renderEnvironment = InkRenderEnvironment(contentSizeCategory: .large)
    coordinator.updateStatic(markdown: markdown, configuration: large)
    _ = container.sizeThatFits(CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude))

    var ax = InkConfiguration.standard
    ax.renderEnvironment = InkRenderEnvironment(contentSizeCategory: .accessibilityLarge)
    coordinator.updateStatic(markdown: markdown, configuration: ax)
    _ = container.sizeThatFits(CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude))

    #expect(container.blockMeasurementInvocationCount >= 1)
  }

  @Test("reset 后流式 slot epoch 递增且不复用旧槽 cache")
  func resetIsolatesStreamingSlotCache() throws {
    let session = InkMarkdownRenderSession()
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container
    let width: CGFloat = 360

    let longBody = String(repeating: "Long paragraph line for cache baseline.\n\n", count: 24)
    session.append("# Long Stream\n\n\(longBody)")
    coordinator.updateStreaming(session: session)

    var settled = false
    let settleDeadline = Date().addingTimeInterval(3)
    while Date() < settleDeadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
      coordinator.updateStreaming(session: session)
      if container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height > 80 {
        settled = true
        break
      }
    }
    #expect(settled)

    let epoch0 = session.streamingSlotEpoch
    #expect(epoch0 == 0)
    let identity0 = InkBlockIdentity(
      documentEpoch: epoch0,
      blockIndex: -1,
      kind: InkStreamingSlotKind.streamText
    )
    let height0 = try #require(container.cachedSlotHeight(for: identity0, width: width))
    #expect(height0 > 40)

    session.reset()
    coordinator.updateStreaming(session: session)
    let resetWindowHeight = container.sizeThatFits(
      CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    ).height
    #expect(resetWindowHeight < height0)
    #expect(session.streamingSlotEpoch == 1)
    #expect(session.streamingSlotEpoch != epoch0)

    session.append("# Hi\n\nShort.")
    coordinator.updateStreaming(session: session)
    #expect(session.streamingSlotEpoch == 1)

    let identity1 = InkBlockIdentity(
      documentEpoch: session.streamingSlotEpoch,
      blockIndex: -1,
      kind: InkStreamingSlotKind.streamText
    )
    let height1 = try #require(container.cachedSlotHeight(for: identity1, width: width))
    #expect(height1 < height0)
    #expect(container.cachedSlotHeight(for: identity0, width: width) == height0)

    container.invalidateMeasurementSlot(identity: identity1, width: width)
    _ = container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    #expect(container.blockMeasurementInvocationCount >= 1)
  }

  @Test("cancel 后窗口期不得复用上一条流槽高")
  func cancelWindowDoesNotReusePriorStreamSlotHeight() throws {
    let session = InkMarkdownRenderSession()
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container
    let width: CGFloat = 360

    let longBody = String(repeating: "Cancel baseline paragraph.\n\n", count: 24)
    session.append("# Cancel Stream\n\n\(longBody)")
    coordinator.updateStreaming(session: session)

    var settled = false
    let settleDeadline = Date().addingTimeInterval(3)
    while Date() < settleDeadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
      coordinator.updateStreaming(session: session)
      if container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height > 80 {
        settled = true
        break
      }
    }
    #expect(settled)

    let priorHeight = container.sizeThatFits(
      CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    ).height
    #expect(priorHeight > 40)

    session.cancel()
    coordinator.updateStreaming(session: session)
    let cancelWindowHeight = container.sizeThatFits(
      CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    ).height
    #expect(cancelWindowHeight < priorHeight)
    #expect(session.state == .cancelled)
  }

  @Test("流式 thought 正文增长仅更新 thought 槽")
  func streamingThoughtBodyGrowthUpdatesThoughtSlotOnly() throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container
    let width: CGFloat = 360

    session.append("<think>\n步骤一")
    coordinator.updateStreaming(session: session)
    _ = container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))

    let textIdentity = InkBlockIdentity(
      documentEpoch: session.streamingSlotEpoch,
      blockIndex: -1,
      kind: InkStreamingSlotKind.streamText
    )
    let thoughtView = try #require(
      container.subviews.compactMap { $0 as? InkThoughtBlockView }.first
    )
    let prefixThoughtHeight = thoughtView.sizeThatFits(
      CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    ).height
    let prefixStreamTextHeight = container.cachedSlotHeight(for: textIdentity, width: width) ?? 0
    let reservedBeforeThoughtAppend = container.reservedHeightSlotUpdateCount

    session.append("\n" + String(repeating: "步骤二：详细分析。\n", count: 6))

    let contentDeadline = Date().addingTimeInterval(3)
    while !(session.streamingThought?.thought.contains("步骤二") ?? false), Date() < contentDeadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }
    #expect(session.streamingThought?.thought.contains("步骤二") == true)

    let reservedThoughtDelta = container.reservedHeightSlotUpdateCount - reservedBeforeThoughtAppend
    #expect(reservedThoughtDelta == 1)

    let suffixThoughtHeight = thoughtView.sizeThatFits(
      CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    ).height
    #expect(suffixThoughtHeight > prefixThoughtHeight)

    let suffixStreamTextHeight = container.cachedSlotHeight(for: textIdentity, width: width) ?? 0
    #expect(suffixStreamTextHeight == prefixStreamTextHeight)
  }

  @Test("iOS 14 ICS 回传高度", .disabled("本机无 iOS 14 Simulator runtime，未交付"))
  func ios14ICSHeightNotDelivered() {
    Issue.record("iOS 14 ICS 回传高度需在 iOS 14 runtime 上实测；当前环境未交付")
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

  private static let longStaticFixture: String = {
    var parts: [String] = ["# 长文测量闸门"]
    for index in 0..<8 {
      parts.append("## Section \(index)")
      parts.append("段落 \(index)：用于验证单次测量与 layout 不再 sizeThatFits。")
      parts.append("```swift\nlet value\(index) = \(index)\n```")
    }
    parts.append("| Col | Val |\n|---|---|\n| A | 1 |")
    return parts.joined(separator: "\n\n")
  }()
}
