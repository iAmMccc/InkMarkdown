//
//  InkMarkdownRenderSession.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import Combine
import Foundation
import UIKit

/// 流式 Markdown 渲染会话管理类。
///
/// 会话是单条流式 Markdown 的唯一输入源与生命周期所有者：宿主负责 transport，
/// 会话负责接收 delta、结束、取消、重置与终态 Block Promotion。
///
/// - Important: 所有公开方法均需在主线程调用。
/// - Note: `@ObservedObject` 会订阅对象上任意 `@Published` 变更；SwiftUI 入口不得
///   `@ObservedObject` 整个 session。`isPromoted` 是唯一会驱动 SwiftUI 换树的发布，
///   通过 0-delay default-mode timer 离开当前 view update 后再写入。
@MainActor
public final class InkMarkdownRenderSession: ObservableObject {

  /// 流式渲染会话状态。
  public enum State: Sendable, Equatable {
    /// 初始状态或重置后的空闲状态。
    case idle
    /// 正在接收流式分片并逐字吐字。
    case streaming
    /// 输入已结束，正在等待最终全量解析完成。
    case finishing
    /// 最终解析已完成，正在等待显示追赶最终内容。
    case displayingFinalContent
    /// 显示完成且已提升为可交互的终态块级视图。
    case finished
    /// 流式会话已被主动取消。
    case cancelled
  }

  /// 当前会话状态。
  @Published public private(set) var state: State = .idle

  /// 当前累计接收的完整 Markdown 纯文本；append 不会触发 SwiftUI 全量 diff。
  public private(set) var currentText: String = ""

  /// 终态解析产出的块级渲染单元数组（仅在 `isPromoted == true` 时生效）。
  public private(set) var blocks: [InkRenderableBlock] = []

  /// 是否已完成从流式富文本到静态块级组件的提升（Block Promotion）。
  @Published public private(set) var isPromoted: Bool = false

  /// 当前会话使用的唯一 Markdown 渲染配置快照。
  public private(set) var configuration: InkConfiguration

  /// 当前会话创建时固定的最大 Markdown 源文本长度。
  ///
  /// 传入 `0` 或负数会回退到 ``InkStreamRenderer/maximumSourceLength``；会话与
  /// 底层 renderer 共享同一个不可变上限快照，不会分别截断同一输入。
  public let maximumSourceLength: Int

  /// 底层流式渲染器；仅供 adapter 内部与契约测试访问。
  private(set) var renderer: InkStreamRenderer

  /// 会话与 renderer 共同持有的 canonical source 上限快照。
  private let sourceLimit: InkStreamSourceLimit

  /// 流式 PREFIX 思考块快照；供 Coordinator 挂载 `InkThoughtBlockView`。
  internal private(set) var streamingThought: InkThoughtBlock?

  /// 本 session 的 Block Presentation Continuity context；跨 streaming/promotion 持有。
  internal let presentationContinuity: InkBlockPresentationContinuity

  /// 当前流式文档的呈现周期；reset/cancel 开启新周期，但 source append 不改变。
  internal private(set) var presentationCycleID: InkBlockPresentationCycleID

  /// streaming Thought 与 promoted Thought 的一一对应 evidence。
  internal private(set) var thoughtPromotionEvidence: InkBlockPresentationPromotionLineageEvidence

  /// adapter-only remainder candidate 的稳定 identity；不进入 core renderer。
  internal private(set) var streamRemainderStableIdentity: AnyHashable

  /// 流式显示刷新槽位；Coordinator 按集合处理，禁止二选一 switch。
  internal struct StreamingDirtySlots: OptionSet, Sendable {
    let rawValue: UInt8
    /// 流式 remainder 富文本槽。
    static let streamText = StreamingDirtySlots(rawValue: 1 << 0)
    /// PREFIX 思考块槽。
    static let streamingThought = StreamingDirtySlots(rawValue: 1 << 1)
    /// 会话级 presentation 作废（cancel / reset）；Coordinator 需同步拆除流式 attachment。
    static let presentationInvalidated = StreamingDirtySlots(rawValue: 1 << 2)
    /// 已挂载终态的 render environment 更新；Coordinator 需重算 presentation 与 measurement。
    static let presentationEnvironment = StreamingDirtySlots(rawValue: 1 << 3)
  }

  /// remainder 每次可见内容刷新递增；只参与 adapter candidate 的 semantic revision。
  internal private(set) var streamTextPresentationRevision: UInt64 = 0

  /// 同一次 flush 周期内合并的 pending 槽位。
  private var pendingDisplayUpdateSlots: StreamingDirtySlots = []

