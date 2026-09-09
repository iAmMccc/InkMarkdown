import Testing
import UIKit
import InkMarkdownSemanticCorpus
@_spi(Performance) @testable import InkMarkdown

// MARK: - 显示刷新 seam（refreshTextStorage）测试
//
// 背景：显示刷新是 CADisplayLink 驱动的（onDisplayFrame），集成测试环境不触发
// displayLink，刷新逻辑若内联在 onDisplayFrame 里将永远处于测试盲区。
// 该 seam 把"节流 + 差量重写"抽成可测的纯函数，以下测试钉住四种情形：
// 跳过 / 尾部追加 / 收缩裁剪 / 前缀变化全量重写。
// 注意：字符串长度按 UTF-16 单元计（"AB\nCD" = 5 单元）。

/// 变更点完全落在已显示范围之外、且显示长度与 textStorage 一致时：不重写、返回 nil。
@Test @MainActor func refreshTextStorage_skipsWhenChangeOutsideVisibleRange() {
  let content = NSAttributedString(string: "AB\nCD")
  let storage = NSTextStorage(string: "AB")
  // displayIndex = 2（已显示 "AB"），变更点在 2 之后，textStorage 无需裁剪 → 跳过
  let range = InkStreamRenderer.refreshTextStorage(
    textStorage: storage,
    content: content,
    refreshLocation: 2,
    showLength: 2
  )
  #expect(range == nil)
  #expect(storage.string == "AB")
}

/// 尾部追加：只重写 [refreshLocation, showLength) 一段，已显示前缀原样保留。
@Test @MainActor func refreshTextStorage_appendsTailOnly() {
  let content = NSAttributedString(string: "AB\nCD", attributes: [.foregroundColor: UIColor.label])
  // 已显示前缀由同一配置渲染，属性与 content 前缀一致（真实显示链的既成状态）。
  let storage = NSTextStorage(string: "AB", attributes: [.foregroundColor: UIColor.label])
  let range = InkStreamRenderer.refreshTextStorage(
    textStorage: storage,
    content: content,
    refreshLocation: 2,
    showLength: content.length
  )
  #expect(range == NSRange(location: 2, length: 3))
  #expect(storage.string == "AB\nCD")
  // 前缀属性保留：前 2 个字符的前景色与 content 前缀一致。
  // 不直接 isEqual(to:)：NSTextStorage 会附加系统默认字体，content 没有，整体比较必不等。
  let storagePrefix = storage.attributedSubstring(from: NSRange(location: 0, length: 2))
  let contentPrefix = content.attributedSubstring(from: NSRange(location: 0, length: 2))
  #expect(storagePrefix.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
    == contentPrefix.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
}

/// 内容收缩（filter/语法解析使文本变短）：把 textStorage 裁剪到 showLength。
@Test @MainActor func refreshTextStorage_truncatesShrunkContent() {
  let content = NSAttributedString(string: "AB")
  let storage = NSTextStorage(string: "AB\nCD")
  let range = InkStreamRenderer.refreshTextStorage(
    textStorage: storage,
    content: content,
    refreshLocation: 2,
    showLength: 2
  )
  #expect(range == NSRange(location: 2, length: 0))
  #expect(storage.string == "AB")
}

/// 前缀变化（如段落被重解析成 setext heading）：refreshLocation = 0 → 全量重写。
@Test @MainActor func refreshTextStorage_fullRewriteOnPrefixChange() {
  let content = NSAttributedString(string: "**bold**", attributes: [.font: UIFont.boldSystemFont(ofSize: 17)])
  let storage = NSTextStorage(string: "plain", attributes: [.font: UIFont.systemFont(ofSize: 17)])
  let range = InkStreamRenderer.refreshTextStorage(
    textStorage: storage,
    content: content,
    refreshLocation: 0,
    showLength: content.length
  )
  #expect(range == NSRange(location: 0, length: content.length))
  #expect(storage.isEqual(to: content))
}

/// 端到端：sourceFilter 流式 + 显示链（分帧刷新 seam）收敛到与一次性全量渲染一致。
@Test @MainActor func sourceFilterStream_displayChainMatchesFullRender() async throws {
  let config = InkConfiguration(sourceFilter: { $0.replacingOccurrences(of: "<ref/>", with: "") })
  let renderer = InkStreamRenderer(configuration: config)
  renderer.append("<ref")
  renderer.append("/>正文")

  // 等待第二次 append 的后台全量解析落盘。
  for _ in 0..<50 where !renderer.currentAttributedString().string.contains("正文") {
    try? await Task.sleep(nanoseconds: 10_000_000)
  }

  let content = renderer.currentAttributedString()
  let full = InkAttributedRenderer.render("<ref/>正文", configuration: config)
  #expect(content.string == full.string)

  // 用 seam 模拟显示链路：displayIndex 分帧推进，refreshLocation 用字符级稳定前缀近似，
  // 最终 textStorage 必须与全量渲染一致（含节流跳过路径）。
  let textStorage = NSTextStorage()
  var displayIndex = 0
  let target = content.string as NSString
  while displayIndex < content.length {
    let showLength = min(displayIndex + 3, content.length)
    var prefix = 0
    let current = textStorage.string as NSString
    let limit = min(current.length, showLength)
    while prefix < limit, current.character(at: prefix) == target.character(at: prefix) {
      prefix += 1
    }
    _ = InkStreamRenderer.refreshTextStorage(
      textStorage: textStorage,
      content: content,
      refreshLocation: prefix,
      showLength: showLength
    )
    displayIndex = showLength
  }
  #expect(textStorage.string == full.string)
  #expect(!textStorage.string.contains("<ref/>"))
}

