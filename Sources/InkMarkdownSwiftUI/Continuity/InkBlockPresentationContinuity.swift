//
//  InkBlockPresentationContinuity.swift
//  InkMarkdownSwiftUI
//

import os.log
import UIKit
@_spi(InkMarkdown) import InkMarkdown

#if DEBUG
private let inkBlockPresentationContinuityLog = OSLog(
  subsystem: "com.inkmarkdown.InkMarkdownSwiftUI",
  category: "BlockPresentationContinuity"
)
#endif

/// 当前 SwiftUI adapter 呈现周期的 opaque identity。
@MainActor
struct InkBlockPresentationCycleID: Hashable {
  fileprivate let rawValue: UUID

  init() {
    rawValue = UUID()
  }
}

/// adapter 根据渲染配置与 UIKit 当前 trait 解析出的稳定环境身份。
///
/// `InkConfiguration.renderEnvironment` 只描述 renderer 需要的 style/category；UIKit
/// trait 还会影响排版方向、尺寸类别、显示比例和可访问性对比度。把两部分收成明确
/// 的值类型，避免把 `UITraitCollection` 对象身份或不受支持的 getter override 当作缓存依据。
@MainActor
struct InkBlockPresentationEnvironmentSignature: Hashable {
  let renderEnvironment: InkRenderEnvironment
  let userInterfaceStyleRawValue: Int
  let preferredContentSizeCategoryRawValue: String
  let layoutDirectionRawValue: Int
  let horizontalSizeClassRawValue: Int
  let verticalSizeClassRawValue: Int
  let displayScaleBits: UInt64
  let accessibilityContrastRawValue: Int

  init(
    configuration: InkConfiguration,
    traitCollection: UITraitCollection
  ) {
    renderEnvironment = configuration.renderEnvironment

    let style = configuration.renderEnvironment.userInterfaceStyle == .unspecified
      ? traitCollection.userInterfaceStyle
      : configuration.renderEnvironment.userInterfaceStyle
    userInterfaceStyleRawValue = style.rawValue

    let category = configuration.renderEnvironment.contentSizeCategory == .unspecified
      ? traitCollection.preferredContentSizeCategory
      : configuration.renderEnvironment.contentSizeCategory
    preferredContentSizeCategoryRawValue = category.rawValue

    layoutDirectionRawValue = traitCollection.layoutDirection.rawValue
    horizontalSizeClassRawValue = traitCollection.horizontalSizeClass.rawValue
    verticalSizeClassRawValue = traitCollection.verticalSizeClass.rawValue
    displayScaleBits = UInt64(traitCollection.displayScale.bitPattern)
    accessibilityContrastRawValue = traitCollection.accessibilityContrast.rawValue
  }
}

/// 一个待 reconciliation 的语义 block 及其 adapter 层 structural 证据。
@MainActor
struct InkBlockPresentationCandidate {
  let block: any InkRenderableBlock
  let structuralSlot: Int
  /// 调用方能证明同一逻辑块时提供；不提供时不得由内容推测。
  let stableIdentity: AnyHashable?
  /// 为 streaming promotion 预留的一一对应证据。当前 adapter 不自动生成或推测它。
  let promotionLineageEvidence: InkBlockPresentationPromotionLineageEvidence?

  init(
    block: any InkRenderableBlock,
    structuralSlot: Int,
    stableIdentity: AnyHashable? = nil,
    promotionLineageEvidence: InkBlockPresentationPromotionLineageEvidence? = nil
  ) {
    self.block = block
    self.structuralSlot = structuralSlot
    self.stableIdentity = stableIdentity
    self.promotionLineageEvidence = promotionLineageEvidence
  }

  static func staticBlocks(_ blocks: [InkRenderableBlock]) -> [InkBlockPresentationCandidate] {
    blocks.enumerated().map { index, block in
      InkBlockPresentationCandidate(block: block, structuralSlot: index)
    }
  }
}

/// adapter-only promotion evidence。
///
/// 同一实例应由未来的 streaming adapter 同时附着到临时与终态 candidate；
/// continuity module 不从 block 内容、位置或 source hash 推导该证据。
struct InkBlockPresentationPromotionLineageEvidence: Hashable {
  private let rawValue: AnyHashable

  init(_ rawValue: AnyHashable) {
    self.rawValue = rawValue
  }

  init() {
    self.init(UUID().uuidString)
  }
}

/// 单次 reconciliation 使用的不可变 snapshot。
@MainActor
struct InkBlockPresentationSnapshot {
  let cycleID: InkBlockPresentationCycleID
  let candidates: [InkBlockPresentationCandidate]
  let configuration: InkConfiguration
  let constrainedWidth: CGFloat
  let environmentSignature: InkBlockPresentationEnvironmentSignature

  init(
    cycleID: InkBlockPresentationCycleID,
    candidates: [InkBlockPresentationCandidate],
    configuration: InkConfiguration,
    constrainedWidth: CGFloat = 0
  ) {
    self.cycleID = cycleID
    self.candidates = candidates
    self.configuration = configuration
    self.constrainedWidth = constrainedWidth
    environmentSignature = InkBlockPresentationEnvironmentSignature(
      configuration: configuration,
      traitCollection: UITraitCollection.current
    )
  }

  init(
    cycleID: InkBlockPresentationCycleID,
    candidates: [InkBlockPresentationCandidate],
    configuration: InkConfiguration,
    constrainedWidth: CGFloat,
    environmentSignature: InkBlockPresentationEnvironmentSignature
  ) {
    self.cycleID = cycleID
    self.candidates = candidates
    self.configuration = configuration
    self.constrainedWidth = constrainedWidth
    self.environmentSignature = environmentSignature
  }
}

/// adapter 内建 stateful block 使用的最小 presentation state。
@MainActor
enum InkBlockPresentationState: Equatable {
  case thought(isCollapsed: Bool)
}

/// 当前呈现周期内一条逻辑块生命线的 identity。
@MainActor
struct InkBlockPresentationLineageID: Hashable {
  fileprivate let rawValue: UInt64

  fileprivate init(rawValue: UInt64) {
    self.rawValue = rawValue
  }
}

/// continuity module 交给 container 使用的单槽测量 identity。
@MainActor
struct InkBlockPresentationMeasurementKey: Hashable {
  let lineageID: InkBlockPresentationLineageID
  let slotRevision: UInt64
  let constrainedWidth: CGFloat
  let environmentSignature: UInt64

  func replacingWidth(_ width: CGFloat) -> InkBlockPresentationMeasurementKey {
    InkBlockPresentationMeasurementKey(
      lineageID: lineageID,
      slotRevision: slotRevision,
      constrainedWidth: width,
      environmentSignature: environmentSignature
    )
  }
}

/// 一次 reconciliation 的完整 UIKit apply 结果。
@MainActor
final class InkBlockPresentationAttachmentToken {
  private(set) var isValid = true

  func invalidate() {
    isValid = false
  }
}

@MainActor
final class InkBlockPresentationApplyPlan {