  /// append 批处理期间抑制 renderer 触发的过早 flush。
  private var isBatchingDisplayUpdate = false

  /// 供契约测试断言 remainder 派生缓冲（SSOT 仍为 `currentText`）。
  internal var streamRemainder: String { remainderText }

  /// 供 workload 契约证明流式 scanner 未重复检查历史 source。
  internal var thoughtScannerInputUnitInspectionCount: Int {
    thoughtStreamingScanner.debugInputUnitInspectionCount
  }

  /// 是否暂停逐字显示；转发至底层 renderer，供 Chat 滚动策略在用户拖拽时暂停吐字。
  public var isDisplayPaused: Bool {
    get { renderer.isDisplayPaused }
    set { renderer.isDisplayPaused = newValue }
  }

  /// 递增以作废已排队的 deferred `@Published` 写入（`reset` / `cancel` 时调用）。
  private var publishGeneration: UInt64 = 0

  /// 0-delay default-mode timer 载体，将 `@Published` 写入推迟到当前 view update 之外。
  private let publishHopper = PublishHopper()

  /// 进入 `InkStreamRenderer` 的 remainder 派生文本（SSOT 为 `currentText`）。
  private var remainderText: String = ""

  /// Core-owned PREFIX Thought 增量语法状态；session 只消费 delta，不复制标签语法。
  private var thoughtStreamingScanner = InkThoughtScanner.StreamingScanner()

  /// 已确认、去除首尾空白的流式 Thought 正文；scanner 仅追加稳定 body delta。
  private var streamingThoughtText: String = ""

  /// 上一帧是否存在 PREFIX 思考块，用于检测 none→thought 转换。
  private var hadStreamingThought: Bool = false

  /// 宿主用于跟随滚动或高度变化的显示刷新回调。
  ///
  /// 该回调在流式内容尺寸变化时由 session 触发，供 UIKit 宿主（如 ExampleApp）
  /// 或 SwiftUI Coordinator 同步滚动位置；**不是** `@Published`，避免每帧显示更新
  /// 再次触发 Publishing changes。
  public var onDisplayUpdate: (() -> Void)?

  /// 成组呈现绑定：private observer + 可选 textView；旧 grant 释放不能清掉新 record。
  private var presentationBinding: PresentationBindingRecord?

  /// 创建一个流式 Markdown 渲染会话。
  /// - Parameter configuration: 此会话从流式到终态均使用的 Markdown 渲染配置快照。
  /// - Parameter maximumSourceLength: 此会话可接受的最大 Markdown 字符数。必须为正数；
  ///   `0` 或负数视为无效并回退到默认 `50_000`。
  public init(
    configuration: InkConfiguration = .standard,
    maximumSourceLength: Int = InkStreamRenderer.maximumSourceLength
  ) {
    let presentationCycleID = InkBlockPresentationCycleID()
    let sourceLimit = InkStreamSourceLimit(maximum: maximumSourceLength)
    self.presentationCycleID = presentationCycleID
    self.presentationContinuity = InkBlockPresentationContinuity(cycleID: presentationCycleID)
    self.thoughtPromotionEvidence = InkBlockPresentationPromotionLineageEvidence()
    self.streamRemainderStableIdentity = UUID().uuidString
    self.sourceLimit = sourceLimit
    self.maximumSourceLength = sourceLimit.maximum
    self.configuration = configuration
    self.renderer = InkStreamRenderer(configuration: configuration, sourceLimit: sourceLimit)
    setupCallbacks()
  }

