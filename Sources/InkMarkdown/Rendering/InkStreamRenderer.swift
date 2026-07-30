import UIKit
import Markdown

/// 流式渲染器：把一段会**持续增长**的 Markdown 文本，增量渲染为 `NSAttributedString`，
/// 并支持直接绑定 `UITextView` 进行差量更新。
///
/// ## 架构：解析-显示双缓冲
///
/// ```
/// SSE chunk 到达 → 后台串行队列增量解析 → preloadContent（缓冲区）
///                                              ↓
///                          CADisplayLink 按帧率 → 逐步截取 → textStorage 增量更新
/// ```
///
/// - 解析与显示完全解耦：解析慢不影响吐字动画平滑
/// - 显示侧每帧开销恒定 O(1)：只做 attributedSubstring 截取 + textStorage append
/// - 支持暂停/恢复显示（用户滑动时暂停）
///
/// ## 块级 LaTeX / Mermaid 的终态职责
///
/// 本渲染器只产出 `NSAttributedString`，**不能**承载块级 LaTeX（`$$...$$`、`\\[...\\]`）
/// 或 Mermaid 围栏对应的 `UIView`。流结束时调用 ``finish()`` 仅对 attributed-string
/// 通道做最终全量解析；若需把独占段落的块级公式或 Mermaid 图渲染为图片块，
/// 宿主须在收到完整源文本后另行调用 ``InkBlockRenderer/render(_:configuration:)``。
///
/// ### 使用方式
/// ```swift
/// let renderer = InkStreamRenderer(configuration: .standard)
/// renderer.bindTextView(textView)
/// renderer.append("## 标题\n")     // SSE 每收到分片就 append
/// renderer.finish()                // 流结束（仅 finalized attributed string）
/// // 块级 LaTeX / Mermaid（需保留完整源文本）：
/// let blocks = InkBlockRenderer.render(fullSource, configuration: config)
/// ```
/// 流式渲染器：所有公开 API（append/finish/bindTextView/unbindTextView）必须在主线程调用。
public final class InkStreamRenderer {

  // MARK: - Public Properties

  public let configuration: InkConfiguration

  /// 每次渲染产物更新时回调（未绑定 textView 时使用）。
  public var onUpdate: ((NSAttributedString) -> Void)?

  /// 每帧显示的字符数。60fps 下：1=60字/秒，2=120字/秒，3=180字/秒。
  public var charactersPerFrame: Int = 2

  /// 每帧显示内容变化时回调（用于通知外部更新 cell 高度）。
  public var onDisplayUpdate: (() -> Void)?

  /// Mermaid 块事件回调
  public var onMermaidBlockUpdate: ((_ blockID: String, _ source: String, _ isComplete: Bool) -> Void)?


  /// 所有内容吐字完毕时回调（finish 被调用且 displayIndex 追上 totalLength 时触发）。
  public var onFinishDisplay: (() -> Void)?

  /// 暂停显示更新（解析仍继续）。用于用户滑动列表时暂停主线程 textStorage 操作。
  public var isDisplayPaused: Bool = false {
    didSet {
      if !isDisplayPaused && oldValue {
        DispatchQueue.main.async { [weak self] in
          self?._flushDisplay()
        }
      }
    }
  }

  // MARK: - Private Properties

  /// 已累计接收的原始 Markdown 文本
  private var buffer: String = ""

  /// 绑定的 textView（弱引用）
  private weak var textView: UITextView?

  /// 后台解析队列
  private let parseQueue = DispatchQueue(label: "InkStreamRenderer.parse", qos: .userInitiated)

  /// 解析完成的完整 NSAttributedString（后台写入，主线程读取）
  private var preloadContent: NSAttributedString = NSAttributedString()
  private let preloadLock = NSLock()

  /// 当前已显示到 preloadContent 的字符位置
  private var displayIndex: Int = 0

  /// 驱动逐字显示的 displayLink
  private var displayLink: CADisplayLink?

  /// 每帧推进的字符数（自适应）
  private var chunkSize: Int = 3

  /// 标记流是否已结束
  private var isFinished: Bool = false

  /// finish() 触发的最终解析是否已完成
  private var finalParseCompleted: Bool = false

  /// 上次记录的 textView 内容高度，用于检测高度变化
  private var lastContentHeight: CGFloat = 0

