//
//  InkMarkdownAdapterWorkloadTests.swift
//  InkMarkdownSwiftUITests
//
//  单环境（当前 Simulator / 构建配置）回归闸门：捕获测量路径退化或流式/promotion 明显变慢。
//  不是跨设备 FPS/hitch 签收，也不是生产级性能承诺。
//

import Testing
import UIKit
import SwiftUI
import InkMarkdownSemanticCorpus
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("SwiftUI Adapter 工作负载回归闸门")
@MainActor
struct InkMarkdownAdapterWorkloadTests {

  @Test("静态布局与折叠复用语义块，只有内容或配置更新重新解析")
  func staticPresentation_parsesOnlyOnSemanticInputChange() throws {
    var documentParseCount = 0
    var configuration = InkConfiguration.standard
    configuration.appearance.thought.isCollapsible = true
    configuration.sourceFilter = { source in
      if source.hasPrefix("<think>") { documentParseCount += 1 }
      return source
    }
    let markdown = "<think>分析步骤</think>\n\n# 标题\n\n正文"
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    defer { coordinator.teardown() }

    coordinator.updateStatic(markdown: markdown, configuration: configuration)
    #expect(documentParseCount == 1)
    let thoughtView = try #require(container.subviews.compactMap { $0 as? InkThoughtBlockView }.first)
    let wasCollapsed = thoughtView.isCollapsed
    thoughtView.handleHeaderTap()
    #expect(thoughtView.isCollapsed != wasCollapsed)

    for width: CGFloat in [360, 744, 360] {
      let size = container.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
      #expect(size.height > 0)
      coordinator.updateStatic(markdown: markdown, configuration: configuration)
      #expect(documentParseCount == 1, "测量和交互不应重新进入文档解析")
    }
    #expect(thoughtView.isCollapsed != wasCollapsed)

    coordinator.updateStatic(markdown: markdown + "更新", configuration: configuration)
    #expect(documentParseCount == 2)
    configuration.appearance.text.fontSize += 1
    coordinator.updateStatic(markdown: markdown + "更新", configuration: configuration)
    #expect(documentParseCount == 3)

    coordinator.updateBlocks([], configuration: configuration)
    coordinator.updateStatic(markdown: markdown, configuration: configuration)
    #expect(documentParseCount == 4, "blocks 入口切回 Markdown 时必须生成新语义输入")
  }

  @Test("静态长文首测块数有界且同宽二次测量为 0")
  func staticLongDocument_measurementBudget() throws {
    let markdown = Self.workloadStaticMarkdown
    let blocks = InkBlockRenderer.render(markdown, configuration: .standard)
    #expect(blocks.count >= 60)

    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    coordinator.updateBlocks(blocks, configuration: .standard)

    let width: CGFloat = 360
    let start = CACurrentMediaTime()
    _ = container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    let firstMeasureElapsed = CACurrentMediaTime() - start

    #expect(container.blockMeasurementInvocationCount <= blocks.count)
    #expect(firstMeasureElapsed < 2.0, "首测耗时 \(String(format: "%.0f", firstMeasureElapsed * 1000))ms 超过 2000ms 宽松上限")

    _ = container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    #expect(container.blockMeasurementInvocationCount == 0)
  }

  @Test("流式百片 append 显示追上有界且仅测量当前 remainder slot")
  func streamingChunkAppend_workloadBudget() throws {
    let session = InkMarkdownRenderSession()
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container
    let width: CGFloat = 360

    let chunkCount = 100
    _ = container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))

    let appendStart = CACurrentMediaTime()
    for index in 0..<chunkCount {
      session.append("Chunk-\(index) ")
      coordinator.updateStreaming(session: session)
    }

    let textView = try #require(
      container.subviews.compactMap { $0 as? UITextView }.first
    )
    let catchUpDeadline = Date().addingTimeInterval(20)
    while !textView.text.contains("Chunk-99"), Date() < catchUpDeadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
      coordinator.updateStreaming(session: session)
    }
    #expect(textView.text.contains("Chunk-99"))

    let catchUpElapsed = CACurrentMediaTime() - appendStart
    #expect(catchUpElapsed < 25.0, "百片追显示耗时 \(String(format: "%.0f", catchUpElapsed * 1000))ms 超过 25000ms 宽松上限")

    _ = container.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    #expect(container.blockMeasurementInvocationCount <= 1)
  }

  @Test("finish→promotion 时长有界且终态 Thought 可交互")
  func promotion_workloadCompletesWithInteractiveThought() async throws {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n分析步骤\n</think>\n\n# Stream\n\nBody for promotion.")

    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView()
    coordinator.containerView = container
    coordinator.updateStreaming(session: session)

    _ = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )

    let promotionStart = CACurrentMediaTime()
    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    #expect(
      await InkAsyncTestProbe.wait(timeoutNanoseconds: 3_000_000_000) {
        session.isPromoted
      }
    )
    let promotionElapsed = CACurrentMediaTime() - promotionStart
    #expect(promotionElapsed < 30.0, "promotion 耗时 \(String(format: "%.0f", promotionElapsed * 1000))ms 超过 30000ms 宽松上限")

    coordinator.updateStreaming(session: session)
    let promotedThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    #expect(promotedThought.isDescendant(of: container))
  }

  private static let workloadStaticMarkdown: String = {
    var parts: [String] = ["# Adapter Workload Static"]
    for index in 0..<35 {
      parts.append("## Section \(index)")
      parts.append("Paragraph \(index) with enough text to render as an attributed block.")
      parts.append("- item \(index)a")
      parts.append("- item \(index)b")
      parts.append("```swift\nlet workload\(index) = \(index)\n```")
    }
    parts.append("| Col | Val |\n|---|---|\n| A | 1 |")
    return parts.joined(separator: "\n\n")
  }()
}