  /// 使用最新 trait 快照重渲染当前会话。
  ///
  /// 宿主在 Dark Mode、Dynamic Type 或其它影响 ``InkConfiguration/renderEnvironment`` 的
  /// trait 变化时，**必须**对每条消息各自持有的 ``InkMarkdownRenderSession`` 调用本方法。
  /// 库不会在 SwiftUI 环境变化时自动遍历 Chat 历史中的 per-message session；若遗漏调用，
  /// 已渲染消息会保留旧 trait 下的动态色与字号解析结果。
  ///
  /// 该方法仅更新 ``InkConfiguration/renderEnvironment``，不会引入第二套 SwiftUI 样式模型；
  /// 若会话正在流式显示，会以 remainder 派生缓冲重新解析，避免把思考标签回灌 textView。
  /// 已完成会话只重渲染 blocks，不重置流式 renderer；renderer 仍同步保存最新配置，
  /// 供后续 `reset()` / `append()` 使用。流式阶段不触发 ``objectWillChange``，终态
  /// Block Promotion 后会通知 SwiftUI 重建。
  ///
  /// - Parameter environment: 从当前 ``UITraitCollection`` 或 SwiftUI `colorScheme` 等
  ///   捕获的 trait 快照；须与宿主界面实际外观一致。
  public func updateRenderEnvironment(_ environment: InkRenderEnvironment) {
    guard configuration.renderEnvironment != environment else { return }

    configuration.renderEnvironment = environment

    if isPromoted || state == .finished {
      // 终态不再调用 renderer.updateConfiguration(_:source:)：该公开 API 会 reset
      // 并重新启动 display link。只保留未来 reset/append 所需的配置 snapshot，
      // 同时重建已经提升的 blocks。
      renderer.updateConfigurationSnapshot(configuration)
      blocks = InkBlockRenderer.render(
        currentText,
        configuration: configuration
      )
      notifyDisplayUpdate(slots: .presentationEnvironment)
      flushDisplayUpdateIfNeeded()
      enqueuePublishedMutation { [weak self] in
        self?.objectWillChange.send()
      }
      return
    }

    guard state == .streaming || state == .finishing || state == .displayingFinalContent else {
      // idle/cancelled 没有活跃呈现，避免无意义 reset；后续流使用新 snapshot。
      renderer.updateConfigurationSnapshot(configuration)
      return
    }

    if var thought = streamingThought {
      thought.config = configuration.appearance.thought
      thought.renderConfiguration = configuration
      streamingThought = thought
    }
    renderer.updateConfiguration(configuration, source: remainderText)
    if state == .finishing || state == .displayingFinalContent {
      renderer.finish()
    }

    // 流式阶段 UIKit renderer 已 in-place 更新；adapter 只刷新当前 attachment。
    if state == .streaming || state == .finishing || state == .displayingFinalContent {
      notifyDisplayUpdate(slots: [.streamingThought, .streamText])
      flushDisplayUpdateIfNeeded()
    }
  }

  // MARK: - Public API

  /// 追加接收到的 Markdown 文本分片。
  ///
  /// 若当前处于 `idle` 状态，将自动转换至 `streaming` 状态；终态或取消后的调用为 no-op。
  /// PREFIX 思考标签进入 `streamingThought`，仅 remainder delta 喂入 renderer。
  /// - Parameter text: 新到达的 Markdown 文本片段。
  public func append(_ text: String) {
    guard state == .idle || state == .streaming else { return }
    let acceptedText = sourceLimit.acceptedChunk(text, after: currentText)
    guard !acceptedText.isEmpty else { return }
    if state == .idle {
      state = .streaming
    }
    currentText += acceptedText
    applyStreamingScannerUpdate(thoughtStreamingScanner.append(acceptedText))
  }

  /// 标记流式输入结束。
  ///
  /// 状态会依次经过 `finishing`、`displayingFinalContent`，最后在完成 Block Promotion 后进入
  /// `finished`。`idle` 会被视为合法的零内容流并完成空结果提升；其它终态调用为 no-op。
  public func finish() {
    guard state == .idle || state == .streaming else { return }
    isDisplayPaused = false
    applyStreamingScannerUpdate(thoughtStreamingScanner.finish())
    state = .finishing
    renderer.finish()
  }

  /// 取消当前流式会话。
  ///
  /// 取消会使底层 renderer 丢弃进行中的后台解析结果。若会话已终态、已取消或仍为空闲，
  /// 此调用为 no-op。
  public func cancel() {
    guard state == .streaming || state == .finishing || state == .displayingFinalContent else { return }
    invalidatePendingPublishedMutations()
    beginNewPresentationCycle()
    state = .cancelled
    renderer.reset()
    clearStreamingSplitState()
    notifyDisplayUpdate(slots: [.presentationInvalidated, .streamText, .streamingThought])
    flushDisplayUpdateIfNeeded()
  }

  /// 重置会话至初始状态。
  ///
  /// 清空唯一输入源、终态块列表及底层 renderer；随后可安全复用同一会话。
  public func reset() {
    invalidatePendingPublishedMutations()
    beginNewPresentationCycle()
    renderer.reset()
    setupCallbacks()
    currentText = ""
    blocks = []
    isPromoted = false
    state = .idle
    clearStreamingSplitState()
    notifyDisplayUpdate(slots: [.presentationInvalidated, .streamText, .streamingThought])
    flushDisplayUpdateIfNeeded()
  }

  // MARK: - Internal Helpers for Coordinator

  /// 仅活跃的流式显示阶段需要 adapter-owned remainder attachment。
  var requiresStreamingTextAttachment: Bool {
    switch state {
    case .streaming, .finishing, .displayingFinalContent:
      return true
    case .idle, .finished, .cancelled:
      return false
    }
  }

