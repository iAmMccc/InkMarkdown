//
//  InkMarkdownViewTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import SwiftUI
@testable import InkMarkdownSwiftUI
import InkMarkdown

@Suite("InkMarkdownView 静态视图契约测试")
@MainActor
struct InkMarkdownViewTests {

  @Test("InkMarkdownView 支持具名与省略参数初始化")
  func initializationWithMarkdownOnly() {
    let markdown = "## 标题\n这是一段测试正文。"
    _ = InkMarkdownView(markdown: markdown).body
    _ = InkMarkdownView(markdown).body
  }

  @Test("InkMarkdownView 可接受显式 configuration")
  func initializationWithConfiguration() {
    var config = InkConfiguration.standard
    config.appearance.text.fontSize = 19
    config.appearance.heading.h1FontSize = 25

    let markdown = "# 带有自定义配置的标题\n正文内容。"
    _ = InkMarkdownView(markdown: markdown, configuration: config).body
    _ = InkMarkdownView(markdown, configuration: config).body
  }

  @Test("相同 Markdown 在配置变化时会重新生成静态块")
  func staticConfigurationChangeRerenders() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container

    coordinator.updateStatic(markdown: "原始文本", configuration: .standard)
    let initialTextView = try #require(container.subviews.first as? UITextView)
    #expect(initialTextView.attributedText.string.contains("原始文本"))

    var filteredConfiguration = InkConfiguration.standard
    filteredConfiguration.sourceFilter = { _ in "配置已变更" }
    coordinator.updateStatic(markdown: "原始文本", configuration: filteredConfiguration)

    let updatedTextView = try #require(container.subviews.first as? UITextView)
    #expect(updatedTextView.attributedText.string.contains("配置已变更"))
  }

  @Test("InkMarkdownView 可与 inkConfiguration 修饰符组合构建")
  func modifierComposition() {
    var customConfig = InkConfiguration.standard
    customConfig.appearance.text.fontSize = 18

    let view = InkMarkdownView("### Markdown 内容")
      .inkConfiguration(customConfig)
    _ = view
  }
}