  /// 解析版本号：每次后台解析完成递增，用于检测受影响范围是否需要刷新
  private var parseVersion: UInt64 = 0

  /// 上次应用到 textView 的解析版本
  private var lastAppliedParseVersion: UInt64 = 0

  /// 本次解析产物中需要刷新的起点；稳定前缀无需重写 textStorage
  private var preloadRefreshLocation: Int = 0

  /// 渲染代次：reset/finish 后丢弃旧后台解析结果，避免过期任务回写
  private var renderGeneration: UInt64 = 0

  /// 后台队列独占访问的增量渲染缓存
  private var incrementalRenderer = InkIncrementalMarkdownRenderer()

  // MARK: - Init

  public init(configuration: InkConfiguration = .standard) {
    self.configuration = configuration
  }

  deinit {
    stopDisplayLink()
  }

  // MARK: - Public API

  /// 绑定 UITextView，后续 append/finish 会自动驱动其 textStorage 更新。
  /// 如果已有已显示内容（displayIndex > 0），会同步到新 textView。
  public func bindTextView(_ tv: UITextView) {
    self.textView = tv

    // 重新绑定时同步已显示的内容到新 textView
    if displayIndex > 0 {
      preloadLock.lock()
      let content = preloadContent
      preloadLock.unlock()
      let showLength = min(displayIndex, content.length)
      if showLength > 0 {
        let displayed = content.attributedSubstring(from: NSRange(location: 0, length: showLength))
        tv.textStorage.setAttributedString(displayed)
        bindImageAttachmentsIfNeeded()
      }
    }

    startDisplayLink()
  }

  /// 解绑 textView 并快进 displayIndex 到当前已解析位置。
  /// 用于 cell 离开屏幕时：不再做 textStorage 操作，但逻辑上视为已吐出。
  public func unbindTextView() {
    textView = nil
    // 快进到已解析的最新位置
    preloadLock.lock()
    displayIndex = preloadContent.length
    preloadLock.unlock()
  }

  /// 与 BDAiTextViewCache.maxRenderLength 保持一致：超过此长度停止解析
  private static let maxParseLength = 50_000

  /// 追加一段新到达的 Markdown 文本分片。
  /// 内部将在后台队列异步解析，不阻塞主线程。
  public func append(_ chunk: String) {
    buffer += chunk

    // buffer 超过阈值后停止解析——最终 warmUp 也只渲染 50K，流式中超出部分无意义
    guard buffer.count <= Self.maxParseLength else { return }

    let currentBuffer = buffer
    let config = configuration.capturingRenderEnvironmentForBackgroundParse()
    let generation = currentRenderGeneration()
    parseQueue.async { [weak self] in
      guard let self = self else { return }
      let result: InkIncrementalMarkdownRenderer.Result
      if config.sourceFilter == nil {
        result = self.incrementalRenderer.append(chunk, configuration: config)
      } else {
        result = InkIncrementalMarkdownRenderer.Result(
          content: InkAttributedRenderer.render(currentBuffer, configuration: config),
          refreshLocation: 0
        )
      }
      self.preloadLock.lock()
      guard self.renderGeneration == generation else {
        self.preloadLock.unlock()
        return
      }
      self.preloadContent = result.content
      self.preloadRefreshLocation = result.refreshLocation
      self.parseVersion += 1
      self.preloadLock.unlock()
    }
  }

  /// 用完整文本整体重置。
  public func reset(to source: String = "") {
    stopDisplayLink()
    buffer = source
    displayIndex = 0
    isFinished = false
    lastAppliedParseVersion = 0

    preloadLock.lock()
    renderGeneration += 1
    let generation = renderGeneration
    finalParseCompleted = false
    parseVersion = 0
    preloadRefreshLocation = 0
    preloadLock.unlock()

    let config = configuration.capturingRenderEnvironmentForBackgroundParse()
    if source.isEmpty {
      parseQueue.async { [weak self] in
        self?.incrementalRenderer.reset()
      }
      preloadLock.lock()
      preloadContent = NSAttributedString()
      preloadLock.unlock()
      if let tv = textView {
        tv.textStorage.setAttributedString(NSAttributedString())
      }
      onUpdate?(NSAttributedString())
    } else {
      parseQueue.async { [weak self] in
        guard let self = self else { return }
        let result: InkIncrementalMarkdownRenderer.Result
        if config.sourceFilter == nil {
          result = self.incrementalRenderer.replaceSource(source, configuration: config)
        } else {
          self.incrementalRenderer.reset()
          result = InkIncrementalMarkdownRenderer.Result(
            content: InkAttributedRenderer.render(source, configuration: config),
            refreshLocation: 0
          )
        }
        self.preloadLock.lock()
        guard self.renderGeneration == generation else {
          self.preloadLock.unlock()
          return
        }
        self.preloadContent = result.content
        self.preloadRefreshLocation = result.refreshLocation
        self.preloadLock.unlock()
        DispatchQueue.main.async { [weak self] in
          self?.startDisplayLink()
        }
      }
    }
  }

