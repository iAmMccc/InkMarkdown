//
//  InkStreamSourceLimitTests.swift
//  InkMarkdownTests
//

import Testing
import UIKit
@_spi(InkMarkdown) @testable import InkMarkdown

@Suite("InkStreamRenderer source limit 契约测试")
@MainActor
struct InkStreamSourceLimitTests {

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

  @Test("默认上限保持 50_000，并在 renderer 创建时固化")
  func defaultSourceLimitSnapshot() {
    let renderer = InkStreamRenderer()

    #expect(InkStreamRenderer.maximumSourceLength == 50_000)
    #expect(renderer.maximumSourceLength == InkStreamRenderer.maximumSourceLength)
    #expect(renderer.canonicalSource.isEmpty)
  }

  @Test("自定义上限覆盖小于、等于与超过三种输入")
  func customSourceLimitAcceptsOnlyCanonicalPrefix() {
    let renderer = InkStreamRenderer(maximumSourceLength: 4)

    renderer.append("ab")
    #expect(renderer.canonicalSource == "ab")

    renderer.append("cd")
    #expect(renderer.canonicalSource == "abcd")

    renderer.append("ef")
    #expect(renderer.canonicalSource == "abcd")
  }

  @Test("reset 与 finish 均只使用已接受 canonical source")
  func resetAndFinishUseCanonicalSource() async {
    let renderer = InkStreamRenderer(maximumSourceLength: 6)
    renderer.reset(to: "# keep\nDROP")

    #expect(renderer.canonicalSource == "# keep")

    renderer.finish()
    await waitForRunLoop { renderer.currentAttributedString().length > 0 }

    #expect(renderer.canonicalSource == "# keep")
    #expect(renderer.currentAttributedString().string == "keep")

    renderer.append("AFTER_FINISH")
    #expect(renderer.canonicalSource == "# keep")
    #expect(renderer.currentAttributedString().string == "keep")
  }

  @Test("非法上限回退默认值且不取消长度保护")
  func invalidSourceLimitFallsBackToDefault() {
    let zero = InkStreamRenderer(maximumSourceLength: 0)
    let negative = InkStreamRenderer(maximumSourceLength: -1)

    #expect(zero.maximumSourceLength == InkStreamRenderer.maximumSourceLength)
    #expect(negative.maximumSourceLength == InkStreamRenderer.maximumSourceLength)
  }
}
