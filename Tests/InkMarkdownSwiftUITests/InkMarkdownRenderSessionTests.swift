//
//  InkMarkdownRenderSessionTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import SwiftUI
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("InkMarkdownRenderSession 契约测试")
@MainActor
struct InkMarkdownRenderSessionTests {

  /// 等待 deferred @Published 写入在下一 runloop 生效（与 `headlessFinishPromotes` 轮询模式一致）。
  private func waitForRunLoop(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    stepNanoseconds: UInt64 = 10_000_000,
    _ condition: () -> Bool
  ) async {
    var elapsed: UInt64 = 0
    while !condition(), elapsed < timeoutNanoseconds {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
          // 在 GCD 同步块内抽干 `.default` mode；Swift 6 禁止在 async 上下文直接调用 `RunLoop.run`。
          RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
          continuation.resume()
        }
      }
      try? await Task.sleep(nanoseconds: stepNanoseconds)
      elapsed += stepNanoseconds
    }
  }

  @Test("初始状态验证：idle、空文本、空块列表、未提升")
  func initialState() {
    let session = InkMarkdownRenderSession()
    #expect(session.state == .idle)
    #expect(session.currentText.isEmpty)
    #expect(session.blocks.isEmpty)
    #expect(session.isPromoted == false)
  }

  @Test("append 状态转移：idle -> streaming，连续 append 保持 streaming")
  func appendStateTransition() {
    let session = InkMarkdownRenderSession()
    session.append("## 第一分片\n")
    #expect(session.state == .streaming)

    session.append("第二分片内容")
    #expect(session.state == .streaming)
    #expect(session.currentText == "## 第一分片\n第二分片内容")
  }

  @Test("会话与底层 renderer 使用相同的输入长度上限")
  func canonicalSourceLengthLimit() {
    let session = InkMarkdownRenderSession()
    session.append(String(repeating: "a", count: InkStreamRenderer.maximumSourceLength + 1))

    #expect(session.currentText.count == InkStreamRenderer.maximumSourceLength)
  }

  @Test("finish 区分输入结束、最终解析完成、显示完成与终态提升")
  func finishStateTransition() async {
    let session = InkMarkdownRenderSession()
    session.append("正在生成的文本...")
    let textView = UITextView()
    session.bindTextView(textView)
    session.renderer.isDisplayPaused = true

    session.finish()
    #expect(session.state == .finishing)
    #expect(session.isPromoted == false)

    session.renderer.onFinishParse?()
    #expect(session.state == .displayingFinalContent)
    #expect(session.isPromoted == false)

    session.renderer.onFinishDisplay?()
    #expect(session.state == .displayingFinalContent)
    #expect(session.isPromoted == false)
    await waitForRunLoop { session.state == .finished && session.isPromoted }
    #expect(session.state == .finished)
    #expect(session.isPromoted == true)
    #expect(!session.blocks.isEmpty)
  }

  @Test("finish 回调在同 runloop 触发时不在回调栈内同步 publish，下一 runloop 仍完成 promotion")
  func finishCallbacksDeferSameRunLoop() async {
    let session = InkMarkdownRenderSession()
    session.append("# 同 runloop 终态")
    session.finish()

    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    #expect(session.state == .displayingFinalContent)
    #expect(session.isPromoted == false)

    await waitForRunLoop { session.state == .finished && session.isPromoted }
    #expect(session.state == .finished)
    #expect(session.isPromoted == true)
    #expect(!session.blocks.isEmpty)
  }

  @Test("未 attach 文本视图时 finish 仍会完成终态提升")
  func headlessFinishPromotes() async {
    let session = InkMarkdownRenderSession()
    session.append("# 终态内容")
    session.finish()

    await waitForRunLoop { session.state == .finished && session.isPromoted }

    #expect(session.state == .finished)
    #expect(session.isPromoted == true)
    #expect(!session.blocks.isEmpty)
  }

  @Test("cancel 可终止接收、解析或最终显示阶段")
  func cancelStateTransition() {
    let session = InkMarkdownRenderSession()
    session.append("流式内容")
    session.cancel()
    #expect(session.state == .cancelled)

    session.reset()
    session.append("流式内容")
    session.finish()
    #expect(session.state == .finishing)
    session.cancel()
    #expect(session.state == .cancelled)
  }

  @Test("reset 可在全部状态复用，并重新安装终态回调")
  func resetStateTransition() async {
    let session = InkMarkdownRenderSession()
    session.reset()
    #expect(session.state == .idle)

    session.append("一些内容")
    session.reset()
    #expect(session.state == .idle)
    #expect(session.currentText.isEmpty)

    session.append("终态内容")
    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await waitForRunLoop { session.state == .finished && session.isPromoted }
    #expect(session.state == .finished)

    session.reset()
    session.append("第二次终态内容")
    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await waitForRunLoop { session.state == .finished && session.isPromoted }
    #expect(session.state == .finished)
    #expect(session.isPromoted == true)
  }

  @Test("终态与取消状态会拒绝后续输入")
  func terminalStateGuards() async {
    let finished = InkMarkdownRenderSession()
    finished.append("完成前的文本")
    finished.finish()
    finished.renderer.onFinishDisplay?()
    await waitForRunLoop { finished.state == .finished && finished.isPromoted }
    let finishedText = finished.currentText
    finished.append("额外分片")
    finished.cancel()
    #expect(finished.currentText == finishedText)
    #expect(finished.state == .finished)

    let cancelled = InkMarkdownRenderSession()
    cancelled.append("已取消的会话文本")
    cancelled.cancel()
    let cancelledText = cancelled.currentText
    cancelled.append("被忽略的内容")
    cancelled.finish()
    #expect(cancelled.currentText == cancelledText)
    #expect(cancelled.state == .cancelled)
  }

  @Test("配置与 trait 快照由会话集中管理")
  func configurationAndTraitSnapshot() {
    var config = InkConfiguration.standard
    config.appearance.text.fontSize = 24
    let session = InkMarkdownRenderSession(configuration: config)

    session.updateRenderEnvironment(InkRenderEnvironment(userInterfaceStyle: .dark))
    #expect(session.configuration.appearance.text.fontSize == 24)
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .dark)
    #expect(session.renderer.configuration.renderEnvironment.userInterfaceStyle == .dark)
  }

  @Test("PREFIX 未闭合思考 append：streamingThought 未完成且 remainder 无标签")
  func unclosedThoughtStreamingRemainderHasNoTags() {
    let session = InkMarkdownRenderSession()
    session.append("<think>\n正在深度思考")

    #expect(session.streamingThought != nil)
    #expect(session.streamingThought?.isComplete == false)
    #expect(session.streamRemainder.isEmpty)
    #expect(!session.streamRemainder.contains("<think>"))
    #expect(!session.streamRemainder.contains("</think>"))
  }

  @Test("闭合思考后 remainder 进入 renderer；finish 后 blocks 含 InkThoughtBlock")
  func closedThoughtThenAnswerAndFinish() async {
    let session = InkMarkdownRenderSession()
    session.append("<think>步骤</think>\n\n## 回答\n正文")

    #expect(session.streamingThought?.isComplete == true)
    #expect(session.streamRemainder.contains("回答"))

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await waitForRunLoop { session.isPromoted }

    #expect(session.blocks.first is InkThoughtBlock)
    if let thought = session.blocks.first as? InkThoughtBlock {
      #expect(thought.isComplete == true)
      #expect(thought.thought.contains("步骤"))
    }
  }

  @Test("流式 append 保留用户折叠态")
  func streamingThoughtAppendPreservesCollapse() {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    config.appearance.thought.isInitiallyCollapsed = false
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n第一步")
    session.setStreamingThoughtCollapsed(true)
    session.append("\n第二步")
    #expect(session.streamingThought?.isCollapsed == true)
  }

  @Test("finish 后 blocks 继承 streamingThought 折叠态")
  func promotedBlocksPreserveThoughtCollapse() async {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>步骤</think>\n\n## 回答\n正文")
    session.setStreamingThoughtCollapsed(true)

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await waitForRunLoop { session.isPromoted }

    if let thought = session.blocks.first as? InkThoughtBlock {
      #expect(thought.isCollapsed == true)
    }
  }

  @Test("finish 清除 isDisplayPaused，避免 promotion 后仍暂停")
  func finishClearsDisplayPause() {
    let session = InkMarkdownRenderSession()
    session.append("流式文本")
    session.isDisplayPaused = true
    session.finish()
    #expect(session.isDisplayPaused == false)
  }

  @Test("折叠后立即 append 仍保留 streamingThought 折叠态")
  func collapseThenImmediateAppendPreservesStreamingCollapse() {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    config.appearance.thought.isInitiallyCollapsed = false
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>\n第一步")

    let view = InkThoughtBlockView(
      thought: session.streamingThought!.thought,
      isComplete: false,
      config: config.appearance.thought,
      renderConfiguration: config
    )
    view.onToggleCollapse = { session.setStreamingThoughtCollapsed($0) }

    view.handleHeaderTap()
    session.append("\n第二步")

    #expect(session.streamingThought?.isCollapsed == true)
    view.apply(
      thought: session.streamingThought!.thought,
      isComplete: session.streamingThought!.isComplete,
      isCollapsed: session.streamingThought!.isCollapsed
    )
    #expect(view.isCollapsed == true)
    let collapsedSize = view.sizeThatFits(CGSize(width: 320, height: 1000))
    #expect(collapsedSize.height <= 60)
  }

  @Test("promoted 后 updateRenderEnvironment 重渲染 blocks 并保留折叠态")
  func promotedUpdateRenderEnvironmentRerendersBlocksPreservingCollapse() async {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>步骤</think>\n\n## 回答\n正文")
    session.setStreamingThoughtCollapsed(true)

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await waitForRunLoop { session.isPromoted }

    if let thought = session.blocks.first as? InkThoughtBlock {
      #expect(thought.isCollapsed == true)
      #expect(thought.renderConfiguration.renderEnvironment.userInterfaceStyle == .unspecified)
    }

    session.updateRenderEnvironment(InkRenderEnvironment(userInterfaceStyle: .dark))
    await waitForRunLoop { session.blocks.first != nil }

    if let thought = session.blocks.first as? InkThoughtBlock {
      #expect(thought.isCollapsed == true)
      #expect(thought.renderConfiguration.renderEnvironment.userInterfaceStyle == .dark)
    }
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .dark)
  }

  @Test("流式进行中 updateRenderEnvironment 同步更新 streamingThought 配置")
  func streamingUpdateRenderEnvironmentRefreshesStreamingThoughtConfiguration() {
    let session = InkMarkdownRenderSession()
    session.append("<think>\n思考正文")

    #expect(session.streamingThought != nil)
    #expect(session.streamingThought?.renderConfiguration.renderEnvironment.userInterfaceStyle == .unspecified)

    session.updateRenderEnvironment(InkRenderEnvironment(userInterfaceStyle: .dark))

    #expect(session.streamingThought?.renderConfiguration.renderEnvironment.userInterfaceStyle == .dark)
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .dark)
  }
}
