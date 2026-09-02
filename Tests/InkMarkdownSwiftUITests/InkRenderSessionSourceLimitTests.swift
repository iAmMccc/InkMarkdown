//
//  InkRenderSessionSourceLimitTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import InkMarkdownSemanticCorpus
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) @testable import InkMarkdown

@Suite("InkMarkdownRenderSession source limit 契约测试")
@MainActor
struct InkRenderSessionSourceLimitTests {

  @Test("session 与 renderer 在创建时共享同一个不可变上限 snapshot")
  func renderSession_sessionAndRendererShareSourceLimitSnapshot() {
    let session = InkMarkdownRenderSession(maximumSourceLength: 4)

    #expect(session.maximumSourceLength == 4)
    #expect(session.renderer.maximumSourceLength == 4)

    session.append("abcd")
    #expect(session.currentText == "abcd")
    #expect(session.streamRemainder == "abcd")

    session.append("ef")
    #expect(session.currentText == "abcd")
    #expect(session.streamRemainder == "abcd")
  }

  @Test("小于、等于、超过上限时 currentText 只保留 canonical source")
  func currentText_usesCanonicalSource() {
    let session = InkMarkdownRenderSession(maximumSourceLength: 5)

    session.append("ab")
    #expect(session.currentText == "ab")
    session.append("cde")
    #expect(session.currentText == "abcde")
    session.append("fgh")
    #expect(session.currentText == "abcde")
  }

  @Test("非法 session 上限回退默认值")
  func sessionSourceLimit_invalidFallsBackToDefault() {
    let zero = InkMarkdownRenderSession(maximumSourceLength: 0)
    let negative = InkMarkdownRenderSession(maximumSourceLength: -1)

    #expect(zero.maximumSourceLength == InkStreamRenderer.maximumSourceLength)
    #expect(negative.maximumSourceLength == InkStreamRenderer.maximumSourceLength)
    #expect(zero.renderer.maximumSourceLength == zero.maximumSourceLength)
    #expect(negative.renderer.maximumSourceLength == negative.maximumSourceLength)
  }

  @Test("finish 与 promotion 只消费 canonical source")
  func promotion_finishAndPromotionUseCanonicalSource() async {
    let session = InkMarkdownRenderSession(maximumSourceLength: 10)
    let source = "# accepted\nTAIL"
    session.append(source)

    #expect(session.currentText == String(source.prefix(10)))
    #expect(session.renderer.canonicalSource == session.streamRemainder)

    session.finish()
    await InkAsyncTestProbe.wait { session.isPromoted }

    #expect(session.isPromoted)
    #expect(session.currentText == "# accepted")
    #expect(session.renderer.canonicalSource == session.streamRemainder)

    let promotedText = session.blocks
      .compactMap { ($0 as? InkAttributedTextBlock)?.attributedText.string }
      .joined(separator: "\n")
    #expect(promotedText.contains("accepted"))
    #expect(!promotedText.contains("TAIL"))
  }
}