  @MainActor
  final class Entry {
    let lineageID: InkBlockPresentationLineageID
    let presentationState: InkBlockPresentationState?
    let measurementKey: InkBlockPresentationMeasurementKey

    private var resolvedView: UIView?
    private var makeViewHandler: (@MainActor () -> UIView)?

    /// 仅在 plan 已 begin 并解析 attachment 后可访问。
    var view: UIView {
      guard let resolvedView else {
        preconditionFailure("presentation entry view must be resolved during apply")
      }
      return resolvedView
    }

    init(
      lineageID: InkBlockPresentationLineageID,
      view: UIView,
      presentationState: InkBlockPresentationState?,
      measurementKey: InkBlockPresentationMeasurementKey
    ) {
      self.lineageID = lineageID
      self.presentationState = presentationState
      self.measurementKey = measurementKey
      resolvedView = view
    }

    init(
      lineageID: InkBlockPresentationLineageID,
      makeView: @escaping @MainActor () -> UIView,
      presentationState: InkBlockPresentationState?,
      measurementKey: InkBlockPresentationMeasurementKey
    ) {
      self.lineageID = lineageID
      self.presentationState = presentationState
      self.measurementKey = measurementKey
      makeViewHandler = makeView
    }

    func resolveView() -> UIView {
      if let resolvedView { return resolvedView }
      guard let makeViewHandler else {
        preconditionFailure("presentation entry is missing its view factory")
      }
      let view = makeViewHandler()
      resolvedView = view
      self.makeViewHandler = nil
      return view
    }

    func replaceResolvedView(with view: UIView) {
      resolvedView = view
      makeViewHandler = nil
    }
  }

  struct Replacement {
    let oldView: UIView
    let entry: Entry
  }

  struct InPlaceUpdate {
    let entry: Entry
    let oldView: UIView
    let makeFallbackView: @MainActor () -> UIView
    let apply: @MainActor () -> Bool
  }

  enum Operation {
    case update(InPlaceUpdate)
    case replace(Replacement)
    case unmount(UIView)
    case mount(Entry)
    case order([Entry])
  }

  let expectedCurrentViews: [UIView]
  let configuration: InkConfiguration
  let orderedEntries: [Entry]
  let operations: [Operation]
  let invalidatesAllMeasurementSlots: Bool
  let invalidatedMeasurementLineageIDs: Set<InkBlockPresentationLineageID>
  let attachmentGeneration: UInt64
  let attachmentToken: InkBlockPresentationAttachmentToken
  let invalidatesIntrinsicContentSize: Bool

  private enum Lifecycle {
    case staged
    case begun
    case completed
    case aborted
  }

  private var lifecycle: Lifecycle = .staged
  private var canCommitHandler: (() -> Bool)?
  private var commitHandler: (() -> Void)?

  var isCommitted: Bool {
    lifecycle == .completed
  }

  var isAborted: Bool {
    lifecycle == .aborted
  }

  /// 在首次 UIKit mutation 前验证 plan，并标记 plan 已被接受。
  @discardableResult
  func begin() -> Bool {
    guard case .staged = lifecycle,
          canCommitHandler?() == true else {
      return false
    }
    lifecycle = .begun
    return true
  }

  /// container 完整执行 plan 后调用；commit closure 只能执行一次。
  @discardableResult
  func complete() -> Bool {
    guard case .begun = lifecycle else { return false }
    commitHandler?()
    commitHandler = nil
    canCommitHandler = nil
    lifecycle = .completed
    return true
  }

  /// 拒绝 plan 时丢弃 staged state，不改变 continuity module durable state。
  @discardableResult
  func abort() -> Bool {
    guard case .staged = lifecycle else { return false }
    commitHandler = nil
    canCommitHandler = nil
    lifecycle = .aborted
    return true
  }

  init(
    expectedCurrentViews: [UIView],
    configuration: InkConfiguration,
    orderedEntries: [Entry],
    operations: [Operation],
    invalidatesAllMeasurementSlots: Bool,
    invalidatedMeasurementLineageIDs: Set<InkBlockPresentationLineageID>,
    attachmentGeneration: UInt64,
    attachmentToken: InkBlockPresentationAttachmentToken,
    invalidatesIntrinsicContentSize: Bool,
    canCommit: @escaping () -> Bool,
    commit: @escaping () -> Void
  ) {
    self.expectedCurrentViews = expectedCurrentViews
    self.configuration = configuration
    self.orderedEntries = orderedEntries
    self.operations = operations
    self.invalidatesAllMeasurementSlots = invalidatesAllMeasurementSlots
    self.invalidatedMeasurementLineageIDs = invalidatedMeasurementLineageIDs
    self.attachmentGeneration = attachmentGeneration
    self.attachmentToken = attachmentToken
    self.invalidatesIntrinsicContentSize = invalidatesIntrinsicContentSize
    canCommitHandler = canCommit
    commitHandler = commit
  }
}

/// 持有单一呈现周期内 block presentation state 的 deep module。
@MainActor
final class InkBlockPresentationContinuity {

  private struct Record {
    let lineageID: InkBlockPresentationLineageID
    var structuralSlot: Int
    var typeIdentifier: ObjectIdentifier
    var stableIdentity: AnyHashable?
    var promotionLineageEvidence: InkBlockPresentationPromotionLineageEvidence?
    var semanticBlock: any InkRenderableBlock
    var lastSuppliedState: InkBlockPresentationState?
    var liveState: InkBlockPresentationState?
    var strategyID: Strategy.ID
    var view: UIView?
    var slotRevision: UInt64
    var attachmentGeneration: UInt64
  }

  /// Type-erased strategy 把 Thought state、continuation approval、view transition
  /// 和 interaction callback wiring 收在同一 seam；fallback 永远安全重建。
  @MainActor
  private struct Strategy {
    enum ID: Hashable {
      case thought
      case fallback
    }

    let id: ID
    let approvesContinuation: @MainActor (InkBlockPresentationCandidate, Record) -> Bool
    let hasEquivalentSemanticContent: @MainActor (any InkRenderableBlock, any InkRenderableBlock) -> Bool
    let suppliedState: @MainActor (any InkRenderableBlock) -> InkBlockPresentationState?
    let resolveLiveState: @MainActor (InkBlockPresentationState?, Record?) -> InkBlockPresentationState?
    let applyState: @MainActor (any InkRenderableBlock, InkBlockPresentationState?) -> any InkRenderableBlock
    let makeView: @MainActor (any InkRenderableBlock) -> UIView
    let updateExistingView: @MainActor (any InkRenderableBlock, UIView) -> Bool
    let installInteractionHandler: @MainActor (UIView, InkBlockPresentationLineageID, UInt64, InkBlockPresentationContinuity) -> Void
    let clearInteractionHandler: @MainActor (UIView) -> Void
  }

  @MainActor
  private struct StrategyRegistry {
    private let thought: Strategy
    private let fallback: Strategy

