import UIKit
import Markdown

/// 流式 Markdown 输入上限的不可变快照。
///
/// 该快照由会话在创建时生成，再由会话与底层 renderer 共同持有，保证
/// canonical source 的接收、解析和终态提升使用同一个上限。传入 `0` 或负数
/// 时视为无效，自动回退到默认值 `50_000`；不会因此取消长度保护。
@_spi(InkMarkdown)
public struct InkStreamSourceLimit: Sendable {
  /// 默认最大源文本长度，保持 0.0.1 的行为。
  public static let defaultMaximum = 50_000

  /// 归一化后的最大源文本长度。
  public let maximum: Int

  /// 创建上限快照；非正数回退到 ``defaultMaximum``。
  public init(maximum requestedMaximum: Int) {
    self.maximum = requestedMaximum > 0 ? requestedMaximum : Self.defaultMaximum
  }

  /// 返回在当前 canonical source 后仍可接受的分片；超出部分不返回。
  public func acceptedChunk(_ chunk: String, after source: String) -> String {
    let remaining = maximum - source.count
    guard remaining > 0, !chunk.isEmpty else { return "" }
    guard chunk.count > remaining else { return chunk }
    return String(chunk.prefix(remaining))
  }

  /// 将任意源文本收敛为不超过上限的 canonical source。
  public func canonicalSource(_ source: String) -> String {
    guard source.count > maximum else { return source }
    return String(source.prefix(maximum))
  }

  /// 判断分片是否已经由该快照完整接受；canonical append seam 不在此处截断。
  public func canAppend(_ chunk: String, after source: String) -> Bool {
    guard source.count <= maximum else { return false }
    return chunk.count <= maximum - source.count
  }
}

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
/// - 解析与显示分阶段调度：显示侧消费最近一次已准备的内容
/// - 显示侧使用 attributedSubstring 与 textStorage 增量更新；substring、布局和测量成本取决于内容与视图状态，不承诺 O(1)
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
/// 流式渲染器：所有公开 API（append/finish/reset/updateConfiguration/bindTextView/unbindTextView）必须在主线程调用。
public final class InkStreamRenderer: @unchecked Sendable {

  // MARK: - Public Properties

  public private(set) var configuration: InkConfiguration

  /// 渲染产物有**可见变化**时回调（未绑定 textView 时，每次解析更新都会回调）。
  /// 绑定 textView 且变更点位于已显示范围之外（纯尾部新增、显示内容无变化）时，
  /// 节流路径会跳过重写与回调——此时宿主收到的上一份内容仍然有效。
  public var onUpdate: ((NSAttributedString) -> Void)?

  /// 单个会话默认可解析的最大 Markdown 字符数；保留此静态常量以兼容既有调用方。
  public static let maximumSourceLength = InkStreamSourceLimit.defaultMaximum

  /// 当前 renderer 创建时固定的最大 Markdown 源文本长度。
  ///
  /// 该值是不可变快照。传入 initializer 的 `0` 或负数会回退为
  /// ``InkStreamRenderer/maximumSourceLength``。
  public let maximumSourceLength: Int

  /// 每帧显示的字符数。60fps 下：1=60字/秒，2=120字/秒，3=180字/秒。
  /// 非正值按每帧 1 个字符推进；大于剩余长度时仅显示剩余内容。
  public var charactersPerFrame: Int = 2

  /// 每帧显示内容变化时回调（用于通知外部更新 cell 高度）。
  public var onDisplayUpdate: (() -> Void)?

  /// Mermaid 块事件回调
  public var onMermaidBlockUpdate: ((_ blockID: String, _ source: String, _ isComplete: Bool) -> Void)?


  /// 最终全量解析完成时回调；此时显示可能仍在逐帧追赶最终内容。
  public var onFinishParse: (() -> Void)?

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

