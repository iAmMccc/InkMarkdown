//
//  InkMarkdownRenderSessionTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import SwiftUI
@testable import InkMarkdownSwiftUI
import InkMarkdown

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
}