    init() {
      thought = Strategy(
        id: .thought,
        approvesContinuation: { candidate, record in
          record.strategyID == .thought
            && record.typeIdentifier == ObjectIdentifier(type(of: candidate.block))
            && candidate.block is InkThoughtBlock
            && record.structuralSlot == candidate.structuralSlot
        },
        hasEquivalentSemanticContent: { current, previous in
          guard let current = current as? InkThoughtBlock,
                let previous = previous as? InkThoughtBlock else {
            return false
          }
          return current.thought == previous.thought
            && current.isComplete == previous.isComplete
            && current.config == previous.config
            && current.renderConfiguration.isSemanticallyEqualTo(previous.renderConfiguration)
        },
        suppliedState: { block in
          guard let thought = block as? InkThoughtBlock else { return nil }
          return .thought(isCollapsed: thought.isCollapsed)
        },
        resolveLiveState: { suppliedState, previous in
          guard let previous else { return suppliedState }
          return previous.lastSuppliedState == suppliedState
            ? previous.liveState
            : suppliedState
        },
        applyState: { block, state in
          guard case .thought(let isCollapsed) = state,
                var thought = block as? InkThoughtBlock else {
            return block
          }
          thought.isCollapsed = isCollapsed
          return thought
        },
        makeView: { $0.makeView() },
        updateExistingView: { block, view in
          guard let thought = block as? InkThoughtBlock else { return false }
          return thought.updateExistingView(view)
        },
        installInteractionHandler: { view, lineageID, attachmentGeneration, continuity in
          guard let thoughtView = view as? InkThoughtBlockView else { return }
          thoughtView.onToggleCollapse = { [weak continuity, weak thoughtView] collapsed in
            guard let continuity, let thoughtView else { return }
            continuity.receiveThoughtCollapse(
              collapsed,
              for: lineageID,
              view: thoughtView,
              attachmentGeneration: attachmentGeneration
            )
          }
        },
        clearInteractionHandler: { view in
          (view as? InkThoughtBlockView)?.onToggleCollapse = nil
        }
      )

      fallback = Strategy(
        id: .fallback,
        approvesContinuation: { candidate, record in
          record.strategyID == .fallback
            && record.typeIdentifier == ObjectIdentifier(type(of: candidate.block))
            && record.structuralSlot == candidate.structuralSlot
            && candidate.block is any InkReusableBlock
            && record.semanticBlock is any InkReusableBlock
        },
        hasEquivalentSemanticContent: { current, previous in
          guard let current = current as? any InkReusableBlock else { return false }
          return current.hasEquivalentContent(to: previous)
        },
        suppliedState: { _ in nil },
        resolveLiveState: { _, _ in nil },
        applyState: { block, _ in block },
        makeView: { $0.makeView() },
        updateExistingView: { block, view in
          guard let reusable = block as? any InkReusableBlock else { return false }
          return reusable.updateExistingView(view)
        },
        installInteractionHandler: { _, _, _, _ in },
        clearInteractionHandler: { _ in }
      )
    }

    func resolve(for block: any InkRenderableBlock) -> Strategy {
      block is InkThoughtBlock ? thought : fallback
    }

    func resolve(id: Strategy.ID) -> Strategy {
      id == .thought ? thought : fallback
    }
  }

  private struct PendingInteraction {
    let lineageID: InkBlockPresentationLineageID
    let strategyID: Strategy.ID
    let attachmentGeneration: UInt64
  }

  private struct StructuralMatchKey: Hashable {
    let structuralSlot: Int
    let typeIdentifier: ObjectIdentifier
    let strategyID: Strategy.ID
  }

  private struct StructuralFamilyKey: Hashable {
    let typeIdentifier: ObjectIdentifier
    let strategyID: Strategy.ID
  }

  private struct ThoughtStructuralMarker: Hashable {
    let family: StructuralFamilyKey
    let thought: String
  }

  /// Snapshot-wide structural facts used only to reject unsafe weak matches.
  /// Exact Thought text is never positive identity evidence; it only exposes a
  /// duplicate or a block that demonstrably moved to another structural slot.
  @MainActor
  private struct StructuralEvidence {
    var thoughtSlots: [ThoughtStructuralMarker: [Int]] = [:]
    var thoughtMarkersByFamily: [StructuralFamilyKey: Set<ThoughtStructuralMarker>] = [:]
    var thoughtSlotsByFamily: [StructuralFamilyKey: [Int]] = [:]

    mutating func insert(_ candidate: InkBlockPresentationCandidate, strategyID: Strategy.ID) {
      let family = StructuralFamilyKey(
        typeIdentifier: ObjectIdentifier(type(of: candidate.block)),
        strategyID: strategyID
      )
      if strategyID == .thought, let thought = candidate.block as? InkThoughtBlock {
        let marker = ThoughtStructuralMarker(family: family, thought: thought.thought)
        thoughtSlots[marker, default: []].append(candidate.structuralSlot)
        thoughtMarkersByFamily[family, default: []].insert(marker)
        thoughtSlotsByFamily[family, default: []].append(candidate.structuralSlot)
      }
    }

    mutating func insert(_ record: Record) {
      let family = StructuralFamilyKey(
        typeIdentifier: record.typeIdentifier,
        strategyID: record.strategyID
      )
      if record.strategyID == .thought,
         let thought = record.semanticBlock as? InkThoughtBlock {
        let marker = ThoughtStructuralMarker(family: family, thought: thought.thought)
        thoughtSlots[marker, default: []].append(record.structuralSlot)
        thoughtMarkersByFamily[family, default: []].insert(marker)
        thoughtSlotsByFamily[family, default: []].append(record.structuralSlot)
      }
    }

    func ambiguousMatches(comparedWith previous: StructuralEvidence) -> Set<StructuralMatchKey> {
      let allFamilies = Set(thoughtMarkersByFamily.keys)
        .union(previous.thoughtMarkersByFamily.keys)
      var result: Set<StructuralMatchKey> = []

      func matchKey(for slot: Int, family: StructuralFamilyKey) -> StructuralMatchKey {
        StructuralMatchKey(
          structuralSlot: slot,
          typeIdentifier: family.typeIdentifier,
          strategyID: family.strategyID
        )
      }

      for family in allFamilies {
        let markers = (thoughtMarkersByFamily[family] ?? [])
          .union(previous.thoughtMarkersByFamily[family] ?? [])
        let currentFamilySlots = thoughtSlotsByFamily[family] ?? []
        let previousFamilySlots = previous.thoughtSlotsByFamily[family] ?? []

        if currentFamilySlots.count != previousFamilySlots.count {
          var provenStableSlots: Set<Int> = []
          for marker in markers {
            let currentSlots = thoughtSlots[marker] ?? []
            let previousSlots = previous.thoughtSlots[marker] ?? []
            if currentSlots.count == 1,
               previousSlots.count == 1,
               currentSlots[0] == previousSlots[0] {
              provenStableSlots.insert(currentSlots[0])
            }
          }

          // Cardinality changes only invalidate slots that cannot be anchored in place.
          // Unaffected siblings retain their lineage and live interaction state.
          for slot in Set(currentFamilySlots + previousFamilySlots)
            where !provenStableSlots.contains(slot) {
            result.insert(matchKey(for: slot, family: family))
          }
        }

        for marker in markers {
          let currentSlots = thoughtSlots[marker] ?? []
          let previousSlots = previous.thoughtSlots[marker] ?? []
          if currentSlots.count > 1 || previousSlots.count > 1 {
            for slot in Set(currentSlots + previousSlots) {
              result.insert(matchKey(for: slot, family: family))
            }
            continue
          }
          if let currentSlot = currentSlots.first,
             let previousSlot = previousSlots.first,
             currentSlot != previousSlot {
            result.insert(matchKey(for: currentSlot, family: family))
            result.insert(matchKey(for: previousSlot, family: family))
          }
        }
      }
      return result
    }
  }