  /// 标记流结束。displayLink 会继续逐字吐完剩余内容，全部完成后触发 onFinishDisplay。
  ///
  /// 此方法仅 finalized 当前 buffer 的 **attributed-string 通道**结果；
  /// 块级 LaTeX（`$$...$$`、`\\[...\\]`）与 Mermaid 围栏不会被转为 `UIView`。
  /// 若宿主需要块级图片渲染，请在流结束后对完整源文本调用 ``InkBlockRenderer/render(_:configuration:)``。
  public func finish() {
    var currentBuffer = buffer
    if currentBuffer.count > Self.maxParseLength {
      let endIndex = currentBuffer.index(currentBuffer.startIndex, offsetBy: Self.maxParseLength)
      currentBuffer = String(currentBuffer[..<endIndex])
    }
    let config = configuration.capturingRenderEnvironmentForBackgroundParse()
    isFinished = true
    preloadLock.lock()
    renderGeneration += 1
    let generation = renderGeneration
    finalParseCompleted = false
    preloadLock.unlock()

    parseQueue.async { [weak self] in
      self?.incrementalRenderer.reset()
      let rendered = InkAttributedRenderer.render(currentBuffer, configuration: config)
      guard let self = self else { return }
      self.preloadLock.lock()
      guard self.renderGeneration == generation else {
        self.preloadLock.unlock()
        return
      }
      self.preloadContent = rendered
      self.preloadRefreshLocation = 0
      self.parseVersion += 1
      self.finalParseCompleted = true
      self.preloadLock.unlock()
    }
  }

  /// 当前已渲染的完整结果（可用于缓存）。
  public func currentAttributedString() -> NSAttributedString {
    preloadLock.lock()
    let content = preloadContent
    preloadLock.unlock()
    return content
  }

  private func currentRenderGeneration() -> UInt64 {
    preloadLock.lock()
    let generation = renderGeneration
    preloadLock.unlock()
    return generation
  }

  // MARK: - Display Link

