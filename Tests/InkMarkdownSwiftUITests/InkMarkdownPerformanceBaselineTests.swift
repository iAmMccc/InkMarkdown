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

  @Test("流式 append 不触发 SwiftUI body 级 blocks 切换")
  func streamingAppend_doesNotPromoteEarly() {
    let session = InkMarkdownRenderSession()
    _ = InkStreamMarkdownView(session: session)

    session.append("第一片")
    session.append("第二片")

    #expect(session.isPromoted == false)
    #expect(session.state == .streaming)
  }

  @Test("Dynamic Type 档位变化触发 Coordinator 重测")
  func dynamicType_triggersRemeasure() throws {
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
}