  /// Old records are indexed once per reconciliation. Duplicate evidence remains
  /// visible in each bucket so validation can reject it without rescanning all records.
  @MainActor
  private struct RecordLookup {
    var stableIdentities: [AnyHashable: [InkBlockPresentationLineageID]] = [:]
    var promotionLineages:
      [InkBlockPresentationPromotionLineageEvidence: [InkBlockPresentationLineageID]] = [:]
    var structuralMatches: [StructuralMatchKey: [InkBlockPresentationLineageID]] = [:]

    mutating func insert(_ record: Record) {
      if let stableIdentity = record.stableIdentity {
        stableIdentities[stableIdentity, default: []].append(record.lineageID)
      }
      if let evidence = record.promotionLineageEvidence {
        promotionLineages[evidence, default: []].append(record.lineageID)
      }
      let structuralKey = StructuralMatchKey(
        structuralSlot: record.structuralSlot,
        typeIdentifier: record.typeIdentifier,
        strategyID: record.strategyID
      )
      structuralMatches[structuralKey, default: []].append(record.lineageID)
    }
  }

  @MainActor
  private struct EvidenceCounts {
    var stableIdentities: [AnyHashable: Int] = [:]
    var promotionLineages: [InkBlockPresentationPromotionLineageEvidence: Int] = [:]

    mutating func insert(_ candidate: InkBlockPresentationCandidate) {
      if let stableIdentity = candidate.stableIdentity {
        stableIdentities[stableIdentity, default: 0] += 1
      }
      if let evidence = candidate.promotionLineageEvidence {
        promotionLineages[evidence, default: 0] += 1
      }
    }

  }

  private enum MatchDecision {
    case matched(key: InkBlockPresentationLineageID, value: Record)
    case noMatch
    case ambiguous(String)
  }

  private struct StagedState {
    let cycleID: InkBlockPresentationCycleID
    let records: [InkBlockPresentationLineageID: Record]
    let orderedLineageIDs: [InkBlockPresentationLineageID]
    let nextLineageRawValue: UInt64
    let environmentSignature: UInt64
    let resolvedEnvironmentSignature: InkBlockPresentationEnvironmentSignature
    let configuration: InkConfiguration
    let constrainedWidth: CGFloat
    let attachmentGeneration: UInt64
    let attachmentToken: InkBlockPresentationAttachmentToken
    let retiredRecords: [Record]
    let pendingInteractions: [PendingInteraction]
    let pendingDirtyLineageIDsToClear: Set<InkBlockPresentationLineageID>
  }

  private(set) var cycleID: InkBlockPresentationCycleID

  private var records: [InkBlockPresentationLineageID: Record] = [:]
  private var orderedLineageIDs: [InkBlockPresentationLineageID] = []
  private var nextLineageRawValue: UInt64 = 0
  private var stateVersion: UInt64 = 0
  private var environmentSignature: UInt64 = 0
  private var lastResolvedEnvironmentSignature: InkBlockPresentationEnvironmentSignature?
  private var lastConfiguration: InkConfiguration?
  private var lastConstrainedWidth: CGFloat?
  private var attachmentGeneration: UInt64 = 0
  private var attachmentToken = InkBlockPresentationAttachmentToken()
  private var pendingDirtyLineageIDs: Set<InkBlockPresentationLineageID> = []
  private var isNotifyingReconcileNeeded = false
  private var reconcileObservers: [ObjectIdentifier: @MainActor () -> Void] = [:]
  private let strategyRegistry = StrategyRegistry()

  init(cycleID: InkBlockPresentationCycleID = InkBlockPresentationCycleID()) {
    self.cycleID = cycleID
  }

  /// 安装 attachment owner 的 reconcile observer；新 owner 可登记接管请求。
  func installReconcileObserver(owner: AnyObject, observer: @escaping @MainActor () -> Void) {
    reconcileObservers[ObjectIdentifier(owner)] = observer
  }

  /// 只清理指定 owner；交叠期的活跃 host 与等待 host 可同时登记。
  func removeReconcileObserver(owner: AnyObject) {
    reconcileObservers.removeValue(forKey: ObjectIdentifier(owner))
  }

  /// 旧 attachment 释放后，通知已经登记的另一 owner 重试首次 reconcile。
  func requestReconcileForWaitingOwner(excluding owner: AnyObject) {
    requestReconcileNeeded(excluding: ObjectIdentifier(owner))
  }

  /// Coordinator 只有持有 continuity 当前已提交 token 时，才拥有 UIKit attachment。
  func ownsAttachment(_ token: InkBlockPresentationAttachmentToken?) -> Bool {
    guard let token else { return false }
    return attachmentToken === token
  }

  /// 结束当前呈现周期并丢弃 durable lineage 与 presentation state。
  func endCycle() {
    attachmentToken.invalidate()
    for record in records.values {
      clearAttachmentCallbacks(on: record)
    }
    records.removeAll()
    orderedLineageIDs.removeAll()
    pendingDirtyLineageIDs.removeAll()
    lastResolvedEnvironmentSignature = nil
    lastConfiguration = nil
    lastConstrainedWidth = nil
    cycleID = InkBlockPresentationCycleID()
    attachmentGeneration &+= 1
    stateVersion &+= 1
  }

  /// reset/cancel 切换 session cycle 时立即作废旧 plan 与 attachment callback。
  ///
  /// 旧 view 暂留在 records 中，只为下一次 reconcile 生成可验证的 unmount；由于
  /// `cycleID` 尚未更新，新 cycle snapshot 仍会清空全部 lineage 与 live state。
  func invalidateForCycleBoundary() {
    // 已 detach 的 session 没有待 UIKit 退休的 attachment；立即清空 journal，
    // 避免无 host 时继续持有上一周期 semantic block 与 live state。
    guard records.values.contains(where: { $0.view != nil }) else {
      endCycle()
      return
    }

    attachmentToken.invalidate()
    attachmentGeneration &+= 1
    for lineageID in orderedLineageIDs {
      guard var record = records[lineageID] else { continue }
      clearAttachmentCallbacks(on: record)
      record.attachmentGeneration = attachmentGeneration
      records[lineageID] = record
    }
    pendingDirtyLineageIDs.removeAll()
    stateVersion &+= 1
  }

