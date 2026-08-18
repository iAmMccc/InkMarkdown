//
//  InkStreamMarkdownViewTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import SwiftUI
@testable import InkMarkdownSwiftUI
import InkMarkdown

@Suite("InkStreamMarkdownView 流式视图契约测试")
@MainActor
struct InkStreamMarkdownViewTests {

  /// 等待 deferred @Published 写入在下一 runloop 生效（与 `InkMarkdownRenderSessionTests` 轮询模式一致）。
  private func waitForRunLoop(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    stepNanoseconds: UInt64 = 10_000_000,
    _ condition: () -> Bool
  ) async {
    var elapsed: UInt64 = 0
    while !condition(), elapsed < timeoutNanoseconds {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
          RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
          continuation.resume()
        }
      }
      try? await Task.sleep(nanoseconds: stepNanoseconds)
      elapsed += stepNanoseconds
    }
  }

  @Test("InkStreamMarkdownView 支持具名与省略参数初始化")
  func initializationWithSession() {
    let session = InkMarkdownRenderSession()
    let named = InkStreamMarkdownView(session: session)
    let unnamed = InkStreamMarkdownView(session)

    _ = named.body
    _ = unnamed.body
  }

  @Test("会话配置是流式与终态共享的唯一配置真相")
  func sessionConfigurationIsSharedSnapshot() {
    var config = InkConfiguration.standard
    config.appearance.text.fontSize = 20
    let session = InkMarkdownRenderSession(configuration: config)
    let view = InkStreamMarkdownView(session: session)

    _ = view.body
    #expect(session.configuration.appearance.text.fontSize == 20)
    #expect(session.renderer.configuration.appearance.text.fontSize == 20)
  }

  @Test("InkStreamMarkdownView 在 idle、streaming 与 promoted 状态下访问 body 均不崩溃")
  func bodyAccessAcrossSessionStates() async {
    let session = InkMarkdownRenderSession()

    _ = InkStreamMarkdownView(session: session).body

    session.append("## 流式标题\n正在生成的段落内容...")
    _ = InkStreamMarkdownView(session: session).body

    session.finish()
    session.renderer.onFinishDisplay?()
    #expect(session.isPromoted == false)
    await waitForRunLoop { session.state == .finished && session.isPromoted }
    #expect(session.state == .finished)
    #expect(session.isPromoted == true)
    _ = InkStreamMarkdownView(session: session).body
  }
}
