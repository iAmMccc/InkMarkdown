//
//  InkMarkdownRenderSessionTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import SwiftUI
import InkMarkdownSemanticCorpus
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("InkMarkdownRenderSession 契约测试")
@MainActor
struct InkMarkdownRenderSessionTests {

  @Test("初始状态验证：idle、空文本、空块列表、未提升")
  func renderSession_initialState() {
    let session = InkMarkdownRenderSession()
    #expect(session.state == .idle)
    #expect(session.currentText.isEmpty)
    #expect(session.blocks.isEmpty)
    #expect(session.isPromoted == false)
  }

  @Test("append 状态转移：idle -> streaming，连续 append 保持 streaming")
  func renderSession_appendStateTransition() {
    let session = InkMarkdownRenderSession()
    session.append("")
    #expect(session.state == .idle, "空 delta 不得创建活跃流式呈现周期")
    #expect(!session.requiresStreamingTextAttachment)

    session.append("## 第一分片\n")
    #expect(session.state == .streaming)

    session.append("第二分片内容")
    #expect(session.state == .streaming)
    #expect(session.currentText == "## 第一分片\n第二分片内容")
  }

  @Test("会话与底层 renderer 使用相同的输入长度上限")
  func sourceLimit_canonicalSourceLengthLimit() {
    let session = InkMarkdownRenderSession()
    session.append(String(repeating: "a", count: InkStreamRenderer.maximumSourceLength + 1))

    #expect(session.currentText.count == InkStreamRenderer.maximumSourceLength)
  }

  @Test("finish 区分输入结束、最终解析完成、显示完成与终态提升")
  func renderSession_finishStateTransition() async {
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
    await InkAsyncTestProbe.wait { session.state == .finished && session.isPromoted }
    #expect(session.state == .finished)
    #expect(session.isPromoted == true)
    #expect(!session.blocks.isEmpty)
  }

  @Test("finish 回调在同 runloop 触发时不在回调栈内同步 publish，下一 runloop 仍完成 promotion")
  func renderSession_finishCallbacksDeferSameRunLoop() async {
    let session = InkMarkdownRenderSession()
    session.append("# 同 runloop 终态")
    session.finish()

    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    #expect(session.state == .displayingFinalContent)
    #expect(session.isPromoted == false)

    await InkAsyncTestProbe.wait { session.state == .finished && session.isPromoted }
    #expect(session.state == .finished)
    #expect(session.isPromoted == true)
    #expect(!session.blocks.isEmpty)
  }

  @Test("延迟 publish 前 cancel/reset 作废排队的 @Published 变更")
  func renderSession_deferredPublishInvalidatedByCancelAndReset() async {
    let cancelled = InkMarkdownRenderSession()
    cancelled.append("# 将被取消的终态")
    cancelled.finish()
    cancelled.renderer.onFinishParse?()
    cancelled.renderer.onFinishDisplay?()
    #expect(cancelled.state == .displayingFinalContent)
    #expect(cancelled.isPromoted == false)

    cancelled.cancel()
    #expect(cancelled.state == .cancelled)
    #expect(cancelled.isPromoted == false)

    // 抽干 default-mode hopper；cancel 必须作废排队的 finished/isPromoted 写入。
    await InkAsyncTestProbe.wait(timeoutNanoseconds: 200_000_000) { false }
    #expect(cancelled.state == .cancelled)
    #expect(cancelled.isPromoted == false)

    let resetSession = InkMarkdownRenderSession()
    resetSession.append("# 将被 reset 的终态")
    resetSession.finish()
    resetSession.renderer.onFinishParse?()
    resetSession.renderer.onFinishDisplay?()
    #expect(resetSession.state == .displayingFinalContent)
    #expect(resetSession.isPromoted == false)

    resetSession.reset()
    #expect(resetSession.state == .idle)
    #expect(resetSession.isPromoted == false)
    await InkAsyncTestProbe.wait(timeoutNanoseconds: 200_000_000) { false }
    #expect(resetSession.state == .idle)
    #expect(resetSession.isPromoted == false)
    #expect(resetSession.blocks.isEmpty)
  }

  @Test("未 attach 文本视图时 finish 仍会完成终态提升")
  func renderSession_headlessFinishPromotes() async {
    let session = InkMarkdownRenderSession()
    session.append("# 终态内容")
    session.finish()

    await InkAsyncTestProbe.wait { session.state == .finished && session.isPromoted }

    #expect(session.state == .finished)
    #expect(session.isPromoted == true)
    #expect(!session.blocks.isEmpty)

    let emptySession = InkMarkdownRenderSession()
    emptySession.finish()
    await InkAsyncTestProbe.wait { emptySession.state == .finished && emptySession.isPromoted }
    #expect(emptySession.state == .finished, "零内容流也必须完成终态生命周期")
    #expect(emptySession.isPromoted)
    #expect(emptySession.blocks.isEmpty)
  }