  /// 成组安装呈现绑定：可选 textView + private observer。返回可匹配释放的 grant。
  ///
  /// 替换任意既有 binding；不拥有 continuity attachment 权限。
  @discardableResult
  func installPresentationBinding(
    owner: AnyObject,
    textView: UITextView? = nil,
    observer: (() -> Void)? = nil
  ) -> InkSessionPresentationBindingGrant {
    let previous = presentationBinding
    let grant = InkSessionPresentationBindingGrant()
    let record = PresentationBindingRecord(
      grant: grant,
      owner: owner,
      textView: textView,
      observer: observer
    )
    presentationBinding = record
    applyTextViewBinding(from: previous, to: record)
    return grant
  }

  /// 在 grant 仍匹配当前 record 时更新 textView / observer。
  func updatePresentationBinding(
    _ grant: InkSessionPresentationBindingGrant,
    textView: UITextView?,
    observer: (() -> Void)?
  ) {
    guard let record = presentationBinding, record.grant == grant else { return }
    let previousTextView = record.textView
    record.textView = textView
    record.observer = observer
    if previousTextView !== textView {
      applyTextViewBinding(from: nil, to: record, previousTextView: previousTextView)
    }
  }

  /// 仅当 grant 仍是当前 record 时释放；旧 grant 不会清掉新绑定。
  func releasePresentationBinding(_ grant: InkSessionPresentationBindingGrant) {
    guard let record = presentationBinding, record.grant == grant else { return }
    presentationBinding = nil
    if record.textView != nil {
      renderer.unbindTextView()
    }
  }

  /// 当前是否存在活跃的呈现绑定（供测试及内部诊断使用）。
  var hasPresentationBinding: Bool {
    presentationBinding != nil
  }

  /// 仅当 grant 仍是当前活跃绑定时解绑当前绑定的 `UITextView`，保留 observer 与 grant。
  func unbindTextView(for grant: InkSessionPresentationBindingGrant) {
    guard let record = presentationBinding, record.grant == grant else { return }
    if record.textView != nil {
      record.textView = nil
      renderer.unbindTextView()
    }
  }

  /// Continuity 中的交互状态变化已由 Coordinator 原位应用；这里只通知宿主重新测量，
  /// 不再次唤醒 adapter observer，避免 reconcile 回路。
  func notifyHostPresentationSizeChanged() {
    onDisplayUpdate?()
  }

  private func applyTextViewBinding(
    from previous: PresentationBindingRecord?,
    to record: PresentationBindingRecord,
    previousTextView: UITextView? = nil
  ) {
    let oldView = previousTextView ?? previous?.textView
    if let textView = record.textView {
      if oldView !== textView {
        renderer.bindTextView(textView)
      }
    } else if oldView != nil {
      renderer.unbindTextView()
    }
  }

  // MARK: - Private Helpers

  private func applyStreamingScannerUpdate(
    _ update: InkThoughtScanner.StreamingScanner.Update
  ) {
    let previousHadThought = hadStreamingThought
    let previousThoughtWasComplete = streamingThought?.isComplete
    var dirtySlots: StreamingDirtySlots = []

    switch update.phase {
    case .prefixUndecided, .passthrough:
      streamingThought = nil
      hadStreamingThought = false
    case .thought(let isComplete):
      if !update.thoughtBodyDelta.isEmpty {
        streamingThoughtText += update.thoughtBodyDelta
      }
      hadStreamingThought = true
      if !previousHadThought
          || !update.thoughtBodyDelta.isEmpty
          || previousThoughtWasComplete != isComplete {
        streamingThought = InkThoughtBlock(
          thought: streamingThoughtText,
          isComplete: isComplete,
          config: configuration.appearance.thought,
          renderConfiguration: configuration,
          isCollapsed: nil
        )
        dirtySlots.insert(.streamingThought)
      }
    }

    remainderText += update.remainderDelta

    isBatchingDisplayUpdate = true
    defer {
      isBatchingDisplayUpdate = false
      if !dirtySlots.isEmpty {
        notifyDisplayUpdate(slots: dirtySlots)
      }
      flushDisplayUpdateIfNeeded()
    }

    if !previousHadThought && hadStreamingThought {
      // PREFIX 在多个 chunks 后才确认时，撤回任何 speculative text attachment。
      renderer.reset(to: remainderText)
      dirtySlots.insert(.streamText)
    } else if !update.remainderDelta.isEmpty {
      renderer.appendCanonical(update.remainderDelta)
      dirtySlots.insert(.streamText)
    }
  }