  private func startDisplayLink() {
    guard displayLink == nil else { return }
    let link = CADisplayLink(target: DisplayLinkTarget(renderer: self), selector: #selector(DisplayLinkTarget.onFrame))
    if #available(iOS 15.0, *) {
      link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    }
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  private func stopDisplayLink() {
    displayLink?.invalidate()
    displayLink = nil
  }

  /// CADisplayLink 每帧回调
  fileprivate func onDisplayFrame() {
    guard !isDisplayPaused else { return }

    preloadLock.lock()
    let content = preloadContent
    let parseVersion = self.parseVersion
    let refreshLocation = min(preloadRefreshLocation, content.length)
    let finalParseCompleted = self.finalParseCompleted
    preloadLock.unlock()

    let totalLength = content.length

    // 解析后长度可能缩短（如链接/图片语法解析后只保留可见文本），
    // 或当前开放块样式变化——只刷新受影响范围
    if totalLength < displayIndex || parseVersion != lastAppliedParseVersion {
      displayIndex = min(displayIndex, totalLength)
      lastAppliedParseVersion = parseVersion
      var bindRange: NSRange?
      if let tv = textView {
        let showLength = min(displayIndex, totalLength)
        let start = min(refreshLocation, tv.textStorage.length, showLength)
        let replacement = content.attributedSubstring(from: NSRange(location: start, length: showLength - start))
        tv.textStorage.replaceCharacters(
          in: NSRange(location: start, length: tv.textStorage.length - start),
          with: replacement
        )
        bindRange = NSRange(location: start, length: showLength - start)
      }
      onUpdate?(content.attributedSubstring(from: NSRange(location: 0, length: displayIndex)))
      bindImageAttachmentsIfNeeded(in: bindRange)
      notifyHeightChangeIfNeeded()
      if isFinished && finalParseCompleted && displayIndex >= totalLength {
        stopDisplayLink()
        let cb = onFinishDisplay
        onFinishDisplay = nil
        cb?()
      }
      return
    }

    guard totalLength > displayIndex else {
      if isFinished && finalParseCompleted {
        stopDisplayLink()
        let cb = onFinishDisplay
        onFinishDisplay = nil
        cb?()
      }
      return
    }

    chunkSize = charactersPerFrame

    let newDisplayIndex = min(displayIndex + chunkSize, totalLength)

    guard let tv = textView else {
      displayIndex = newDisplayIndex
      let substring = content.attributedSubstring(from: NSRange(location: 0, length: newDisplayIndex))
      onUpdate?(substring)
      return
    }

    // 增量追加：只插入 [displayIndex..<newDisplayIndex] 的新字符
    let appendRange = NSRange(location: displayIndex, length: newDisplayIndex - displayIndex)
    let appendContent = content.attributedSubstring(from: appendRange)
    let insertionPoint = NSRange(location: tv.textStorage.length, length: 0)
    tv.textStorage.replaceCharacters(in: insertionPoint, with: appendContent)

    displayIndex = newDisplayIndex
    onUpdate?(content.attributedSubstring(from: NSRange(location: 0, length: newDisplayIndex)))

    bindImageAttachmentsIfNeeded(in: appendRange)
    notifyHeightChangeIfNeeded()

    // 流结束且最终解析完成且显示追上 → 停止并通知
    if isFinished && finalParseCompleted && displayIndex >= totalLength {
      stopDisplayLink()
      let cb = onFinishDisplay
      onFinishDisplay = nil
      cb?()
    }
  }

  private func notifyHeightChangeIfNeeded() {
    let containerWidth = textView?.textContainer.size.width ?? 0
    guard containerWidth > 0, let tv = textView else { return }
    let newHeight = tv.sizeThatFits(CGSize(width: containerWidth, height: .greatestFiniteMagnitude)).height
    if abs(newHeight - lastContentHeight) > 1 {
      lastContentHeight = newHeight
      onDisplayUpdate?()
    }
  }

  private func bindImageAttachmentsIfNeeded(in range: NSRange? = nil) {
    MainActor.assumeIsolated {
      guard let tv = textView else { return }
      let layoutManager = tv.layoutManager
      InkImageAttachment.bindAttachments(
        in: tv.textStorage,
        layoutManager: layoutManager,
        onHeightChange: { [weak self] in
          self?.notifyHeightChangeIfNeeded()
        },
        range: range
      )
    }
  }

  // MARK: - Flush

  /// 立即将所有已解析内容显示完毕
  private func _flushDisplay() {
    preloadLock.lock()
    let content = preloadContent
    preloadLock.unlock()

    let totalLength = content.length
    guard totalLength > 0 else { return }

    if let tv = textView {
      tv.textStorage.setAttributedString(content)
      bindImageAttachmentsIfNeeded()
    }
    displayIndex = totalLength
    onUpdate?(content)
  }
}

// MARK: - Incremental Markdown Rendering

struct InkIncrementalMarkdownRenderer {
  struct Result {
    let content: NSAttributedString
    let refreshLocation: Int
  }

  private struct FenceMarker {
    let character: Character
    let count: Int
  }

  private var source = ""
  private var stableCharacterCount = 0
  private var stableContent = NSMutableAttributedString()

  init() {}

  mutating func reset() {
    source = ""
    stableCharacterCount = 0
    stableContent = NSMutableAttributedString()
  }

  mutating func replaceSource(_ source: String, configuration: InkConfiguration) -> Result {
    reset()
    return append(source, configuration: configuration)
  }