  /// 自上次显示端消费快照以来，所有解析结果中最早需要刷新的起点。
  ///
  /// `nil` 表示没有尚未消费的解析结果。多个后台解析结果可能在同一显示帧
  /// 之间完成，不能让后完成的结果覆盖更早的 dirty location。
  private var preloadRefreshLocation: Int?

  private struct PreloadSnapshot {
    let content: NSAttributedString
    let parseVersion: UInt64
    let refreshLocation: Int
    let finalParseCompleted: Bool
  }

  /// 渲染代次：reset/finish 后丢弃旧后台解析结果，避免过期任务回写
  private var renderGeneration: UInt64 = 0

  /// 后台队列独占访问的增量渲染缓存
  private var incrementalRenderer = InkIncrementalMarkdownRenderer()

  /// sourceFilter 路径上一次**被接受**的全量渲染结果（仅 parseQueue 上读写），
  /// 作为本次全量渲染的前缀 diff 基线：textStorage 重写范围由此收敛到
  /// "本次 append 真正影响的范围"，而不是每次都从 0 全量重写。
  private var lastFilteredContent: NSAttributedString?

  /// 创建时注入的不可变上限快照；session 与 renderer 共享同一实例。
  private let sourceLimit: InkStreamSourceLimit

  // MARK: - Init

  /// 创建一个流式 Markdown renderer。
  /// - Parameters:
  ///   - configuration: 此 renderer 使用的 Markdown 渲染配置快照。
  ///   - maximumSourceLength: 此 renderer 可接受的最大 Markdown 字符数。必须为正数；
  ///     `0` 或负数视为无效并回退到默认 `50_000`。
  @MainActor
  public init(
    configuration: InkConfiguration = .standard,
    maximumSourceLength: Int = InkStreamRenderer.maximumSourceLength
  ) {
    self.configuration = configuration
    let sourceLimit = InkStreamSourceLimit(maximum: maximumSourceLength)
    self.sourceLimit = sourceLimit
    self.maximumSourceLength = sourceLimit.maximum
  }

  /// 以既有不可变上限快照创建 renderer。
  ///
  /// 该 initializer 供 `InkMarkdownRenderSession` 复用同一个 source-limit
  /// snapshot；普通调用方应使用带 `maximumSourceLength` 的公开 initializer。
  @_spi(InkMarkdown)
  @MainActor
  public init(configuration: InkConfiguration = .standard, sourceLimit: InkStreamSourceLimit) {
    self.configuration = configuration
    self.sourceLimit = sourceLimit
    self.maximumSourceLength = sourceLimit.maximum
  }

  /// 替换渲染配置，并以给定完整源文本重新开始解析和显示。
  ///
  /// 调用方须在主线程调用；进行中的后台解析结果会由渲染代次丢弃。
  /// - Parameters:
  ///   - configuration: 后续解析与显示使用的新配置快照。
  ///   - source: 作为唯一输入源重新解析的完整 Markdown 文本。
  @MainActor
  public func updateConfiguration(_ configuration: InkConfiguration, source: String) {
    self.configuration = configuration
    reset(to: source)
  }

  /// 仅同步后续渲染使用的配置快照，不重置当前流或启动新的显示周期。
  ///
  /// SwiftUI adapter 在已完成会话切换 trait 时使用此 seam：终态块由 adapter
  /// 重新渲染，renderer 则保留最新配置供后续 `reset()` / `append()` 使用。
  /// 公开 ``updateConfiguration(_:source:)`` 仍保留重解析语义。
  @_spi(InkMarkdown)
  @MainActor
  public func updateConfigurationSnapshot(_ configuration: InkConfiguration) {
    self.configuration = configuration
  }