/// 真实 renderer 回归：显示暂停期间连续解析的结果必须在下一批显示消费时
/// 保留最早 dirty location。前面的普通段落在追加 Setext 下划线后会改变属性，
/// 后续尾部又经过 sourceFilter；一次消费不能只应用最后一个尾部更新而漏掉前缀。
@Test @MainActor func displayFrame_consumesPrefixRewriteAndLaterTailTogether() async {
  let configuration = InkConfiguration(
    sourceFilter: { $0.replacingOccurrences(of: "<ref/>", with: "") }
  )
  let renderer = InkStreamRenderer(configuration: configuration)
  renderer.charactersPerFrame = Int.max
  let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
  textView.textContainer.size = CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
  renderer.bindTextView(textView)
  renderer.isDisplayPaused = true

  let initialSource = "Title\n"
  renderer.append(initialSource)
  let initialContent = InkAttributedRenderer.render(initialSource, configuration: configuration)
  #expect(await InkAsyncTestProbe.wait { renderer.currentAttributedString().isEqual(to: initialContent) })

  // Resume only long enough to drive the initial snapshot into textStorage. The
  // scheduled flush from isDisplayPaused is kept on the main queue until after
  // these synchronous test frames, so the same seam exercises the real consumer.
  renderer.isDisplayPaused = false
  renderer.driveDisplayFrameForTesting()
  renderer.driveDisplayFrameForTesting()
  renderer.isDisplayPaused = true
  #expect(textView.textStorage.isEqual(to: initialContent))

  // The Setext underline changes the already displayed title's attributes. The
  // later source-filtered tail must be merged into the same pending snapshot.
  let finalSource = "Title\n---\n<ref/>Tail"
  renderer.append("---\n")
  renderer.append("<ref/>Tail")
  let finalContent = InkAttributedRenderer.render(finalSource, configuration: configuration)
  #expect(await InkAsyncTestProbe.wait { renderer.currentAttributedString().isEqual(to: finalContent) })

  renderer.isDisplayPaused = false
  renderer.driveDisplayFrameForTesting()
  let displayedPrefixLength = min(initialContent.length, finalContent.length)
  #expect(
    textView.textStorage.attributedSubstring(
      from: NSRange(location: 0, length: displayedPrefixLength)
    ).isEqual(
      to: finalContent.attributedSubstring(
        from: NSRange(location: 0, length: displayedPrefixLength)
      )
    )
  )
  renderer.driveDisplayFrameForTesting()
  renderer.isDisplayPaused = true

  #expect(textView.textStorage.string == finalContent.string)
  // UITextView fills missing separator attributes during TextKit normalization.
  // Compare semantic text runs; an unstyled newline need not stay attribute-empty.
  let tailRange = (finalContent.string as NSString).range(of: "Tail")
  #expect(textView.textStorage.attributedSubstring(from: tailRange).isEqual(
    to: finalContent.attributedSubstring(from: tailRange)
  ))
  let actualParagraphStyle = textView.textStorage.attribute(
    .paragraphStyle,
    at: 0,
    effectiveRange: nil
  ) as? NSParagraphStyle
  let expectedParagraphStyle = finalContent.attribute(
    .paragraphStyle,
    at: 0,
    effectiveRange: nil
  ) as? NSParagraphStyle
  #expect(actualParagraphStyle?.isEqual(expectedParagraphStyle) == true)
}

@Test(arguments: [0, -1, Int.min])
@MainActor
func displayFrame_nonpositiveSpeedStillMakesProgress(speed: Int) async {
  let renderer = InkStreamRenderer()
  renderer.charactersPerFrame = speed
  let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
  renderer.bindTextView(textView)
  renderer.isDisplayPaused = true
  renderer.append("abc")
  #expect(await InkAsyncTestProbe.wait { renderer.currentAttributedString().string == "abc" })
  renderer.isDisplayPaused = false
  renderer.driveDisplayFrameForTesting()
  renderer.driveDisplayFrameForTesting()
  renderer.isDisplayPaused = true
  #expect(textView.textStorage.string == "a")
}