  mutating func append(_ chunk: String, configuration: InkConfiguration) -> Result {
    source += chunk

    let oldStableLength = stableContent.length
    let boundary = Self.stableBoundary(in: source, from: stableCharacterCount)
    if boundary > stableCharacterCount {
      let start = source.index(source.startIndex, offsetBy: stableCharacterCount)
      let end = source.index(source.startIndex, offsetBy: boundary)
      appendStable(String(source[start..<end]), configuration: configuration)
      stableCharacterCount = boundary
    }

    let result = NSMutableAttributedString(attributedString: stableContent)
    let tailStart = source.index(source.startIndex, offsetBy: stableCharacterCount)
    let tail = String(source[tailStart...])
    let latex = configuration.appearance.latexRendering
    if !tail.isEmpty,
       !Self.hasUnclosedLaTeXBlock(tail, latex: latex),
       !Self.hasUnclosedLaTeXInlineDelimiter(tail, latex: latex),
       !Self.hasUnclosedMermaidFence(tail) {
      if result.length > 0 {
        result.append(NSAttributedString(string: InkRenderConstants.blockSeparator))
      }
      result.append(InkAttributedRenderer.render(tail, configuration: configuration))
    }

    return Result(content: result, refreshLocation: oldStableLength)
  }

  /// 追加阶段不显示未闭合 `$$` / `\\[` 块；finish() 会走完整解析并稳定地以文本降级。
  private static func hasUnclosedLaTeXBlock(_ source: String, latex: InkLaTeXRendering) -> Bool {
    guard latex.isEnabled else { return false }
    let state = latexDelimiterState(in: source, latex: latex)
    return state.blockDollarOpen || state.blockBracketsOpen
  }

  /// 追加阶段不显示未闭合 `$...$` 或 `\\(...\\)`；完整配对、转义符号和代码区域不受影响。
  private static func hasUnclosedLaTeXInlineDelimiter(_ source: String, latex: InkLaTeXRendering) -> Bool {
    guard latex.isEnabled else { return false }
    let state = latexDelimiterState(in: source, latex: latex)
    return state.inlineParenthesesOpen || (latex.allowsInlineDollarDelimiter && state.inlineDollarOpen)
  }

  private struct LaTeXDelimiterState {
    var blockDollarOpen = false
    var blockBracketsOpen = false
    var inlineDollarOpen = false
    var inlineParenthesesOpen = false
    var inlineCodeTickCount: Int?
    var fencedCode: FenceMarker?
  }

  /// 最小流式状态机：只判断是否应保留活动尾部，不改变最终 Markdown / LaTeX 解析语义。
  private static func latexDelimiterState(in source: String, latex: InkLaTeXRendering) -> LaTeXDelimiterState {
    var state = LaTeXDelimiterState()
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false)

    for (lineIndex, line) in lines.enumerated() {
      let lineString = String(line)
      let trimmed = lineString.trimmingCharacters(in: .whitespaces)
      if let fence = state.fencedCode {
        if let closing = closingCodeFenceMarker(in: trimmed),
           closing.character == fence.character,
           closing.count >= fence.count {
          state.fencedCode = nil
        }
        continue
      }
      if let opening = openingCodeFenceMarker(in: trimmed) {
        state.fencedCode = opening
        continue
      }

      scanLaTeXDelimiters(in: lineString, latex: latex, state: &state)
      // `$...$` 不允许跨行；只有最后一个尚未完成的行内片段需要继续等待分片。
      if lineIndex < lines.count - 1 {
        state.inlineDollarOpen = false
      }
    }
    return state
  }