  /// 以当前绑定的 `UITextView` 宿主环境重新绑定行内图片。
  ///
  /// SwiftUI adapter 在流式文本视图的实际宽度、window screen 或 display scale
  /// 变化后调用此 seam。显示上下文由 `InkImageAttachment` 的统一宿主 helper 从
  /// 同一个 text view 解析，避免跨 host 各自猜测屏幕尺寸；未挂载或尚无有效宽度时
  /// helper 会等待下一次有效 layout。
  @_spi(InkMarkdown)
  @MainActor
  public func refreshImageAttachments() {
    bindImageAttachmentsIfNeeded()
  }

  deinit {
    displayLink?.invalidate()
  }

  // MARK: - Public API

  /// 绑定 UITextView，后续 append/finish 会自动驱动其 textStorage 更新。
  /// 总是用当前 renderer 的显示快照覆盖 textView；空快照也必须清空旧会话内容。
  @MainActor
  public func bindTextView(_ tv: UITextView) {
    self.textView = tv

    // textView 可能由另一个 session 复用。绑定即转移内容所有权，不能把新内容追加到旧 storage。
    preloadLock.lock()
    let content = preloadContent
    preloadLock.unlock()
    let showLength = min(displayIndex, content.length)
    let displayed = content.attributedSubstring(from: NSRange(location: 0, length: showLength))
    tv.textStorage.setAttributedString(displayed)
    if showLength > 0 {
      bindImageAttachmentsIfNeeded()
    }

    if !buffer.isEmpty || isFinished {
      startDisplayLink()
    }
  }

  /// 解绑 textView 并快进 displayIndex 到当前已解析位置。
  /// 用于 cell 离开屏幕时：不再做 textStorage 操作，但逻辑上视为已吐出。
  @MainActor
  public func unbindTextView() {
    textView = nil
    // 快进到已解析的最新位置。
    preloadLock.lock()
    displayIndex = preloadContent.length
    let shouldFinish = isFinished && finalParseCompleted
    preloadLock.unlock()

    if shouldFinish {
      completeFinishDisplay()
    }
  }

  /// 追加一段新到达的 Markdown 文本分片。
  /// 内部将在后台队列异步解析，不阻塞主线程。超过创建时上限的尾部不会进入
  /// renderer 的 canonical source。
  @MainActor
  public func append(_ chunk: String) {
    // finish() 已把 buffer 固化为终态：此后到达的分片一律安全忽略。
    // 若放行会污染终态——incrementalRenderer 已在 finish() 里 reset，追加会基于空状态
    // 重渲出残缺内容，且 parseVersion 继续递增会让 onDisplayFrame 在错误时机
    // 覆盖 finalize 结果或提前触发 onFinishDisplay。
    guard !isFinished else { return }

    let acceptedChunk = sourceLimit.acceptedChunk(chunk, after: buffer)
    guard !acceptedChunk.isEmpty else { return }
    appendAcceptedChunk(acceptedChunk)
  }

  /// 接收已由同一 source-limit snapshot 接受的 canonical remainder 分片。
  ///
  /// 该 SPI seam 供 SwiftUI session 使用：session 先以完整 canonical source
  /// 接受输入，再把 remainder 交给 renderer，避免两个模块各自截断同一输入。
  @_spi(InkMarkdown)
  @MainActor
  public func appendCanonical(_ chunk: String) {
    guard !isFinished, !chunk.isEmpty, sourceLimit.canAppend(chunk, after: buffer) else { return }
    appendAcceptedChunk(chunk)
  }