  @Test("cancel 可终止接收、解析或最终显示阶段")
  func renderSession_cancelStateTransition() {
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
  func renderSession_resetStateTransition() async {
    let session = InkMarkdownRenderSession()
    session.reset()
    #expect(session.state == .idle)

    session.append("<thi")
    #expect(session.streamingThought == nil)
    #expect(session.renderer.canonicalSource.isEmpty, "未决 PREFIX 不得泄漏到正文 renderer")
    session.reset()
    session.append("普通正文")
    #expect(session.renderer.canonicalSource == "普通正文", "reset 后不得残留局部标签状态")

    session.reset()
    #expect(session.state == .idle)
    #expect(session.currentText.isEmpty)

    session.append("终态内容")
    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await InkAsyncTestProbe.wait { session.state == .finished && session.isPromoted }
    #expect(session.state == .finished)

    session.reset()
    session.append("第二次终态内容")
    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await InkAsyncTestProbe.wait { session.state == .finished && session.isPromoted }
    #expect(session.state == .finished)
    #expect(session.isPromoted == true)
  }

  @Test("终态与取消状态会拒绝后续输入")
  func renderSession_terminalStateGuards() async {
    let finished = InkMarkdownRenderSession()
    finished.append("完成前的文本")
    finished.finish()
    finished.renderer.onFinishDisplay?()
    await InkAsyncTestProbe.wait { finished.state == .finished && finished.isPromoted }
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
  func renderSession_configurationAndTraitSnapshot() {
    var config = InkConfiguration.standard
    config.appearance.text.fontSize = 24
    let session = InkMarkdownRenderSession(configuration: config)

    session.updateRenderEnvironment(InkRenderEnvironment(userInterfaceStyle: .dark))
    #expect(session.configuration.appearance.text.fontSize == 24)
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .dark)
    #expect(session.renderer.configuration.renderEnvironment.userInterfaceStyle == .dark)
  }

  @Test("PREFIX 未闭合思考 append：streamingThought 未完成且 remainder 无标签")
  func streamingThought_unclosedRemainderHasNoTags() {
    let session = InkMarkdownRenderSession()
    session.append("<think>\n正在深度思考")

    #expect(session.streamingThought != nil)
    #expect(session.streamingThought?.isComplete == false)
    #expect(session.streamRemainder.isEmpty)
    #expect(!session.streamRemainder.contains("<think>"))
    #expect(!session.streamRemainder.contains("</think>"))
  }

  @Test("闭合思考后 remainder 进入 renderer；finish 后 blocks 含 InkThoughtBlock")
  func renderSession_closedThoughtThenAnswerAndFinish() async {
    let chunkedSession = InkMarkdownRenderSession()
    chunkedSession.append("<think>\n`code\n</think>\nstill code")
    #expect(chunkedSession.streamingThought?.isComplete == false)
    #expect(chunkedSession.streamRemainder.isEmpty)
    #expect(chunkedSession.renderer.canonicalSource.isEmpty)

    chunkedSession.append("`\n继续思考\n</think>\nanswer")
    #expect(chunkedSession.streamingThought?.isComplete == true)
    #expect(chunkedSession.streamingThought?.thought.contains("still code`") == true)
    #expect(chunkedSession.streamRemainder == "\nanswer")
    #expect(chunkedSession.renderer.canonicalSource == "\nanswer")
    #expect(
      chunkedSession.thoughtScannerInputUnitInspectionCount
        == chunkedSession.currentText.utf16.count,
      "session 必须只把 accepted delta 交给增量 scanner"
    )

    let session = InkMarkdownRenderSession()
    session.append("<think>步骤</think>\n\n## 回答\n正文")

    #expect(session.streamingThought?.isComplete == true)
    #expect(session.streamRemainder.contains("回答"))

    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await InkAsyncTestProbe.wait { session.isPromoted }

    #expect(session.blocks.first is InkThoughtBlock)
    if let thought = session.blocks.first as? InkThoughtBlock {
      #expect(thought.isComplete == true)
      #expect(thought.thought.contains("步骤"))
    }
  }

  @Test("finish 清除 isDisplayPaused，避免 promotion 后仍暂停")
  func renderSession_finishClearsDisplayPause() {
    let session = InkMarkdownRenderSession()
    session.append("流式文本")
    session.isDisplayPaused = true
    session.finish()
    #expect(session.isDisplayPaused == false)
  }

