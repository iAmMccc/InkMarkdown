import Testing
import UIKit
import InkMarkdownSemanticCorpus
@_spi(Performance) @testable import InkMarkdown

@Suite("流式高度通知：双零宽延迟补测")
@MainActor
struct InkStreamRendererHeightNotificationTests {

  @Test("双零宽显示后宽度就绪补通知一次，后续同宽空闲帧不重复")
  func notifyHeight_deferredUntilWidthReady_notifiesOnce() async {
    let textView = makeZeroWidthTextView()
    let renderer = makePausedRenderer(boundTo: textView)
    var count = 0
    renderer.onDisplayUpdate = { count += 1 }

    renderer.append(Self.wrappingParagraph)
    #expect(await InkAsyncTestProbe.wait {
      renderer.currentAttributedString().string.contains("streaming")
    })

    driveFrames(renderer, count: 4)
    #expect(count == 0)

    applyMeasurementWidth(320, to: textView)
    driveFrames(renderer, count: 1)
    #expect(count == 1)

    driveFrames(renderer, count: 4)
    #expect(count == 1)
  }

  @Test("textContainer 零宽时回退 bounds 立即通知")
  func notifyHeight_textContainerZero_fallsBackToBounds() async {
    let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
    textView.textContainer.widthTracksTextView = false
    textView.textContainer.size = .zero
    let renderer = makePausedRenderer(boundTo: textView)
    var count = 0
    renderer.onDisplayUpdate = { count += 1 }

    renderer.append(Self.wrappingParagraph)
    #expect(await InkAsyncTestProbe.wait {
      renderer.currentAttributedString().string.contains("streaming")
    })

    driveFrames(renderer, count: 4)
    #expect(count == 1)

    driveFrames(renderer, count: 4)
    #expect(count == 1)
  }

  @Test("高度变化大于 1pt 才通知，阈值内不通知")
  func notifyHeight_gateIgnoresSubPointChange() async {
    let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
    textView.textContainer.size = CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
    let renderer = makePausedRenderer(boundTo: textView)
    var count = 0
    renderer.onDisplayUpdate = { count += 1 }

    renderer.append("Hi")
    #expect(await InkAsyncTestProbe.wait { renderer.currentAttributedString().string == "Hi" })
    driveFrames(renderer, count: 4)
    #expect(count == 1)

    renderer.append("!")
    #expect(await InkAsyncTestProbe.wait { renderer.currentAttributedString().string == "Hi!" })
    driveFrames(renderer, count: 4)
    #expect(count == 1)

    renderer.append("\n\nLine two\nLine three\nLine four")
    #expect(await InkAsyncTestProbe.wait {
      renderer.currentAttributedString().string.contains("Line four")
    })
    driveFrames(renderer, count: 4)
    #expect(count == 2)
  }

  @Test("bindTextView 后可补测一次")
  func notifyHeight_bindTextViewConsumesDeferred() async {
    let zeroView = makeZeroWidthTextView()
    let renderer = makePausedRenderer(boundTo: zeroView)
    var count = 0
    renderer.onDisplayUpdate = { count += 1 }

    renderer.append(Self.wrappingParagraph)
    #expect(await InkAsyncTestProbe.wait {
      renderer.currentAttributedString().string.contains("streaming")
    })
    driveFrames(renderer, count: 4)
    #expect(count == 0)

    let sizedView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
    sizedView.textContainer.size = CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
    renderer.bindTextView(sizedView)
    #expect(count == 1)

    driveFrames(renderer, count: 4)
    #expect(count == 1)
  }

  // MARK: - Helpers

  private static let wrappingParagraph =
    "Hello streaming world. This paragraph is long enough to produce a measurable height once a real column width is available for TextKit layout."

  private func makeZeroWidthTextView() -> UITextView {
    let textView = UITextView(frame: .zero)
    textView.textContainer.widthTracksTextView = false
    textView.textContainer.size = .zero
    return textView
  }

  private func makePausedRenderer(boundTo textView: UITextView) -> InkStreamRenderer {
    let renderer = InkStreamRenderer()
    renderer.charactersPerFrame = Int.max
    renderer.bindTextView(textView)
    renderer.isDisplayPaused = true
    return renderer
  }

  private func applyMeasurementWidth(_ width: CGFloat, to textView: UITextView) {
    textView.frame.size = CGSize(width: width, height: 1)
    textView.textContainer.widthTracksTextView = false
    textView.textContainer.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
  }

  private func driveFrames(_ renderer: InkStreamRenderer, count: Int) {
    for _ in 0..<count {
      renderer.driveDisplayFrameForTesting()
    }
  }
}