  @MainActor
  private func appendAcceptedChunk(_ acceptedChunk: String) {
    buffer += acceptedChunk
    if textView != nil || onUpdate != nil {
      startDisplayLink()
    }

    let currentBuffer = buffer
    let config = configuration.capturingRenderEnvironmentForBackgroundParse()
    let generation = currentRenderGeneration()
    parseQueue.async { [weak self] in
      guard let self = self else { return }
      let result: InkIncrementalMarkdownRenderer.Result
      if config.sourceFilter == nil {
        result = self.incrementalRenderer.append(acceptedChunk, configuration: config)
      } else {
        // sourceFilter 依赖完整源文本，无法像无 filter 路径那样按稳定边界做源级增量，
        // 只能对整段 buffer 全量解析（保证 filter 语义正确）；但主线程 textStorage
        // 不必随之全量重写：与上一次全量渲染做前缀 diff，把 refreshLocation 定位到
        // 本次 append 实际影响的范围起点，显示层只重写该点之后的尾部。
        let rendered = InkAttributedRenderer.render(currentBuffer, configuration: config)
        let refresh = Self.stablePrefixLength(between: self.lastFilteredContent, and: rendered)
        result = InkIncrementalMarkdownRenderer.Result(content: rendered, refreshLocation: refresh)
      }
      self.preloadLock.lock()
      guard self.renderGeneration == generation else {
        self.preloadLock.unlock()
        return
      }
      if config.sourceFilter != nil {
        // 只在渲染代次被接受后才更新 diff 基线，避免过期闭包污染后续 diff。
        self.lastFilteredContent = result.content
      }
      self.preloadContent = result.content
      self.preloadRefreshLocation = Self.mergingEarliestRefreshLocation(
        current: self.preloadRefreshLocation,
        incoming: result.refreshLocation
      )
      self.parseVersion += 1
      self.preloadLock.unlock()
    }
  }