  /// host 已不可用、无法执行 UIKit apply plan 时，丢弃可重建 attachment，保留 durable state。
  ///
  /// 正常路径仍使用 `detach()` 的事务 plan；此方法只用于 dismantle 的兜底清理。
  func discardAttachment(ownedBy token: InkBlockPresentationAttachmentToken) {
    guard attachmentToken === token else { return }
    let attachedLineageIDs = orderedLineageIDs.filter { records[$0]?.view != nil }
    guard !attachedLineageIDs.isEmpty else { return }

    attachmentToken.invalidate()
    attachmentGeneration &+= 1
    for lineageID in attachedLineageIDs {
      guard var record = records[lineageID] else { continue }
      clearAttachmentCallbacks(on: record)
      record.view = nil
      record.attachmentGeneration = attachmentGeneration
      records[lineageID] = record
    }
    stateVersion &+= 1
  }

  /// 退休当前 UIKit attachment，同时保留本呈现周期的 durable lineage 与 live state。
  ///
  /// 原 container 必须先消费返回的 plan，另一 continuity context 才能 attach 到同一
  /// container。已经没有 attached view 时返回 `nil`，因此重复 detach 幂等。
  func detach() -> InkBlockPresentationApplyPlan? {
    guard let configuration = lastConfiguration,
          let resolvedEnvironmentSignature = lastResolvedEnvironmentSignature,
          let constrainedWidth = lastConstrainedWidth else {
      return nil
    }

    let priorRecords = records
    let attachedRecords = orderedLineageIDs.compactMap { lineageID -> Record? in
      guard let record = priorRecords[lineageID], record.view != nil else { return nil }
      return record
    }
    let priorViews = attachedRecords.compactMap(\.view)
    guard !priorViews.isEmpty else { return nil }

    let stagedAttachmentGeneration = attachmentGeneration &+ 1
    let stagedAttachmentToken = InkBlockPresentationAttachmentToken()
    var detachedRecords = priorRecords
    for lineageID in orderedLineageIDs {
      guard var record = detachedRecords[lineageID] else { continue }
      record.view = nil
      record.attachmentGeneration = stagedAttachmentGeneration
      detachedRecords[lineageID] = record
    }

    let stagedState = StagedState(
      cycleID: cycleID,
      records: detachedRecords,
      orderedLineageIDs: orderedLineageIDs,
      nextLineageRawValue: nextLineageRawValue,
      environmentSignature: environmentSignature,
      resolvedEnvironmentSignature: resolvedEnvironmentSignature,
      configuration: configuration,
      constrainedWidth: constrainedWidth,
      attachmentGeneration: stagedAttachmentGeneration,
      attachmentToken: stagedAttachmentToken,
      retiredRecords: attachedRecords,
      pendingInteractions: [],
      pendingDirtyLineageIDsToClear: []
    )
    let baseVersion = stateVersion

    return InkBlockPresentationApplyPlan(
      expectedCurrentViews: priorViews,
      configuration: configuration,
      orderedEntries: [],
      operations: priorViews.map(InkBlockPresentationApplyPlan.Operation.unmount)
        + [.order([])],
      invalidatesAllMeasurementSlots: true,
      invalidatedMeasurementLineageIDs: Set(orderedLineageIDs),
      attachmentGeneration: stagedAttachmentGeneration,
      attachmentToken: stagedAttachmentToken,
      invalidatesIntrinsicContentSize: true,
      canCommit: { self.stateVersion == baseVersion },
      commit: { self.commit(stagedState, resolvedEntries: []) }
    )
  }