  private static func scanLaTeXDelimiters(in line: String, latex: InkLaTeXRendering, state: inout LaTeXDelimiterState) {
    guard latex.isEnabled else { return }
    var index = line.startIndex
    while index < line.endIndex {
      let character = line[index]
      if character == "`" {
        let tickCount = line[index...].prefix(while: { $0 == "`" }).count
        if let open = state.inlineCodeTickCount {
          if open == tickCount { state.inlineCodeTickCount = nil }
        } else {
          state.inlineCodeTickCount = tickCount
        }
        index = line.index(index, offsetBy: tickCount)
        continue
      }
      if state.inlineCodeTickCount != nil {
        index = line.index(after: index)
        continue
      }
      if !state.blockDollarOpen,
         line[index...].hasPrefix("$$"),
         !isEscaped(line, at: index) {
        state.blockDollarOpen = true
        index = line.index(index, offsetBy: 2)
        continue
      }
      if state.blockDollarOpen {
        if line[index...].hasPrefix("$$"), !isEscaped(line, at: index) {
          state.blockDollarOpen = false
          index = line.index(index, offsetBy: 2)
          continue
        }
        index = line.index(after: index)
        continue
      }
      if !state.blockBracketsOpen,
         line[index...].hasPrefix("\\["),
         !isEscaped(line, at: index) {
        state.blockBracketsOpen = true
        index = line.index(index, offsetBy: 2)
        continue
      }
      if state.blockBracketsOpen {
        if line[index...].hasPrefix("\\]"), !isEscaped(line, at: index) {
          state.blockBracketsOpen = false
          index = line.index(index, offsetBy: 2)
          continue
        }
        index = line.index(after: index)
        continue
      }
      if line[index...].hasPrefix("\\("), !isEscaped(line, at: index) {
        state.inlineParenthesesOpen.toggle()
        index = line.index(index, offsetBy: 2)
        continue
      }
      if line[index...].hasPrefix("\\)"), !isEscaped(line, at: index), state.inlineParenthesesOpen {
        state.inlineParenthesesOpen = false
        index = line.index(index, offsetBy: 2)
        continue
      }
      if latex.allowsInlineDollarDelimiter,
         character == "$", !isEscaped(line, at: index) {
        state.inlineDollarOpen.toggle()
      }
      index = line.index(after: index)
    }
  }

  private static func isEscaped(_ source: String, at index: String.Index) -> Bool {
    var slashCount = 0
    var cursor = index
    while cursor > source.startIndex {
      let previous = source.index(before: cursor)
      guard source[previous] == "\\" else { break }
      slashCount += 1
      cursor = previous
    }
    return !slashCount.isMultiple(of: 2)
  }

  /// Mermaid 围栏未闭合时保留在活动 buffer，避免 append 阶段暴露围栏符号或重复生成图片。
  private static func hasUnclosedMermaidFence(_ source: String) -> Bool {
    var fence: FenceMarker?
    for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if let open = fence {
        if let closing = closingCodeFenceMarker(in: trimmed),
           closing.character == open.character,
           closing.count >= open.count {
          fence = nil
        }
        continue
      }
      guard let opening = openingCodeFenceMarker(in: trimmed) else { continue }
      let language = trimmed.dropFirst(opening.count).trimmingCharacters(in: .whitespacesAndNewlines)
      if InkMermaidFence.isMermaid(language: String(language)) {
        fence = opening
      }
    }
    return fence != nil
  }

  private mutating func appendStable(_ markdown: String, configuration: InkConfiguration) {
    let rendered = InkAttributedRenderer.render(markdown, configuration: configuration)
    guard rendered.length > 0 else { return }
    if stableContent.length > 0 {
      stableContent.append(NSAttributedString(string: InkRenderConstants.blockSeparator))
    }
    stableContent.append(rendered)
  }

  static func stableBoundary(in source: String, from startOffset: Int = 0) -> Int {
    var index = source.index(source.startIndex, offsetBy: startOffset)
    var openFence: FenceMarker?
    var lastSafeOffset = startOffset

    while index < source.endIndex {
      guard let newline = source[index...].firstIndex(of: "\n") else { break }
      let line = source[index..<newline]
      let lineEnd = source.index(after: newline)
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let offset = source.distance(from: source.startIndex, to: lineEnd)

      if let fence = openFence {
        if let closingFence = closingCodeFenceMarker(in: trimmed),
           closingFence.character == fence.character,
           closingFence.count >= fence.count {
          openFence = nil
          lastSafeOffset = offset
        }
      } else if let openingFence = openingCodeFenceMarker(in: trimmed) {
        openFence = openingFence
      } else if isATXHeading(trimmed) || InkLineClassifier.classify(trimmed) == .thematicBreak {
        // ponytail: blank lines are not stable; list/blockquote containers can continue after them.
        lastSafeOffset = offset
      }

      index = lineEnd
    }

    return lastSafeOffset
  }

  private static func openingCodeFenceMarker(in trimmedLine: String) -> FenceMarker? {
    guard let first = trimmedLine.first, first == "`" || first == "~" else { return nil }
    let count = trimmedLine.prefix(while: { $0 == first }).count
    guard count >= 3 else { return nil }
    return FenceMarker(character: first, count: count)
  }

  private static func closingCodeFenceMarker(in trimmedLine: String) -> FenceMarker? {
    guard let marker = openingCodeFenceMarker(in: trimmedLine) else { return nil }
    guard trimmedLine.dropFirst(marker.count).isEmpty else { return nil }
    return marker
  }

  private static func isATXHeading(_ trimmedLine: String) -> Bool {
    let markerCount = trimmedLine.prefix(while: { $0 == "#" }).count
    guard (1...6).contains(markerCount) else { return false }
    guard trimmedLine.count == markerCount || trimmedLine.dropFirst(markerCount).first == " " else { return false }
    return true
  }
}

