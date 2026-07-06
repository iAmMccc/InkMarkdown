import UIKit
import Markdown

/// 流式渲染器：把一段会**持续增长**的 Markdown 文本，增量渲染为 `NSAttributedString`，
/// 并支持直接绑定 `UITextView` 进行差量更新。
///
/// ## 架构：解析-显示双缓冲
///
/// ```
/// SSE chunk 到达 → 后台串行队列全量解析 → preloadContent（缓冲区）
///                                              ↓
///                          CADisplayLink 按帧率 → 逐步截取 → textStorage 增量更新
/// ```
///
/// - 解析与显示完全解耦：解析慢不影响吐字动画平滑
/// - 显示侧每帧开销恒定 O(1)：只做 attributedSubstring 截取 + textStorage append
/// - 支持暂停/恢复显示（用户滑动时暂停）
///
/// ### 使用方式
/// ```swift
/// let renderer = InkStreamRenderer(configuration: .standard)
/// renderer.bindTextView(textView)
/// renderer.append("## 标题\n")     // SSE 每收到分片就 append
/// renderer.finish()                // 流结束
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

  /// 标记是否有待显示的新内容（避免无效帧处理）
  private var hasPendingContent: Bool = false

  /// 上次记录的 textView 内容高度，用于检测高度变化
  private var lastContentHeight: CGFloat = 0

  /// 解析版本号：每次后台解析完成递增，用于检测前缀样式是否变化
  private var parseVersion: UInt64 = 0

  /// 上次应用到 textView 的解析版本
  private var lastAppliedParseVersion: UInt64 = 0

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
    hasPendingContent = true

    // buffer 超过阈值后停止解析——最终 warmUp 也只渲染 50K，流式中超出部分无意义
    guard buffer.count <= Self.maxParseLength else { return }

    let currentBuffer = buffer
    let config = configuration
    parseQueue.async { [weak self] in
      let rendered = InkAttributedRenderer.render(currentBuffer, configuration: config)
      guard let self = self else { return }
      self.preloadLock.lock()
      self.preloadContent = rendered
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
    finalParseCompleted = false
    hasPendingContent = false
    parseVersion = 0
    lastAppliedParseVersion = 0

    let config = configuration
    if source.isEmpty {
      preloadLock.lock()
      preloadContent = NSAttributedString()
      preloadLock.unlock()
      if let tv = textView {
        tv.textStorage.setAttributedString(NSAttributedString())
      }
      onUpdate?(NSAttributedString())
    } else {
      parseQueue.async { [weak self] in
        let rendered = InkAttributedRenderer.render(source, configuration: config)
        guard let self = self else { return }
        self.preloadLock.lock()
        self.preloadContent = rendered
        self.preloadLock.unlock()
        self.hasPendingContent = true
        DispatchQueue.main.async { [weak self] in
          self?.startDisplayLink()
        }
      }
    }
  }

  /// 标记流结束。displayLink 会继续逐字吐完剩余内容，全部完成后触发 onFinishDisplay。
  public func finish() {
    var currentBuffer = buffer
    if currentBuffer.count > Self.maxParseLength {
      let endIndex = currentBuffer.index(currentBuffer.startIndex, offsetBy: Self.maxParseLength)
      currentBuffer = String(currentBuffer[..<endIndex])
    }
    let config = configuration
    isFinished = true
    finalParseCompleted = false

    parseQueue.async { [weak self] in
      let rendered = InkAttributedRenderer.render(currentBuffer, configuration: config)
      guard let self = self else { return }
      self.preloadLock.lock()
      self.preloadContent = rendered
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
    preloadLock.unlock()

    let totalLength = content.length

    // 解析后长度可能缩短（如链接/图片语法解析后只保留可见文本），
    // 或解析版本变化导致前缀样式重排——全量刷新 textView
    if totalLength < displayIndex || parseVersion != lastAppliedParseVersion {
      displayIndex = min(displayIndex, totalLength)
      lastAppliedParseVersion = parseVersion
      if let tv = textView {
        let showLength = min(displayIndex, totalLength)
        let displayed = content.attributedSubstring(from: NSRange(location: 0, length: showLength))
        tv.textStorage.setAttributedString(displayed)
      }
      onUpdate?(content.attributedSubstring(from: NSRange(location: 0, length: displayIndex)))
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
    }
    displayIndex = totalLength
    onUpdate?(content)
  }
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