  /// 只生成 staged plan；records、order、cycle 与 lineage counter 均等到 plan complete 才改变。
  func reconcile(_ snapshot: InkBlockPresentationSnapshot) -> InkBlockPresentationApplyPlan {
    let priorRecords = records
    let priorOrder = orderedLineageIDs
    let priorViews = priorOrder.compactMap { priorRecords[$0]?.view }
    let cycleChanged = snapshot.cycleID != cycleID
    let oldRecords = cycleChanged ? [:] : priorRecords
    let oldOrder = cycleChanged ? [] : priorOrder
    let configurationChanged = lastConfiguration.map {
      !$0.isSemanticallyEqualTo(snapshot.configuration)
    } ?? true
    let resolvedEnvironmentChanged = lastResolvedEnvironmentSignature.map {
      $0 != snapshot.environmentSignature
    } ?? true
    let environmentChanged = cycleChanged || configurationChanged || resolvedEnvironmentChanged
    let widthChanged = lastConstrainedWidth.map {
      abs($0 - snapshot.constrainedWidth) > 0.1
    } ?? true
    let stagedEnvironmentSignature = environmentChanged
      ? environmentSignature &+ 1
      : environmentSignature
    let stagedAttachmentGeneration = attachmentGeneration &+ 1
    let stagedAttachmentToken = InkBlockPresentationAttachmentToken()
    let retiredRecordsForCycle = cycleChanged
      ? priorOrder.compactMap { priorRecords[$0] }
      : []

    var matchedOldLineages: Set<InkBlockPresentationLineageID> = []
    var nextRecords: [InkBlockPresentationLineageID: Record] = [:]
    var nextOrder: [InkBlockPresentationLineageID] = []
    var entries: [InkBlockPresentationApplyPlan.Entry] = []
    var updateOperations: [InkBlockPresentationApplyPlan.Operation] = []
    var replacementOperations: [InkBlockPresentationApplyPlan.Operation] = []
    var unmountOperations: [InkBlockPresentationApplyPlan.Operation] = []
    var mountOperations: [InkBlockPresentationApplyPlan.Operation] = []
    var retiredRecords = retiredRecordsForCycle
    var pendingInteractions: [PendingInteraction] = []
    let pendingDirtyAtStart = pendingDirtyLineageIDs
    var invalidatedLineageIDs: Set<InkBlockPresentationLineageID> = cycleChanged
      ? []
      : pendingDirtyAtStart
    var stagedNextLineageRawValue = cycleChanged ? 0 : nextLineageRawValue

    var newEvidenceCounts = EvidenceCounts()
    var newStructuralCounts: [StructuralMatchKey: Int] = [:]
    var newStructuralEvidence = StructuralEvidence()
    for candidate in snapshot.candidates {
      newEvidenceCounts.insert(candidate)
      let strategy = strategyRegistry.resolve(for: candidate.block)
      newStructuralEvidence.insert(candidate, strategyID: strategy.id)
      let key = StructuralMatchKey(
        structuralSlot: candidate.structuralSlot,
        typeIdentifier: ObjectIdentifier(type(of: candidate.block)),
        strategyID: strategy.id
      )
      newStructuralCounts[key, default: 0] += 1
    }

    var oldRecordLookup = RecordLookup()
    var oldStructuralEvidence = StructuralEvidence()
    for record in oldRecords.values {
      oldRecordLookup.insert(record)
      oldStructuralEvidence.insert(record)
    }
    let ambiguousStructuralMatches = newStructuralEvidence.ambiguousMatches(
      comparedWith: oldStructuralEvidence
    )

    // Resolve the whole snapshot in evidence-priority passes. A weaker claim must
    // never steal a record that is referenced by a stronger claim merely because
    // it appears earlier in presentation order.
    var matchDecisions: [Int: MatchDecision] = [:]
    let oldLineagesClaimedByStableIdentity: Set<InkBlockPresentationLineageID> = Set(
      oldRecords.values.compactMap { record in
        guard let identity = record.stableIdentity,
              newEvidenceCounts.stableIdentities[identity] != nil else {
          return nil
        }
        return record.lineageID
      }
    )
    let oldLineagesClaimedByPromotion: Set<InkBlockPresentationLineageID> = Set(
      oldRecords.values.compactMap { record in
        guard let evidence = record.promotionLineageEvidence,
              newEvidenceCounts.promotionLineages[evidence] != nil else {
          return nil
        }
        return record.lineageID
      }
    )
    let promotionEvidenceClaimedByStableIdentity:
      Set<InkBlockPresentationPromotionLineageEvidence> = Set(
      oldRecords.values.compactMap { record in
        guard oldLineagesClaimedByStableIdentity.contains(record.lineageID) else {
          return nil
        }
        return record.promotionLineageEvidence
      }
    )
    let lineagesReservedForStructuralMatching = oldLineagesClaimedByStableIdentity
      .union(oldLineagesClaimedByPromotion)
    let noReservedLineages = Set<InkBlockPresentationLineageID>()

    for index in snapshot.candidates.indices
      where snapshot.candidates[index].stableIdentity != nil {
      let candidate = snapshot.candidates[index]
      let strategy = strategyRegistry.resolve(for: candidate.block)
      let decision = matchingRecord(
        for: candidate,
        strategy: strategy,
        in: oldRecords,
        lookup: oldRecordLookup,
        excluding: matchedOldLineages,
        reserving: noReservedLineages,
        newEvidenceCounts: newEvidenceCounts,
        newStructuralCounts: newStructuralCounts,
        ambiguousStructuralMatches: ambiguousStructuralMatches
      )
      matchDecisions[index] = decision
      if case let .matched(key, _) = decision {
        matchedOldLineages.insert(key)
      }
    }

    for index in snapshot.candidates.indices
      where snapshot.candidates[index].stableIdentity == nil
        && snapshot.candidates[index].promotionLineageEvidence != nil {
      let candidate = snapshot.candidates[index]
      let strategy = strategyRegistry.resolve(for: candidate.block)
      let conflictsWithStableClaim = candidate.promotionLineageEvidence.map {
        promotionEvidenceClaimedByStableIdentity.contains($0)
      } ?? false
      let decision: MatchDecision
      if conflictsWithStableClaim {
        decision = .ambiguous("promotion evidence conflicts with a stable identity claim")
      } else {
        decision = matchingRecord(
          for: candidate,
          strategy: strategy,
          in: oldRecords,
          lookup: oldRecordLookup,
          excluding: matchedOldLineages,
          reserving: oldLineagesClaimedByStableIdentity,
          newEvidenceCounts: newEvidenceCounts,
          newStructuralCounts: newStructuralCounts,
          ambiguousStructuralMatches: ambiguousStructuralMatches
        )
      }
      matchDecisions[index] = decision
      if case let .matched(key, _) = decision {
        matchedOldLineages.insert(key)
      }
    }

    for index in snapshot.candidates.indices
      where snapshot.candidates[index].stableIdentity == nil
        && snapshot.candidates[index].promotionLineageEvidence == nil {
      let candidate = snapshot.candidates[index]
      let strategy = strategyRegistry.resolve(for: candidate.block)
      let decision = matchingRecord(
        for: candidate,
        strategy: strategy,
        in: oldRecords,
        lookup: oldRecordLookup,
        excluding: matchedOldLineages,
        reserving: lineagesReservedForStructuralMatching,
        newEvidenceCounts: newEvidenceCounts,
        newStructuralCounts: newStructuralCounts,
        ambiguousStructuralMatches: ambiguousStructuralMatches
      )
      matchDecisions[index] = decision
      if case let .matched(key, _) = decision {
        matchedOldLineages.insert(key)
      }
    }

    for (candidateIndex, candidate) in snapshot.candidates.enumerated() {
      let strategy = strategyRegistry.resolve(for: candidate.block)
      let matchDecision = matchDecisions[candidateIndex] ?? .noMatch
      let oldMatch: (key: InkBlockPresentationLineageID, value: Record)?
      switch matchDecision {
      case let .matched(key, value):
        oldMatch = (key: key, value: value)
      case .noMatch:
        oldMatch = nil
      case let .ambiguous(reason):
        diagnoseLocalFallback(for: candidate, reason: reason)
        oldMatch = nil
      }
      let oldRecord = oldMatch?.value

      let suppliedState = strategy.suppliedState(candidate.block)
      let liveState = strategy.resolveLiveState(suppliedState, oldRecord)
      let resolvedBlock = strategy.applyState(candidate.block, liveState)
      let lineageID: InkBlockPresentationLineageID
      if let oldRecord {
        lineageID = oldRecord.lineageID
      } else {
        stagedNextLineageRawValue &+= 1
        lineageID = InkBlockPresentationLineageID(rawValue: stagedNextLineageRawValue)
      }

      let semanticContentIsEquivalent = oldRecord.map {
        strategy.hasEquivalentSemanticContent(candidate.block, $0.semanticBlock)
      } ?? false
      let liveStateChanged = oldRecord.map { $0.liveState != liveState } ?? true
      let viewCompatibilityCanBeProven = oldRecord.map {
        $0.strategyID == strategy.id
          && $0.typeIdentifier == ObjectIdentifier(type(of: candidate.block))
          && (strategy.id != .fallback || strategy.approvesContinuation(candidate, $0))
      } ?? false
      let attachmentTransitionChangesRevision: Bool
      let canKeepAttachedView = !environmentChanged
        && !liveStateChanged
        && semanticContentIsEquivalent
        && viewCompatibilityCanBeProven
        && oldRecord?.view != nil

      let entry: InkBlockPresentationApplyPlan.Entry
      if canKeepAttachedView, let oldView = oldRecord?.view {
        attachmentTransitionChangesRevision = false
        entry = InkBlockPresentationApplyPlan.Entry(
          lineageID: lineageID,
          view: oldView,
          presentationState: liveState,
          measurementKey: InkBlockPresentationMeasurementKey(
            lineageID: lineageID,
            slotRevision: oldRecord?.slotRevision ?? 0,
            constrainedWidth: snapshot.constrainedWidth,
            environmentSignature: stagedEnvironmentSignature
          )
        )
      } else if let oldRecord,
                let oldView = oldRecord.view,
                viewCompatibilityCanBeProven,
                resolvedBlock is any InkReusableBlock {
        let entry = InkBlockPresentationApplyPlan.Entry(
          lineageID: lineageID,
          view: oldView,
          presentationState: liveState,
          measurementKey: InkBlockPresentationMeasurementKey(
            lineageID: lineageID,
            slotRevision: oldRecord.slotRevision &+ 1,
            constrainedWidth: snapshot.constrainedWidth,
            environmentSignature: stagedEnvironmentSignature
          )
        )
        updateOperations.append(
          .update(
            .init(
              entry: entry,
              oldView: oldView,
              makeFallbackView: { strategy.makeView(resolvedBlock) },
              apply: { strategy.updateExistingView(resolvedBlock, oldView) }
            )
          )
        )
        retiredRecords.append(oldRecord)
        entries.append(entry)
        nextOrder.append(lineageID)
        nextRecords[lineageID] = Record(
          lineageID: lineageID,
          structuralSlot: candidate.structuralSlot,
          typeIdentifier: ObjectIdentifier(type(of: candidate.block)),
          stableIdentity: candidate.stableIdentity,
          promotionLineageEvidence: candidate.promotionLineageEvidence,
          semanticBlock: candidate.block,
          lastSuppliedState: suppliedState,
          liveState: liveState,
          strategyID: strategy.id,
          view: oldView,
          slotRevision: oldRecord.slotRevision &+ 1,
          attachmentGeneration: stagedAttachmentGeneration
        )
        invalidatedLineageIDs.insert(lineageID)
        pendingInteractions.append(
          PendingInteraction(
            lineageID: lineageID,
            strategyID: strategy.id,
            attachmentGeneration: stagedAttachmentGeneration
          )
        )
        continue
      } else {
        // View creation is part of apply, after the plan has passed its version check.
        // A custom block may legally return a currently attached UIView, so all views
        // that retire without replacement are unmounted before any factory is invoked.
        attachmentTransitionChangesRevision = oldRecord != nil
        let slotRevision = (oldRecord?.slotRevision ?? 0)
          &+ (attachmentTransitionChangesRevision ? 1 : 0)
        entry = InkBlockPresentationApplyPlan.Entry(
          lineageID: lineageID,
          makeView: { strategy.makeView(resolvedBlock) },
          presentationState: liveState,
          measurementKey: InkBlockPresentationMeasurementKey(
            lineageID: lineageID,
            slotRevision: slotRevision,
            constrainedWidth: snapshot.constrainedWidth,
            environmentSignature: stagedEnvironmentSignature
          )
        )
      }

      let slotRevision = entry.measurementKey.slotRevision
      if oldRecord == nil {
        invalidatedLineageIDs.insert(lineageID)
      }

      if let oldView = oldRecord?.view, attachmentTransitionChangesRevision {
        let replacement = InkBlockPresentationApplyPlan.Replacement(
          oldView: oldView,
          entry: entry
        )
        replacementOperations.append(.replace(replacement))
        if let oldRecord {
          retiredRecords.append(oldRecord)
        }
      } else if oldRecord == nil || oldRecord?.view == nil {
        mountOperations.append(.mount(entry))
      }

      if let oldRecord,
         oldRecord.slotRevision != slotRevision || attachmentTransitionChangesRevision {
        invalidatedLineageIDs.insert(lineageID)
      }

      pendingInteractions.append(
        PendingInteraction(
          lineageID: lineageID,
          strategyID: strategy.id,
          attachmentGeneration: stagedAttachmentGeneration
        )
      )

      entries.append(entry)
      nextOrder.append(lineageID)
      nextRecords[lineageID] = Record(
        lineageID: lineageID,
        structuralSlot: candidate.structuralSlot,
        typeIdentifier: ObjectIdentifier(type(of: candidate.block)),
        stableIdentity: candidate.stableIdentity,
        promotionLineageEvidence: candidate.promotionLineageEvidence,
        semanticBlock: candidate.block,
        lastSuppliedState: suppliedState,
        liveState: liveState,
        strategyID: strategy.id,
        view: canKeepAttachedView ? oldRecord?.view : nil,
        slotRevision: slotRevision,
        attachmentGeneration: stagedAttachmentGeneration
      )
    }

    for lineageID in oldOrder where !matchedOldLineages.contains(lineageID) {
      guard let oldRecord = oldRecords[lineageID] else { continue }
      invalidatedLineageIDs.insert(lineageID)
      if let oldView = oldRecord.view {
        unmountOperations.append(.unmount(oldView))
        retiredRecords.append(oldRecord)
      }
    }

    if cycleChanged {
      for lineageID in priorOrder {
        guard let oldRecord = priorRecords[lineageID],
              let oldView = oldRecord.view else { continue }
        unmountOperations.append(.unmount(oldView))
      }
    }

    let operations = unmountOperations
      + updateOperations
      + replacementOperations
      + mountOperations
      + [.order(entries)]

    let stagedState = StagedState(
      cycleID: snapshot.cycleID,
      records: nextRecords,
      orderedLineageIDs: nextOrder,
      nextLineageRawValue: stagedNextLineageRawValue,
      environmentSignature: stagedEnvironmentSignature,
      resolvedEnvironmentSignature: snapshot.environmentSignature,
      configuration: snapshot.configuration,
      constrainedWidth: snapshot.constrainedWidth,
      attachmentGeneration: stagedAttachmentGeneration,
      attachmentToken: stagedAttachmentToken,
      retiredRecords: retiredRecords,
      pendingInteractions: pendingInteractions,
      pendingDirtyLineageIDsToClear: pendingDirtyAtStart
    )
    let baseVersion = stateVersion

    return InkBlockPresentationApplyPlan(
      expectedCurrentViews: priorViews,
      configuration: snapshot.configuration,
      orderedEntries: entries,
      operations: operations,
      invalidatesAllMeasurementSlots: environmentChanged,
      invalidatedMeasurementLineageIDs: invalidatedLineageIDs,
      attachmentGeneration: stagedAttachmentGeneration,
      attachmentToken: stagedAttachmentToken,
      invalidatesIntrinsicContentSize: environmentChanged
        || widthChanged
        || !invalidatedLineageIDs.isEmpty
        || oldOrder != nextOrder,
      canCommit: { self.stateVersion == baseVersion },
      commit: { self.commit(stagedState, resolvedEntries: entries) }
    )
  }