// MARK: - Streaming Performance Benchmark

/// 流式 Markdown 渲染性能基准工具。
@_spi(Performance) public enum InkStreamingPerformanceBenchmark {
  /// 一次流式渲染性能测量的结果。
  public struct Result {
    /// 分片数量。
    public let chunkCount: Int

    /// 每次追加后全量渲染的耗时。
    public let fullRenderSeconds: TimeInterval

    /// 使用增量渲染的耗时。
    public let incrementalRenderSeconds: TimeInterval

    /// 增量渲染最终可见文本是否与全量渲染一致。
    public let outputMatches: Bool

    /// 增量渲染的最终结果，用于示例页预览。
    public let preview: NSAttributedString
  }

  /// 生成示例 App 和测试共用的流式 Markdown 分片。
  public static func makeChunks() -> [String] {
    let source = Array(repeating: benchmarkSection, count: 24).joined()
    return stride(from: 0, to: source.count, by: 48).map { offset in
      let start = source.index(source.startIndex, offsetBy: offset)
      let length = min(48, source.distance(from: start, to: source.endIndex))
      let end = source.index(start, offsetBy: length)
      return String(source[start..<end])
    }
  }

  /// 每次追加分片后重新渲染完整 Markdown。
  public static func renderFullyAfterEachChunk(_ chunks: [String], configuration: InkConfiguration = .standard) -> NSAttributedString {
    var buffer = ""
    var result = NSAttributedString()
    for chunk in chunks {
      buffer += chunk
      result = InkAttributedRenderer.render(buffer, configuration: configuration)
    }
    return result
  }

  /// 使用增量渲染处理全部分片。
  public static func renderIncrementally(_ chunks: [String], configuration: InkConfiguration = .standard) -> NSAttributedString {
    var renderer = InkIncrementalMarkdownRenderer()
    var result = NSAttributedString()
    for chunk in chunks {
      result = renderer.append(chunk, configuration: configuration).content
    }
    return result
  }

  /// 测量全量重渲染和增量渲染的耗时。
  public static func measure(chunks: [String] = makeChunks(), configuration: InkConfiguration = .standard) -> Result {
    let fullStart = CACurrentMediaTime()
    let fullResult = renderFullyAfterEachChunk(chunks, configuration: configuration)
    let fullSeconds = CACurrentMediaTime() - fullStart

    let incrementalStart = CACurrentMediaTime()
    let incrementalResult = renderIncrementally(chunks, configuration: configuration)
    let incrementalSeconds = CACurrentMediaTime() - incrementalStart

    return Result(
      chunkCount: chunks.count,
      fullRenderSeconds: fullSeconds,
      incrementalRenderSeconds: incrementalSeconds,
      outputMatches: fullResult.string == incrementalResult.string,
      preview: incrementalResult
    )
  }

  private static let benchmarkSection = """
  ## 流式输出段落

  AI 正在生成一段包含 **强调**、`inline code` 和 [链接](https://example.com) 的 Markdown 内容。

  - 第一条包含中文和 English text
  - 第二条继续补充上下文
  - 第三条用于扩大解析体量

  ```swift
  let value = "streaming markdown"
  print(value)
  ```

  > 引用块也会出现在实际回答里。

  """
}

// MARK: - DisplayLink Target (避免循环引用)

private final class DisplayLinkTarget {
  weak var renderer: InkStreamRenderer?

  init(renderer: InkStreamRenderer) {
    self.renderer = renderer
  }

  @objc func onFrame() {
    renderer?.onDisplayFrame()
  }
}
