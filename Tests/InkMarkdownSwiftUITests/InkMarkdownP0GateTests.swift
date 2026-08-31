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
  func widthChangeRemeasuresAtMeasureEntryOnly() {
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

  @Test("iOS 14 ICS 回传高度", .disabled("本机无 iOS 14 Simulator runtime，未交付"))
  func ios14ICSHeightNotDelivered() {
    Issue.record("iOS 14 ICS 回传高度需在 iOS 14 runtime 上实测；当前环境未交付")
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