  /// 用完整文本整体重置。
  @MainActor
  public func reset(to source: String = "") {
    stopDisplayLink()
    let canonicalSource = sourceLimit.canonicalSource(source)
    buffer = canonicalSource
    displayIndex = 0
    isFinished = false
    lastAppliedParseVersion = 0
    lastContentHeight = 0

    preloadLock.lock()
    renderGeneration += 1
    let generation = renderGeneration
    finalParseCompleted = false
    parseVersion = 0
    preloadRefreshLocation = canonicalSource.isEmpty ? nil : 0
    preloadLock.unlock()

    let config = configuration.capturingRenderEnvironmentForBackgroundParse()
    if canonicalSource.isEmpty {
      parseQueue.async { [weak self] in
        self?.incrementalRenderer.reset()
        // diff 基线一并清空：只在 parseQueue 上触碰 lastFilteredContent，避免跨线程竞争。
        self?.lastFilteredContent = nil
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
          result = self.incrementalRenderer.replaceSource(canonicalSource, configuration: config)
        } else {
          self.incrementalRenderer.reset()
          result = InkIncrementalMarkdownRenderer.Result(
            content: InkAttributedRenderer.render(canonicalSource, configuration: config),
            refreshLocation: 0
          )
        }
        self.preloadLock.lock()
        guard self.renderGeneration == generation else {
          self.preloadLock.unlock()
          return
        }
        if config.sourceFilter != nil {
          // 重置后的全量渲染成为新的 diff 基线（refreshLocation 固定为 0 = 整体重建）。
          self.lastFilteredContent = result.content
        }
        self.preloadContent = result.content
        self.preloadRefreshLocation = Self.mergingEarliestRefreshLocation(
          current: self.preloadRefreshLocation,
          incoming: result.refreshLocation
        )
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
  @MainActor
  public func finish() {
    let currentBuffer = buffer
    let config = configuration.capturingRenderEnvironmentForBackgroundParse()
    isFinished = true
    preloadLock.lock()
    renderGeneration += 1
    let generation = renderGeneration
    finalParseCompleted = false
    preloadRefreshLocation = 0
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
      if config.sourceFilter != nil {
        // 终态全量渲染同样更新 diff 基线，维持"lastFilteredContent == 最近被接受的全量渲染"。
        self.lastFilteredContent = rendered
      }
      self.preloadLock.unlock()
      DispatchQueue.main.async { [weak self] in
        self?.handleFinalParseCompleted()
      }
    }
  }

  /// 当前已渲染的完整结果（可用于缓存）。
  public func currentAttributedString() -> NSAttributedString {
    preloadLock.lock()
    let content = preloadContent
    preloadLock.unlock()
    return content
  }

  /// 当前已接受的 canonical Markdown 源文本；仅供 adapter 与契约测试核对输入一致性。
  @_spi(InkMarkdown)
  @MainActor
  public var canonicalSource: String { buffer }

  private func currentRenderGeneration() -> UInt64 {
    preloadLock.lock()
    let generation = renderGeneration
    preloadLock.unlock()
    return generation
  }

  /// 计算两次全量渲染产物从开头起完全一致（字符与属性均相同）的最长 UTF-16 长度。
  ///
  /// 为什么需要它：sourceFilter 依赖完整源文本，每次 append 只能整段全量解析
  /// （无 filter 路径的源级稳定边界在此不可用），但主线程 textStorage 不必跟着全量重写。
  /// 返回的稳定前缀长度就是"本次 append 真正影响的范围"起点：显示层只重写该点之后的尾部，
  /// 主线程成本从 O(累计长度) 降为 O(本次变化)。
  ///
  /// 前缀内字符相同但属性不同（典型如新增输入改变了前方块级结构，例如段落被重解析成
  /// setext heading）时整体回退到 0 全量重写——宁可多重写，也不能漏掉重解析改变的前缀样式。
  private static func stablePrefixLength(between old: NSAttributedString?, and new: NSAttributedString) -> Int {
    guard let old = old else { return 0 }
    let limit = min(old.length, new.length)
    guard limit > 0 else { return 0 }
    let oldUnits = old.string as NSString
    let newUnits = new.string as NSString

    // 字符级扫描：流式场景通常只差在尾部，扫描在首个差异点即停，均摊代价低。
    var firstDiff = 0
    while firstDiff < limit,
          oldUnits.character(at: firstDiff) == newUnits.character(at: firstDiff) {
      firstDiff += 1
    }

    // 把差异点对齐到组合字符序列边界，避免落在代理对/组合记号中间，
    // 否则 attributedSubstring 会产出孤立半代理或拆散的组合字符，显示为乱码。
    if firstDiff < limit {
      let composed = oldUnits.rangeOfComposedCharacterSequence(at: firstDiff)
      if composed.location != NSNotFound {
        firstDiff = composed.location
      }
    }

    // 属性一致性校验：字符相同不代表样式相同；前缀内任何属性差异都整体回退。
    let oldPrefix = old.attributedSubstring(from: NSRange(location: 0, length: firstDiff))
    let newPrefix = new.attributedSubstring(from: NSRange(location: 0, length: firstDiff))
    if oldPrefix.isEqual(to: newPrefix) {
      return firstDiff
    }
    return 0
  }

  /// 合并自上次显示消费以来到达的解析结果。显示端只在同一把锁内消费并
  /// 清空该槽位，因此解析结果若在消费之后到达，会进入下一显示批次。
  static func mergingEarliestRefreshLocation(current: Int?, incoming: Int) -> Int {
    let incoming = max(0, incoming)
    guard let current else { return incoming }
    return min(current, incoming)
  }

  private func consumePreloadSnapshot() -> PreloadSnapshot {
    preloadLock.lock()
    let content = preloadContent
    let refreshLocation = min(preloadRefreshLocation ?? content.length, content.length)
    let snapshot = PreloadSnapshot(
      content: content,
      parseVersion: parseVersion,
      refreshLocation: refreshLocation,
      finalParseCompleted: finalParseCompleted
    )
    // 解析结果在此锁释放后到达时，写入的是下一批 dirty location；不会被本次消费覆盖。
    preloadRefreshLocation = nil
    preloadLock.unlock()
    return snapshot
  }

  /// 把 `content[0..<showLength)` 的刷新应用到 textStorage：只重写 `refreshLocation`
  /// 之后受影响的尾部，跳过完全无变化的帧。
  ///
  /// 返回本次重写的绑定范围（供附件绑定使用）；返回 `nil` 表示显示内容无需变化
  /// （变更点超出已显示范围且无需裁剪），调用方应跳过 onUpdate/附件/测高等副作用。
  ///
  /// 为什么抽成静态方法：显示刷新是"节流 + 差量重写"的纯函数逻辑，抽离后可以被
  /// 单元测试直接驱动——CADisplayLink 在主 RunLoop 上运行，集成测试环境无法触发
  /// `onDisplayFrame`，若不抽离，这个分支将永远处于测试盲区（曾经如此）。
  @MainActor
  static func refreshTextStorage(
    textStorage: NSTextStorage,
    content: NSAttributedString,
    refreshLocation: Int,
    showLength: Int
  ) -> NSRange? {
    let start = min(refreshLocation, textStorage.length, showLength)
    // 两个重写时机：变更点落在已显示范围内（start < showLength，需重写/插入新尾部），
    // 或内容收缩需要裁剪（textStorage 比目标长）。
    if start < showLength || textStorage.length > showLength {
      let replacement = content.attributedSubstring(from: NSRange(location: start, length: showLength - start))
      textStorage.replaceCharacters(
        in: NSRange(location: start, length: textStorage.length - start),
        with: replacement
      )
      return NSRange(location: start, length: showLength - start)
    }
    return nil
  }

  // MARK: - Display Link

  /// 驱动一次显示帧；仅供性能与显示一致性契约测试使用。
  @_spi(Performance)
  @MainActor
  public func driveDisplayFrameForTesting() {
    onDisplayFrame()
  }

  @MainActor
  private func startDisplayLink() {
    guard displayLink == nil else { return }
    let link = CADisplayLink(target: DisplayLinkTarget(renderer: self), selector: #selector(DisplayLinkTarget.onFrame))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  @MainActor
  private func stopDisplayLink() {
    displayLink?.invalidate()
    displayLink = nil
  }

  /// CADisplayLink 每帧回调
  @MainActor
  fileprivate func onDisplayFrame() {
    guard !isDisplayPaused else { return }

    let snapshot = consumePreloadSnapshot()
    let content = snapshot.content
    let parseVersion = snapshot.parseVersion
    let refreshLocation = snapshot.refreshLocation
    let finalParseCompleted = snapshot.finalParseCompleted

    let totalLength = content.length

    // 解析后长度可能缩短（如链接/图片语法解析后只保留可见文本），
    // 或当前开放块样式变化——只刷新受影响范围
    if totalLength < displayIndex || parseVersion != lastAppliedParseVersion {
      displayIndex = min(displayIndex, totalLength)
      lastAppliedParseVersion = parseVersion

      var bindRange: NSRange?
      var displayedChanged = false
      if let tv = textView {
        let showLength = min(displayIndex, totalLength)
        // 节流：变更起点在已显示范围之外（纯尾部新增）且无需裁剪时，本次不重写任何
        // 已显示内容——已显示前缀与上一已接受解析完全一致，textStorage 重写、onUpdate、
        // 附件绑定与高度测量全部跳过，避免每个 parseVersion 都在主线程做
        // O(已显示长度) 的无谓工作（sourceFilter 路径曾经的 O(n²) 来源）。
        // 多个 parseVersion 已按帧合并：本方法每帧只读取最新的 parseVersion，
        // 帧间多次 append 只触发一次重写；新字符由下方逐字追加路径负责展示。
        bindRange = Self.refreshTextStorage(
          textStorage: tv.textStorage,
          content: content,
          refreshLocation: refreshLocation,
          showLength: showLength
        )
        displayedChanged = bindRange != nil
      } else {
        // 未绑定 textView：没有 textStorage 可节流，解析版本变化必须通知宿主。
        displayedChanged = true
      }

      if displayedChanged {
        onUpdate?(content.attributedSubstring(from: NSRange(location: 0, length: displayIndex)))
        bindImageAttachmentsIfNeeded(in: bindRange)
        notifyHeightChangeIfNeeded()
      }
      if isFinished && finalParseCompleted && displayIndex >= totalLength {
        completeFinishDisplay()
      }
      return
    }

    guard totalLength > displayIndex else {
      if isFinished && finalParseCompleted {
        completeFinishDisplay()
      }
      return
    }

    // Clamp the delta before adding it to the cursor. Public speed values may be
    // Int.max, zero or negative; none may overflow or move the cursor backwards.
    let chunkSize = min(max(1, charactersPerFrame), totalLength - displayIndex)
    let newDisplayIndex = displayIndex + chunkSize

    guard let tv = textView else {
      displayIndex = newDisplayIndex
      let substring = content.attributedSubstring(from: NSRange(location: 0, length: newDisplayIndex))
      onUpdate?(substring)
      if isFinished && finalParseCompleted && displayIndex >= totalLength {
        completeFinishDisplay()
      }
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
      completeFinishDisplay()
    }
  }

  @MainActor
  private func handleFinalParseCompleted() {
    guard isFinished else { return }
    onFinishParse?()

    guard textView == nil else {
      startDisplayLink()
      return
    }

    preloadLock.lock()
    let content = preloadContent
    displayIndex = content.length
    preloadLock.unlock()
    onUpdate?(content)
    completeFinishDisplay()
  }

  @MainActor
  private func completeFinishDisplay() {
    guard isFinished else { return }
    stopDisplayLink()
    let callback = onFinishDisplay
    onFinishDisplay = nil
    callback?()
  }

  @MainActor
  private func notifyHeightChangeIfNeeded() {
    let containerWidth = textView?.textContainer.size.width ?? 0
    guard containerWidth > 0, let tv = textView else { return }
    let newHeight = tv.sizeThatFits(CGSize(width: containerWidth, height: .greatestFiniteMagnitude)).height
    if abs(newHeight - lastContentHeight) > 1 {
      lastContentHeight = newHeight
      onDisplayUpdate?()
    }
  }

  @MainActor
  private func bindImageAttachmentsIfNeeded(in range: NSRange? = nil) {
    // 为什么 用 assumeIsolated 而不是 await MainActor.run：
    // 本方法所有调用点（bindTextView / onDisplayFrame / _flushDisplay）都保证在主线程——
    // displayLink 只加入 .main run loop、_flushDisplay 只经 DispatchQueue.main.async 进入、
    // 公开 API 契约也要求主线程调用。assumeIsolated 在成立时同步直通，避免在
    // CADisplayLink 回调里引入 actor hop 造成的乱序或死锁；一旦未来有调用点移到
    // 后台线程，这里会立刻 fatal error 兜底，而不是静默在错误的线程上操作 TextKit。
    MainActor.assumeIsolated {
      guard let tv = textView else { return }
      InkImageAttachment.bindAttachments(
        in: tv,
        onHeightChange: { [weak self] in
          self?.notifyHeightChangeIfNeeded()
        },
        range: range
      )
    }
  }

  // MARK: - Flush

  /// 立即将所有已解析内容显示完毕
  @MainActor
  private func _flushDisplay() {
    let content = consumePreloadSnapshot().content

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
  @MainActor
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
  @MainActor
  public static func renderIncrementally(_ chunks: [String], configuration: InkConfiguration = .standard) -> NSAttributedString {
    var renderer = InkIncrementalMarkdownRenderer()
    var result = NSAttributedString()
    for chunk in chunks {
      result = renderer.append(chunk, configuration: configuration).content
    }
    return result
  }

  /// 测量全量重渲染和增量渲染的耗时。
  @MainActor
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

@MainActor
private final class DisplayLinkTarget {
  weak var renderer: InkStreamRenderer?

  init(renderer: InkStreamRenderer) {
    self.renderer = renderer
  }

  @objc func onFrame() {
    renderer?.onDisplayFrame()
  }
}