  private func matchingRecord(
    for candidate: InkBlockPresentationCandidate,
    strategy: Strategy,
    in records: [InkBlockPresentationLineageID: Record],
    lookup: RecordLookup,
    excluding matched: Set<InkBlockPresentationLineageID>,
    reserving reserved: Set<InkBlockPresentationLineageID>,
    newEvidenceCounts: EvidenceCounts,
    newStructuralCounts: [StructuralMatchKey: Int],
    ambiguousStructuralMatches: Set<StructuralMatchKey>
  ) -> MatchDecision {
    func availableRecords(
      for lineageIDs: [InkBlockPresentationLineageID]?
    ) -> [Record] {
      guard let lineageIDs else { return [] }
      return lineageIDs.compactMap { lineageID in
        guard !matched.contains(lineageID),
              !reserved.contains(lineageID) else {
          return nil
        }
        return records[lineageID]
      }
    }

    func validatedStrongMatch(_ record: Record) -> MatchDecision {
      guard strategy.id != .fallback
              || strategy.approvesContinuation(candidate, record) else {
        return .ambiguous("custom strong evidence violates strict structural compatibility")
      }
      return .matched(key: record.lineageID, value: record)
    }

    if strategy.id == .fallback && !(candidate.block is any InkReusableBlock) {
      return .ambiguous("non-reusable custom block has no continuity strategy")
    }

    // Strong evidence is authoritative. Even when it cannot resolve, never fall
    // through to structural matching: doing so can steal state from another block.
    if let stableIdentity = candidate.stableIdentity {
      guard newEvidenceCounts.stableIdentities[stableIdentity, default: 0] == 1,
            lookup.stableIdentities[stableIdentity, default: []].count <= 1 else {
        return .ambiguous("duplicate stable identity")
      }

      let stableMatches = availableRecords(for: lookup.stableIdentities[stableIdentity])
      guard stableMatches.count <= 1 else {
        return .ambiguous("stable identity resolves to multiple records")
      }

      if let promotionEvidence = candidate.promotionLineageEvidence {
        guard newEvidenceCounts.promotionLineages[promotionEvidence, default: 0] == 1,
              lookup.promotionLineages[promotionEvidence, default: []].count <= 1 else {
          return .ambiguous("duplicate promotion evidence")
        }

        let promotionMatches = availableRecords(for: lookup.promotionLineages[promotionEvidence])
        guard promotionMatches.count <= 1 else {
          return .ambiguous("promotion evidence resolves to multiple records")
        }
        guard let stableMatch = stableMatches.first,
              let promotionMatch = promotionMatches.first else {
          return stableMatches.isEmpty && promotionMatches.isEmpty
            ? .noMatch
            : .ambiguous("stable identity conflicts with promotion evidence")
        }
        guard stableMatch.lineageID == promotionMatch.lineageID else {
          return .ambiguous("stable identity conflicts with promotion evidence")
        }

        return validatedStrongMatch(stableMatch)
      }

      guard let match = stableMatches.first else { return .noMatch }
      return validatedStrongMatch(match)
    }

    if let promotionEvidence = candidate.promotionLineageEvidence {
      guard newEvidenceCounts.promotionLineages[promotionEvidence, default: 0] == 1,
            lookup.promotionLineages[promotionEvidence, default: []].count <= 1 else {
        return .ambiguous("duplicate promotion evidence")
      }

      let promotionMatches = availableRecords(for: lookup.promotionLineages[promotionEvidence])
      guard promotionMatches.count <= 1 else {
        return .ambiguous("promotion evidence resolves to multiple records")
      }
      guard let match = promotionMatches.first else { return .noMatch }
      return validatedStrongMatch(match)
    }

    guard !records.isEmpty else { return .noMatch }

    let structuralKey = StructuralMatchKey(
      structuralSlot: candidate.structuralSlot,
      typeIdentifier: ObjectIdentifier(type(of: candidate.block)),
      strategyID: strategy.id
    )
    guard !ambiguousStructuralMatches.contains(structuralKey) else {
      return .ambiguous("structural slot changed cardinality, repeated, or moved")
    }
    guard newStructuralCounts[structuralKey, default: 0] == 1,
          lookup.structuralMatches[structuralKey, default: []].count == 1 else {
      return .ambiguous("repeated structural identity")
    }

    let matches = availableRecords(for: lookup.structuralMatches[structuralKey]).filter {
      strategy.approvesContinuation(candidate, $0)
    }
    guard matches.count == 1, let match = matches.first else {
      return matches.isEmpty
        ? .ambiguous("strategy did not approve structural continuation")
        : .ambiguous("structural continuation resolves to multiple records")
    }
    return .matched(key: match.lineageID, value: match)
  }

