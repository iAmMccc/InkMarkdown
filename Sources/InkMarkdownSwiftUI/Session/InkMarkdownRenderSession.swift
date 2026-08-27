//
//  InkMarkdownRenderSession.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import Combine
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

  /// 底层流式渲染器；仅供 adapter 内部与契约测试访问。
  private(set) var renderer: InkStreamRenderer

  /// 流式 PREFIX 思考块快照；供 Coordinator 挂载 `InkThoughtBlockView`。
  internal private(set) var streamingThought: InkThoughtBlock?

  /// 文档 epoch，供 promotion 终态块 identity 与 diff 使用。
  internal var documentEpoch: UInt64 {
    InkDocumentEpoch.hash(currentText)
  }

  /// 流式 slot 固定 epoch；单条流内不变，reset/cancel 后递增，禁止编入 `hash(currentText)`。
  internal private(set) var streamingSlotEpoch: UInt64 = 0

  /// 下一条流式会话将使用的 slot epoch（`reset` / `cancel` 后递增）。
  private var nextStreamingSlotEpoch: UInt64 = 0

  /// 最近一次 `onDisplayUpdate` 应刷新的流式槽位（供 Coordinator 按变化选槽）。
  internal enum StreamingDisplayUpdateTarget: Sendable {
    case streamText
    case streamingThought
  }

  internal private(set) var lastDisplayUpdateTarget: StreamingDisplayUpdateTarget = .streamText

  /// 供契约测试断言 remainder 派生缓冲（SSOT 仍为 `currentText`）。
  internal var streamRemainder: String { remainderText }

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

  /// 上一帧是否存在 PREFIX 思考块，用于检测 none→thought 转换。
  private var hadStreamingThought: Bool = false

  /// 宿主用于跟随滚动或高度变化的显示刷新回调。
  ///
  /// 该回调在流式内容尺寸变化时由 session 触发，供 UIKit 宿主（如 ExampleApp）
  /// 或 SwiftUI Coordinator 同步滚动位置；**不是** `@Published`，避免每帧显示更新
  /// 再次触发 Publishing changes。
  public var onDisplayUpdate: (() -> Void)?

  /// 创建一个流式 Markdown 渲染会话。
  /// - Parameter configuration: 此会话从流式到终态均使用的 Markdown 渲染配置快照。
  public init(configuration: InkConfiguration = .standard) {
    self.configuration = configuration
    self.renderer = InkStreamRenderer(configuration: configuration)
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
  /// 流式阶段不触发 ``objectWillChange``，终态 Block Promotion 后会通知 SwiftUI 重建。
  ///
  /// - Parameter environment: 从当前 ``UITraitCollection`` 或 SwiftUI `colorScheme` 等
  ///   捕获的 trait 快照；须与宿主界面实际外观一致。
  public func updateRenderEnvironment(_ environment: InkRenderEnvironment) {
    guard configuration.renderEnvironment != environment else { return }

    configuration.renderEnvironment = environment
    if var thought = streamingThought {
      thought.config = configuration.appearance.thought
      thought.renderConfiguration = configuration
      streamingThought = thought
    }
    renderer.updateConfiguration(configuration, source: remainderText)
    if state == .finishing || state == .displayingFinalContent {
      renderer.finish()
    }

    // 流式阶段 UIKit renderer 已 in-place 更新；终态需重渲染 blocks 以应用新 trait。
    if isPromoted {
      blocks = Self.renderBlocksPreservingThoughtCollapse(
        from: currentText,
        configuration: configuration,
        streamingThought: streamingThought,
        existingBlocks: blocks
      )
      enqueuePublishedMutation { [weak self] in
        self?.objectWillChange.send()
      }
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
    if state == .idle {
      state = .streaming
      streamingSlotEpoch = nextStreamingSlotEpoch
    }
    let remainingCapacity = InkStreamRenderer.maximumSourceLength - currentText.count
    guard remainingCapacity > 0 else { return }

    let acceptedText = String(text.prefix(remainingCapacity))
    let previousRemainder = remainderText
    let previousHadThought = hadStreamingThought
    let previousThoughtBody = streamingThought?.thought
    currentText += acceptedText

    let split = InkThoughtScanner.splitStreamingSource(currentText)
    updateStreamingThought(from: split)
    let newRemainder = split.remainder

    if !previousHadThought && hadStreamingThought {
      renderer.reset(to: newRemainder)
    } else {
      let remainderDelta = String(newRemainder.dropFirst(previousRemainder.count))
      if !remainderDelta.isEmpty {
        renderer.append(remainderDelta)
      } else if hadStreamingThought,
                streamingThought?.thought != previousThoughtBody {
        // 思考正文增长：由 Coordinator 单槽 updateReservedHeightSlot 处理，不清整表 cache。
        notifyDisplayUpdate(target: .streamingThought)
      }
    }

    remainderText = newRemainder
  }

  /// 标记流式输入结束。
  ///
  /// 状态会依次经过 `finishing`、`displayingFinalContent`，最后在完成 Block Promotion 后进入
  /// `finished`。若当前不处于 `streaming` 状态，此调用为 no-op。
  public func finish() {
    guard state == .streaming else { return }
    isDisplayPaused = false
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
    state = .cancelled
    renderer.reset()
    clearStreamingSplitState()
  }

  /// 重置会话至初始状态。
  ///
  /// 清空唯一输入源、终态块列表及底层 renderer；随后可安全复用同一会话。
  public func reset() {
    invalidatePendingPublishedMutations()
    renderer.reset()
    setupCallbacks()
    currentText = ""
    blocks = []
    isPromoted = false
    state = .idle
    clearStreamingSplitState()
  }

  // MARK: - Internal Helpers for Coordinator

  /// 绑定用于展示流式富文本的 `UITextView`。
  /// - Parameter textView: 承载流式富文本渲染的文本视图。
  func bindTextView(_ textView: UITextView) {
    renderer.bindTextView(textView)
  }

  /// 解绑当前绑定的 `UITextView` 并快进已解析内容。
  func unbindTextView() {
    renderer.unbindTextView()
  }

  /// 更新流式 PREFIX 思考块的折叠态（写入 `streamingThought` SSOT）。
  func setStreamingThoughtCollapsed(_ isCollapsed: Bool) {
    guard var thought = streamingThought else { return }
    thought.isCollapsed = isCollapsed
    streamingThought = thought
  }

  /// 更新终态 blocks 中指定索引思考块的折叠态。
  func setPromotedThoughtCollapsed(at index: Int, isCollapsed: Bool) {
    guard index < blocks.count, var thought = blocks[index] as? InkThoughtBlock else { return }
    thought.isCollapsed = isCollapsed
    blocks[index] = thought
  }

  /// 将流式思考块折叠态合并进终态 blocks（promotion 前最后一道同步）。
  internal func syncStreamingThoughtCollapseIntoBlocks(streamViewCollapsed: Bool? = nil) {
    let collapsed = streamViewCollapsed ?? streamingThought?.isCollapsed
    guard let collapsed else { return }
    for index in blocks.indices {
      guard var thought = blocks[index] as? InkThoughtBlock else { continue }
      thought.isCollapsed = collapsed
      blocks[index] = thought
      break
    }
  }

  // MARK: - Private Helpers

  private static func renderBlocksPreservingThoughtCollapse(
    from text: String,
    configuration: InkConfiguration,
    streamingThought: InkThoughtBlock?,
    existingBlocks: [InkRenderableBlock]? = nil
  ) -> [InkRenderableBlock] {
    var blocks = InkBlockRenderer.render(text, configuration: configuration)
    let collapsed = (existingBlocks?.first(where: { $0 is InkThoughtBlock }) as? InkThoughtBlock)?.isCollapsed
      ?? streamingThought?.isCollapsed
    guard let collapsed else { return blocks }
    for index in blocks.indices {
      guard var thought = blocks[index] as? InkThoughtBlock else { continue }
      thought.isCollapsed = collapsed
      blocks[index] = thought
      break
    }
    return blocks
  }

  private func updateStreamingThought(from split: InkThoughtScanner.StreamingSplit) {
    let previousCollapsed = streamingThought?.isCollapsed
    if let thoughtResult = split.thought {
      var block = InkThoughtBlock(
        thought: thoughtResult.thoughtBody,
        isComplete: thoughtResult.isComplete,
        config: configuration.appearance.thought,
        renderConfiguration: configuration,
        isCollapsed: previousCollapsed
      )
      block.blockIdentity = InkBlockIdentity(
        documentEpoch: streamingSlotEpoch,
        blockIndex: -2,
        kind: ObjectIdentifier(InkThoughtBlock.self).hashValue
      )
      streamingThought = block
      hadStreamingThought = true
    } else {
      streamingThought = nil
      hadStreamingThought = false
    }
  }

  private func clearStreamingSplitState() {
    streamingThought = nil
    remainderText = ""
    hadStreamingThought = false
    lastDisplayUpdateTarget = .streamText
    nextStreamingSlotEpoch += 1
    streamingSlotEpoch = nextStreamingSlotEpoch
  }

  private func notifyDisplayUpdate(target: StreamingDisplayUpdateTarget) {
    lastDisplayUpdateTarget = target
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
      self?.notifyDisplayUpdate(target: .streamText)
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

      self.blocks = Self.renderBlocksPreservingThoughtCollapse(
        from: self.currentText,
        configuration: self.configuration,
        streamingThought: self.streamingThought
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