  private func clearStreamingSplitState() {
    streamingThought = nil
    remainderText = ""
    streamingThoughtText = ""
    thoughtStreamingScanner.reset()
    hadStreamingThought = false
    pendingDisplayUpdateSlots = []
  }

  private func beginNewPresentationCycle() {
    presentationContinuity.invalidateForCycleBoundary()
    presentationCycleID = InkBlockPresentationCycleID()
    thoughtPromotionEvidence = InkBlockPresentationPromotionLineageEvidence()
    streamRemainderStableIdentity = UUID().uuidString
  }

  /// 合并 dirty 槽位；同周期内多次调用仅产生一次 `onDisplayUpdate` 回调。
  private func notifyDisplayUpdate(slots: StreamingDirtySlots) {
    pendingDisplayUpdateSlots.formUnion(slots)
  }

  private func flushDisplayUpdateIfNeeded() {
    guard !isBatchingDisplayUpdate else { return }
    guard !pendingDisplayUpdateSlots.isEmpty else { return }
    let slots = pendingDisplayUpdateSlots
    pendingDisplayUpdateSlots = []
    if slots.contains(.streamText) {
      streamTextPresentationRevision &+= 1
    }
    if let record = presentationBinding {
      if record.owner == nil {
        presentationBinding = nil
      } else {
        record.observer?()
      }
    }
    onDisplayUpdate?()
  }

  /// 作废并清空 hopper 上排队的 deferred `@Published` 写入。
  private func invalidatePendingPublishedMutations() {
    publishGeneration += 1
    publishHopper.cancel()
  }

  /// 将 `@Published` 写入推迟到 `.default` runloop mode 的下一轮 timer 队列。
  ///
  /// 不用 `DispatchQueue.main.async`：main queue 挂在 common modes，SwiftUI 在 view update
  /// 期间会抽干 main queue。不用 `RunLoop.perform(inModes:)`：当前已在 default mode 时会在
  /// 本轮 `__CFRunLoopDoBlocks` 同步执行。0-delay timer 进 default-mode 队列，等当前
  /// source / view-update 栈返回后再 fire。
  private func enqueuePublishedMutation(_ mutate: @escaping () -> Void) {
    publishGeneration += 1
    let generation = publishGeneration
    publishHopper.schedule { [weak self] in
      guard let self, self.publishGeneration == generation else { return }
      mutate()
    }
  }

  private func setupCallbacks() {
    renderer.onDisplayUpdate = { [weak self] in
      self?.notifyDisplayUpdate(slots: .streamText)
      self?.flushDisplayUpdateIfNeeded()
    }

    renderer.onFinishParse = { [weak self] in
      guard let self, self.state == .finishing else { return }
      self.state = .displayingFinalContent
    }

    renderer.onFinishDisplay = { [weak self] in
      guard let self,
            self.state == .finishing || self.state == .displayingFinalContent,
            !self.isPromoted
      else { return }

      self.blocks = InkBlockRenderer.render(
        self.currentText,
        configuration: self.configuration
      )

      self.enqueuePublishedMutation { [weak self] in
        guard let self,
              self.state == .finishing || self.state == .displayingFinalContent,
              !self.isPromoted
        else { return }

        self.state = .finished
        self.isPromoted = true
      }
    }
  }
}

/// Session 成组呈现绑定的可匹配释放令牌；不表达 continuity attachment 权限。
struct InkSessionPresentationBindingGrant: Equatable {
  fileprivate let id: UUID

  fileprivate init(id: UUID = UUID()) {
    self.id = id
  }
}

@MainActor
private final class PresentationBindingRecord {
  let grant: InkSessionPresentationBindingGrant
  weak var owner: AnyObject?
  weak var textView: UITextView?
  var observer: (() -> Void)?

  init(
    grant: InkSessionPresentationBindingGrant,
    owner: AnyObject,
    textView: UITextView?,
    observer: (() -> Void)?
  ) {
    self.grant = grant
    self.owner = owner
    self.textView = textView
    self.observer = observer
  }
}

/// 0-delay timer 回调载体；`NSObject.perform(_:with:afterDelay:inModes:)` 会 retain target 直至触发。
private final class PublishHopper: NSObject {
  private var mutate: (() -> Void)?

  func schedule(_ mutate: @escaping () -> Void) {
    self.mutate = mutate
    NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(flush), object: nil)
    perform(#selector(flush), with: nil, afterDelay: 0, inModes: [RunLoop.Mode.default])
  }

  func cancel() {
    NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(flush), object: nil)
    mutate = nil
  }

  @objc fileprivate func flush() {
    let block = mutate
    mutate = nil
    block?()
  }
}