  private func diagnoseLocalFallback(
    for candidate: InkBlockPresentationCandidate,
    reason: String
  ) {
#if DEBUG
    os_log(
      .error,
      log: inkBlockPresentationContinuityLog,
      "local fallback at structural slot %{public}d: %{public}@",
      candidate.structuralSlot,
      reason
    )
#else
    _ = candidate
    _ = reason
#endif
  }

  private func receiveThoughtCollapse(
    _ collapsed: Bool,
    for lineageID: InkBlockPresentationLineageID,
    view: InkThoughtBlockView,
    attachmentGeneration: UInt64
  ) {
    guard var record = records[lineageID],
          record.view === view,
          record.strategyID == .thought,
          record.attachmentGeneration == attachmentGeneration else {
      return
    }
    guard record.liveState != .thought(isCollapsed: collapsed) else { return }
    record.liveState = .thought(isCollapsed: collapsed)
    record.slotRevision &+= 1
    records[lineageID] = record
    pendingDirtyLineageIDs.insert(lineageID)
    stateVersion &+= 1
    requestReconcileNeeded()
  }

  private func commit(
    _ stagedState: StagedState,
    resolvedEntries: [InkBlockPresentationApplyPlan.Entry]
  ) {
    let resolvedViews = Dictionary(
      uniqueKeysWithValues: resolvedEntries.map { ($0.lineageID, $0.view) }
    )
    for record in stagedState.retiredRecords {
      clearInteractionCallback(on: record)
    }
    for pendingInteraction in stagedState.pendingInteractions {
      guard let view = resolvedViews[pendingInteraction.lineageID] else { continue }
      strategyRegistry.resolve(id: pendingInteraction.strategyID).installInteractionHandler(
        view,
        pendingInteraction.lineageID,
        pendingInteraction.attachmentGeneration,
        self
      )
    }
    cycleID = stagedState.cycleID
    records = stagedState.records.mapValues { record in
      var resolved = record
      resolved.view = resolvedViews[record.lineageID]
      return resolved
    }
    orderedLineageIDs = stagedState.orderedLineageIDs
    nextLineageRawValue = stagedState.nextLineageRawValue
    environmentSignature = stagedState.environmentSignature
    lastResolvedEnvironmentSignature = stagedState.resolvedEnvironmentSignature
    lastConfiguration = stagedState.configuration
    lastConstrainedWidth = stagedState.constrainedWidth
    attachmentGeneration = stagedState.attachmentGeneration
    attachmentToken = stagedState.attachmentToken
    pendingDirtyLineageIDs.subtract(stagedState.pendingDirtyLineageIDsToClear)
    stateVersion &+= 1
  }

  private func requestReconcileNeeded(excluding excludedOwner: ObjectIdentifier? = nil) {
    guard !isNotifyingReconcileNeeded else { return }
    isNotifyingReconcileNeeded = true
    defer { isNotifyingReconcileNeeded = false }

    let observers = reconcileObservers
      .filter { $0.key != excludedOwner }
      .map(\.value)
    for observer in observers {
      observer()
    }
  }

  private func clearInteractionCallback(on record: Record) {
    guard let view = record.view else { return }
    strategyRegistry.resolve(id: record.strategyID).clearInteractionHandler(view)
  }

  private func clearAttachmentCallbacks(on record: Record) {
    guard let view = record.view else { return }
    strategyRegistry.resolve(id: record.strategyID).clearInteractionHandler(view)
    (view as? InkImageBlock)?.onReservedHeightChanged = nil
    (view as? InkThoughtBlockView)?.onReservedHeightChanged = nil
  }
}
