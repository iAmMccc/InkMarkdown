//
//  InkMarkdownAccessibilityTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import SwiftUI
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("SwiftUI Adapter 可访问性契约")
@MainActor
struct InkMarkdownAccessibilityTests {

  @Test("思考块折叠控件具备 VoiceOver 可访问性标签")
  func thoughtBlockHasAccessibilityLabel() throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n步骤一")

    let host = renderInWindow(InkStreamMarkdownView(session: session))
    let container = try #require(findContainerView(in: host.view))
    let thoughtView = try #require(container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView)

    #expect(thoughtView.headerContainer.isAccessibilityElement)
    #expect(thoughtView.headerContainer.accessibilityLabel != nil)
  }

  @Test("Dynamic Type 环境写入 renderEnvironment 并影响思考块测量高度")
  func dynamicTypeAffectsMeasuredHeight() throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = false
    let thoughtMarkdown = "<think>\nDynamic Type 思考正文测试。"

    var large = config
    large.renderEnvironment = InkRenderEnvironment(contentSizeCategory: .large)
    let largeBlocks = InkBlockRenderer.render(thoughtMarkdown, configuration: large)
    let largeContainer = InkMarkdownContainerView()
    largeContainer.updateBlocks(largeBlocks, configuration: large)
    let largeHeight = largeContainer.sizeThatFits(CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)).height

    var ax = config
    ax.renderEnvironment = InkRenderEnvironment(contentSizeCategory: .accessibilityLarge)
    let axBlocks = InkBlockRenderer.render(thoughtMarkdown, configuration: ax)
    let axContainer = InkMarkdownContainerView()
    axContainer.updateBlocks(axBlocks, configuration: ax)
    let axHeight = axContainer.sizeThatFits(CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)).height

    #expect(axHeight >= largeHeight)
  }

  private func renderInWindow<V: View>(_ view: V) -> UIHostingController<V> {
    let host = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.frame = window.bounds
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    return host
  }

  private func findContainerView(in view: UIView) -> InkMarkdownContainerView? {
    if let container = view as? InkMarkdownContainerView { return container }
    for sub in view.subviews {
      if let found = findContainerView(in: sub) { return found }
    }
    return nil
  }
}
