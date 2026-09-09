//
//  InkStreamSourceLimitTests.swift
//  InkMarkdownTests
//

import Testing
import UIKit
import InkMarkdownSemanticCorpus
@_spi(InkMarkdown) @testable import InkMarkdown

@Suite("InkStreamRenderer source limit 契约测试")
@MainActor
struct InkStreamSourceLimitTests {

  @Test("默认上限保持 50_000，并在 renderer 创建时固化")
  func sourceLimit_defaultSourceLimitSnapshot() {
    let renderer = InkStreamRenderer()

    #expect(InkStreamRenderer.maximumSourceLength == 50_000)
    #expect(renderer.maximumSourceLength == InkStreamRenderer.maximumSourceLength)
    #expect(renderer.canonicalSource.isEmpty)
  }

  @Test("自定义上限覆盖小于、等于与超过三种输入")
  func sourceLimit_customAcceptsOnlyCanonicalPrefix() {
    let renderer = InkStreamRenderer(maximumSourceLength: 4)

    renderer.append("ab")
    #expect(renderer.canonicalSource == "ab")

    renderer.append("cd")
    #expect(renderer.canonicalSource == "abcd")

    renderer.append("ef")
    #expect(renderer.canonicalSource == "abcd")
  }

  @Test("reset 与 finish 均只使用已接受 canonical source")
  func sourceLimit_resetAndFinishUseCanonicalSource() async {
    let renderer = InkStreamRenderer(maximumSourceLength: 6)
    renderer.reset(to: "# keep\nDROP")

    #expect(renderer.canonicalSource == "# keep")

    renderer.finish()
    await InkAsyncTestProbe.wait { renderer.currentAttributedString().length > 0 }

    #expect(renderer.canonicalSource == "# keep")
    #expect(renderer.currentAttributedString().string == "keep")

    renderer.append("AFTER_FINISH")
    #expect(renderer.canonicalSource == "# keep")
    #expect(renderer.currentAttributedString().string == "keep")
  }

  @Test("非法上限回退默认值且不取消长度保护")
  func sourceLimit_invalidFallsBackToDefault() {
    let zero = InkStreamRenderer(maximumSourceLength: 0)
    let negative = InkStreamRenderer(maximumSourceLength: -1)

    #expect(zero.maximumSourceLength == InkStreamRenderer.maximumSourceLength)
    #expect(negative.maximumSourceLength == InkStreamRenderer.maximumSourceLength)
  }
}