  @Test("promoted 后 updateRenderEnvironment 重渲染 semantic blocks")
  func renderSession_promotedUpdateRenderEnvironmentRerendersSemanticBlocks() async {
    var config = InkConfiguration.standard
    config.appearance.thought.isCollapsible = true
    let session = InkMarkdownRenderSession(configuration: config)
    session.append("<think>步骤</think>\n\n## 回答\n正文")
    session.finish()
    session.renderer.onFinishParse?()
    session.renderer.onFinishDisplay?()
    await InkAsyncTestProbe.wait { session.isPromoted }

    if let thought = session.blocks.first as? InkThoughtBlock {
      #expect(thought.renderConfiguration.renderEnvironment.userInterfaceStyle == .unspecified)
    }

    let canonicalSourceBeforeEnvironmentUpdate = session.renderer.canonicalSource
    session.updateRenderEnvironment(InkRenderEnvironment(userInterfaceStyle: .dark))
    await InkAsyncTestProbe.wait { session.blocks.first != nil }

    if let thought = session.blocks.first as? InkThoughtBlock {
      #expect(thought.renderConfiguration.renderEnvironment.userInterfaceStyle == .dark)
    }
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .dark)
    #expect(session.renderer.configuration.renderEnvironment.userInterfaceStyle == .dark)

    // 终态环境更新不得把 renderer 退回可追加状态或重置 canonical source。
    session.renderer.appendCanonical("不应进入已完成会话")
    #expect(session.renderer.canonicalSource == canonicalSourceBeforeEnvironmentUpdate)
  }

  @Test("流式进行中 updateRenderEnvironment 同步更新 streamingThought 配置")
  func streamingThought_updateRenderEnvironmentRefreshesConfiguration() {
    let session = InkMarkdownRenderSession()
    session.append("<think>\n思考正文")

    #expect(session.streamingThought != nil)
    #expect(session.streamingThought?.renderConfiguration.renderEnvironment.userInterfaceStyle == .unspecified)

    session.updateRenderEnvironment(InkRenderEnvironment(userInterfaceStyle: .dark))

    #expect(session.streamingThought?.renderConfiguration.renderEnvironment.userInterfaceStyle == .dark)
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .dark)
  }

  @Test("流式 textView 在真实宽度变化后发出图片重绑定信号")
  func streamingTextView_displayContextChangeNotifiesHost() {
    let textView = InkStreamingTextView()
    var callbackCount = 0
    textView.onDisplayContextChange = { callbackCount += 1 }

    textView.frame = CGRect(x: 0, y: 0, width: 180, height: 120)
    textView.setNeedsLayout()
    textView.layoutIfNeeded()
    let firstLayoutCallbackCount = callbackCount
    #expect(firstLayoutCallbackCount > 0)

    textView.frame.size.width = 280
    textView.setNeedsLayout()
    textView.layoutIfNeeded()
    #expect(callbackCount > firstLayoutCallbackCount)
  }

  @Test("成组 binding：新 install 替换旧 grant，旧 release 无效")
  func renderSession_presentationBindingGrantIsolation() {
    let session = InkMarkdownRenderSession()
    final class Owner {}
    let ownerA = Owner()
    let ownerB = Owner()
    let textA = UITextView()
    let textB = UITextView()

    var hitsB = 0
    let grantA = session.installPresentationBinding(
      owner: ownerA,
      textView: textA,
      observer: { }
    )
    let grantB = session.installPresentationBinding(
      owner: ownerB,
      textView: textB,
      observer: { hitsB += 1 }
    )
    #expect(grantA != grantB)

    session.releasePresentationBinding(grantA)
    session.unbindTextView(owner: ownerA)
    session.removePresentationDisplayUpdateObserver(owner: ownerA)

    session.append("绑定隔离")
    session.renderer.onDisplayUpdate?()
    #expect(hitsB >= 1)

    // nil textView 仍可保留 observer
    var observerOnlyHits = 0
    session.updatePresentationBinding(
      grantB,
      textView: nil,
      observer: { observerOnlyHits += 1 }
    )
    session.renderer.onDisplayUpdate?()
    #expect(observerOnlyHits >= 1)

    session.releasePresentationBinding(grantB)
    let before = observerOnlyHits
    session.renderer.onDisplayUpdate?()
    #expect(observerOnlyHits == before)
  }

  @Test("public onDisplayUpdate 与 private observer 共存且互不覆盖")
  func renderSession_publicAndPrivateDisplayCallbacksCoexist() {
    let session = InkMarkdownRenderSession()
    final class Owner {}
    let owner = Owner()
    var publicHits = 0
    var privateHits = 0
    session.onDisplayUpdate = { publicHits += 1 }
    _ = session.installPresentationBinding(
      owner: owner,
      textView: nil,
      observer: { privateHits += 1 }
    )
    session.append("共存回调")
    session.renderer.onDisplayUpdate?()
    #expect(publicHits >= 1)
    #expect(privateHits >= 1)
    #expect(session.onDisplayUpdate != nil)
  }
}
