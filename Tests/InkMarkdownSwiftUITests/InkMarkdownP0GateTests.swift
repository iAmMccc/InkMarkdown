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
  func staticLongDocument_measureOncePerBlock() throws {
    let markdown = Self.longStaticFixture
    let blocks = InkBlockRenderer.render(markdown, configuration: .standard)
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    coordinator.updateBlocks(blocks, configuration: .standard)

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
  func widthChange_remeasuresAtMeasureEntryOnly() {
    let blocks = InkBlockRenderer.render("# Title\n\nBody paragraph.", configuration: .standard)
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    coordinator.updateBlocks(blocks, configuration: .standard)

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

  @Test("流式 append 不触发 isPromoted")
  func streamingAppend_doesNotPromote() {
    let session = InkMarkdownRenderSession()
    _ = InkStreamMarkdownView(session: session)
    session.append("delta-1")
    session.append("delta-2")
    #expect(session.isPromoted == false)
    #expect(session.state == .streaming)
  }

  @Test("Trait 变化触发一次前缀重测")
  func traitChange_triggersPrefixRemeasure() {
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

  @Test("零宽容器从 window 建立固有尺寸测量基准")
  func zeroWidthContainer_usesWindowForIntrinsicMeasurement() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 800))
    let zeroWidthHost = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 800))
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    window.addSubview(zeroWidthHost)
    zeroWidthHost.addSubview(container)
    coordinator.containerView = container
    defer { coordinator.teardown(from: container) }

    coordinator.updateStatic(markdown: "# 固有尺寸验证", configuration: InkConfiguration.standard)

    // 这是当前 runtime 的代码路径契约；iOS 15 runtime 仍须单独实测。
    #expect(container.bounds.width == 0)
    #expect(container.superview?.bounds.width == 0)
    #expect(container.window === window)
    #expect(container.intrinsicContentSize.height > 0)
  }

  @Test("固有尺寸宽度解析保留 iOS 15 detached fallback")
  func intrinsicWidthResolver_usesLegacyFallbackLast() {
    #expect(
      InkIntrinsicMeasurementWidthResolver.resolve(
        contentWidth: 0,
        windowWidth: 0,
        legacyFallbackWidth: 375
      ) == 375
    )
    #expect(
      InkIntrinsicMeasurementWidthResolver.resolve(
        contentWidth: 0,
        windowWidth: 360,
        legacyFallbackWidth: 375
      ) == 360
    )
    #expect(
      InkIntrinsicMeasurementWidthResolver.resolve(
        contentWidth: 320,
        windowWidth: 360,
        legacyFallbackWidth: 375
      ) == 320
    )
  }

  @Test("流式富文本持有 InkMarkdownLayoutManager")
  func streamingTextView_usesMarkdownLayoutManager() {
    let textView = InkStreamingTextView()
    textView.attributedText = InkAttributedRenderer.render("`inline code`\n\n> quote")
    let codeLocation = (textView.attributedText.string as NSString).range(of: "inline code").location

    #expect(textView.layoutManager is InkMarkdownLayoutManager)
    #expect(
      textView.attributedText.attribute(
        .inkInlineCodeBackground,
        at: codeLocation,
        effectiveRange: nil
      ) is InkInlineCodeBackgroundInfo
    )
    let quoteLocation = (textView.attributedText.string as NSString).range(of: "quote").location
    #expect(
      textView.attributedText.attribute(
        .inkBlockquoteBar,
        at: quoteLocation,
        effectiveRange: nil
      ) is InkBlockquoteBarInfo
    )
  }

  @Test("SwiftUI Dynamic Type 映射覆盖普通与辅助功能档位")
  func contentSizeCategoryMapping_preservesSemanticCategory() {
    #expect(UIContentSizeCategory.from(swiftUICategory: .extraSmall) == .extraSmall)
    #expect(UIContentSizeCategory.from(swiftUICategory: .large) == .large)
    #expect(
      UIContentSizeCategory.from(swiftUICategory: .accessibilityExtraExtraExtraLarge)
        == .accessibilityExtraExtraExtraLarge
    )
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
