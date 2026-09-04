//
//  InkMarkdownContainerView.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import UIKit

enum InkIntrinsicMeasurementWidthResolver {
  static func resolve(
    contentWidth: CGFloat,
    windowWidth: CGFloat,
    legacyFallbackWidth: CGFloat
  ) -> CGFloat {
    if contentWidth > 0 { return contentWidth }
    if windowWidth > 0 { return windowWidth }
    return max(legacyFallbackWidth, 0)
  }
}

/// 承载 Markdown 块级视图的 UIKit 容器视图。
///
/// 测量入口唯一：`sizeThatFits` 与 `intrinsicContentSize` 调用 `measureContent`。
/// `layoutSubviews` 仅把已缓存的测量结果写成 frame，禁止二次 `sizeThatFits`。
final class InkMarkdownContainerView: UIView {

  private struct ContinuityLayoutEntry {
    let lineageID: InkBlockPresentationLineageID
    let measurementKey: InkBlockPresentationMeasurementKey
    let attachmentGeneration: UInt64
    weak var view: UIView?
    var size: CGSize
  }

  private var blockViews: [UIView] = []
  private var continuityLayoutEntries: [ContinuityLayoutEntry] = []
  private var continuityMeasurementCache: [InkBlockPresentationMeasurementKey: CGSize] = [:]
  private var continuityAttachmentGeneration: UInt64 = 0
  private var continuityAttachmentToken: InkBlockPresentationAttachmentToken?

  internal private(set) var currentConfiguration: InkConfiguration?
  private var lastMeasuredWidth: CGFloat = 0
  private var lastReportedContinuityWidth: CGFloat?
  private var lastReportedContinuityEnvironmentSignature: InkBlockPresentationEnvironmentSignature?

  /// 仅报告容器观察到的环境事实；Coordinator 决定是否生成新的 continuity plan。
  internal var onContinuityLayoutEnvironmentChanged:
    (@MainActor (CGFloat, InkBlockPresentationEnvironmentSignature) -> Bool)?

  internal private(set) var cachedTotalHeightForTesting: CGFloat = 0
  internal private(set) var blockMeasurementInvocationCount = 0
  internal private(set) var layoutSubviewsICSInvalidateCount = 0
  internal private(set) var reservedHeightSlotUpdateCount = 0
  internal var continuityMeasurementKeysForTesting: [InkBlockPresentationMeasurementKey] {
    continuityLayoutEntries.map(\.measurementKey)
  }
  internal var continuityMeasurementCacheCountForTesting: Int {
    continuityMeasurementCache.count
  }
  internal private(set) var continuityAttachmentGenerationForTesting: UInt64 = 0

  internal func resetLayoutSubviewsICSInvalidateCountForTesting() {
    layoutSubviewsICSInvalidateCount = 0
  }

  internal func cachedContinuitySlotHeight(
    for key: InkBlockPresentationMeasurementKey,
    width: CGFloat? = nil
  ) -> CGFloat? {
    let resolvedKey = width.map(key.replacingWidth) ?? key
    return continuityMeasurementCache[resolvedKey]?.height
  }

  internal var effectiveMeasureWidth: CGFloat {
    resolvedWidth > 0 ? resolvedWidth : lastMeasuredWidth
  }

  private var isInsideLayoutSubviews = false
  private var lastAppliedRenderEnvironment: InkRenderEnvironment?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = .clear
  }

  var hasBlocks: Bool {
    !blockViews.isEmpty
  }

  internal func resolvedEnvironmentSignature(
    for configuration: InkConfiguration
  ) -> InkBlockPresentationEnvironmentSignature {
    InkBlockPresentationEnvironmentSignature(
      configuration: configuration,
      traitCollection: traitCollection
    )
  }

  /// 消费 continuity module 产出的单次 apply plan。
  @discardableResult
  internal func apply(_ plan: InkBlockPresentationApplyPlan) -> Bool {
    let previousContinuityLayoutEntries = Dictionary(
      continuityLayoutEntries.map { ($0.lineageID, $0) },
      uniquingKeysWith: { current, _ in current }
    )

    guard blockViews.count == plan.expectedCurrentViews.count,
          zip(blockViews, plan.expectedCurrentViews).allSatisfy({ pair in
            pair.0 === pair.1
          }) else {
      plan.abort()
      return false
    }

    guard plan.begin() else {
      plan.abort()
      return false
    }

    continuityAttachmentToken?.invalidate()
    continuityAttachmentToken = plan.attachmentToken

    if plan.invalidatesAllMeasurementSlots {
      continuityMeasurementCache.removeAll()
    } else if !plan.invalidatedMeasurementLineageIDs.isEmpty {
      continuityMeasurementCache = continuityMeasurementCache.filter {
        !plan.invalidatedMeasurementLineageIDs.contains($0.key.lineageID)
      }
    }

    for operation in plan.operations {
      switch operation {
      case .update(let update):
        clearContinuityHeightInvalidation(for: update.oldView)
        if !update.apply() {
          let fallbackView = update.makeFallbackView()
          update.oldView.removeFromSuperview()
          if fallbackView.superview !== self {
            addSubview(fallbackView)
          }
          update.entry.replaceResolvedView(with: fallbackView)
        }
      case .replace(let replacement):
        clearContinuityHeightInvalidation(for: replacement.oldView)
        replacement.oldView.removeFromSuperview()
        let newView = replacement.entry.resolveView()
        if newView.superview !== self {
          addSubview(newView)
        }
      case .unmount(let view):
        clearContinuityHeightInvalidation(for: view)
        view.removeFromSuperview()
      case .mount(let entry):
        let view = entry.resolveView()
        if view.superview !== self {
          addSubview(view)
        }
      case .order(let orderedEntries):
        applyContinuitySubviewOrder(orderedEntries.map(\.view))
      }
    }

    blockViews = plan.orderedEntries.map(\.view)
    continuityAttachmentGeneration = plan.attachmentGeneration
    continuityAttachmentGenerationForTesting = plan.attachmentGeneration
    continuityLayoutEntries = plan.orderedEntries.map {
      let preservedSize = preservedContinuitySize(
        for: $0,
        previousEntries: previousContinuityLayoutEntries,
        invalidatedLineageIDs: plan.invalidatedMeasurementLineageIDs
      )
      return ContinuityLayoutEntry(
        lineageID: $0.lineageID,
        measurementKey: $0.measurementKey,
        attachmentGeneration: plan.attachmentGeneration,
        view: $0.view,
        size: preservedSize
      )
    }

    currentConfiguration = plan.configuration

    for entry in plan.orderedEntries {
      wireContinuityHeightInvalidation(
        for: entry.view,
        lineageID: entry.lineageID,
        attachmentGeneration: plan.attachmentGeneration,
        attachmentToken: plan.attachmentToken
      )
    }

    applyRenderEnvironmentTraits(from: plan.configuration)

    let currentWidth = resolvedWidth
    lastReportedContinuityWidth = currentWidth > 0 ? currentWidth : nil
    lastReportedContinuityEnvironmentSignature = resolvedEnvironmentSignature(
      for: plan.configuration
    )

    if plan.invalidatesIntrinsicContentSize {
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }

    let completed = plan.complete()
    assert(completed, "continuity apply plan must complete after UIKit operations")
    return completed
  }

  private func applyContinuitySubviewOrder(_ orderedViews: [UIView]) {
    for view in orderedViews where view.superview === self {
      bringSubviewToFront(view)
    }
  }

  private func clearContinuityHeightInvalidation(for view: UIView) {
    (view as? InkImageBlock)?.onReservedHeightChanged = nil
    (view as? InkThoughtBlockView)?.onReservedHeightChanged = nil
  }

  private func updateContinuityReservedHeightSlot(
    lineageID: InkBlockPresentationLineageID,
    view: UIView,
    attachmentGeneration: UInt64
  ) {
    guard attachmentGeneration == continuityAttachmentGeneration,
          let index = continuityLayoutEntries.firstIndex(where: {
            $0.lineageID == lineageID
              && $0.attachmentGeneration == attachmentGeneration
              && $0.view === view
          }) else {
      return
    }

    reservedHeightSlotUpdateCount += 1
    let committedWidth = continuityLayoutEntries[index].measurementKey.constrainedWidth
    let width: CGFloat
    if lastMeasuredWidth > 0,
       committedWidth <= 0 || abs(lastMeasuredWidth - committedWidth) <= 0.1 {
      // Reconciliation intentionally coalesces subpixel width jitter. Height callbacks must
      // therefore refresh the exact width most recently measured by the host; otherwise they
      // revive a second committed-width cache entry and leave the live-width entry stale.
      width = lastMeasuredWidth
    } else {
      width = committedWidth > 0 ? committedWidth : effectiveMeasureWidth
    }
    guard width > 0 else { return }

    let key = continuityLayoutEntries[index].measurementKey.replacingWidth(width)
    let size = view.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    continuityMeasurementCache[key] = size
    continuityLayoutEntries[index].size = size
    cachedTotalHeightForTesting = continuityLayoutEntries.reduce(0) { $0 + $1.size.height }

    setNeedsLayout()
    invalidateIntrinsicContentSize()
    superview?.setNeedsLayout()
  }

  private func preservedContinuitySize(
    for entry: InkBlockPresentationApplyPlan.Entry,
    previousEntries: [InkBlockPresentationLineageID: ContinuityLayoutEntry],
    invalidatedLineageIDs: Set<InkBlockPresentationLineageID>
  ) -> CGSize {
    guard !invalidatedLineageIDs.contains(entry.lineageID),
          let previous = previousEntries[entry.lineageID],
          previous.measurementKey == entry.measurementKey,
          previous.view === entry.view else {
      return .zero
    }

    if let cached = continuityMeasurementCache[entry.measurementKey] {
      return cached
    }
    if lastMeasuredWidth > 0,
       let cached = continuityMeasurementCache[entry.measurementKey.replacingWidth(lastMeasuredWidth)] {
      return cached
    }
    return previous.size
  }

  override func invalidateIntrinsicContentSize() {
    if isInsideLayoutSubviews {
      layoutSubviewsICSInvalidateCount += 1
    }
    super.invalidateIntrinsicContentSize()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    guard let configuration = currentConfiguration,
          let previousTraitCollection else {
      return
    }

    let previousSignature = InkBlockPresentationEnvironmentSignature(
      configuration: configuration,
      traitCollection: previousTraitCollection
    )
    let currentSignature = resolvedEnvironmentSignature(for: configuration)
    guard previousSignature != currentSignature else { return }

    reportContinuityLayoutEnvironmentIfNeeded(forceEnvironmentChange: true)
  }

  override var intrinsicContentSize: CGSize {
    let width = intrinsicMeasurementWidth
    guard width > 0 else {
      return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    reportContinuityLayoutEnvironmentIfNeeded(width)
    let height = measureContent(for: width)
    return CGSize(width: UIView.noIntrinsicMetric, height: height)
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    reportContinuityLayoutEnvironmentIfNeeded(size.width > 0 ? size.width : nil)
    let width = size.width > 0 ? size.width : resolvedWidth
    guard width > 0 else { return .zero }
    let height = measureContent(for: width)
    return CGSize(width: width, height: height)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    reportContinuityLayoutEnvironmentIfNeeded()
    let width = bounds.width
    guard width > 0 else { return }

    isInsideLayoutSubviews = true
    defer { isInsideLayoutSubviews = false }

    var y: CGFloat = 0
    for entry in continuityLayoutEntries {
      guard let view = entry.view else { continue }
      view.frame = CGRect(x: 0, y: y, width: width, height: entry.size.height)
      y += entry.size.height
    }
  }

  // MARK: - Private Helpers

  private var resolvedWidth: CGFloat {
    if bounds.width > 0 { return bounds.width }
    if let superviewWidth = superview?.bounds.width, superviewWidth > 0 { return superviewWidth }
    return 0
  }

  /// iOS 15 的 `UIViewRepresentable` 没有 proposal-based 测量入口。宿主层级首轮宽度
  /// 仍为零时，优先采用实际 window 宽度；仅在 iOS 15 且尚未挂入 window 时退回主屏宽度。
  private var intrinsicMeasurementWidth: CGFloat {
    let legacyFallbackWidth: CGFloat
    if #unavailable(iOS 16.0) {
      legacyFallbackWidth = legacyMainScreenWidth
    } else {
      legacyFallbackWidth = 0
    }
    return InkIntrinsicMeasurementWidthResolver.resolve(
      contentWidth: resolvedWidth,
      windowWidth: window?.bounds.width ?? 0,
      legacyFallbackWidth: legacyFallbackWidth
    )
  }

  /// `UIScreen.main` 自 iOS 16 起废弃；此兼容入口只会编译并运行于 iOS 15 路径。
  @available(iOS, introduced: 15.0, obsoleted: 16.0)
  private var legacyMainScreenWidth: CGFloat {
    UIScreen.main.bounds.width
  }

  private func reportContinuityLayoutEnvironmentIfNeeded(
    _ proposedWidth: CGFloat? = nil,
    forceEnvironmentChange: Bool = false
  ) {
    guard let configuration = currentConfiguration else {
      return
    }

    let width = proposedWidth.flatMap { $0 > 0 ? $0 : nil } ?? resolvedWidth
    guard width > 0 else { return }

    let signature = resolvedEnvironmentSignature(for: configuration)
    let widthChanged = lastReportedContinuityWidth.map {
      abs($0 - width) > 0.1
    } ?? true
    let environmentChanged = lastReportedContinuityEnvironmentSignature.map {
      $0 != signature
    } ?? true
    guard widthChanged || environmentChanged || forceEnvironmentChange else { return }

    let accepted = onContinuityLayoutEnvironmentChanged?(width, signature) ?? true
    guard accepted else { return }
    lastReportedContinuityWidth = width
    lastReportedContinuityEnvironmentSignature = signature
  }

  @discardableResult
  private func measureContent(for width: CGFloat) -> CGFloat {
    guard width > 0 else { return 0 }

    // Measurement key 使用精确 CGFloat；容差内必须复用上次规范宽度，否则虽不清缓存，
    // 仍会为每个亚像素抖动追加一组新 key，最终形成无界缓存增长。
    if lastMeasuredWidth <= 0 || abs(lastMeasuredWidth - width) > 0.1 {
      continuityMeasurementCache.removeAll(keepingCapacity: true)
      lastMeasuredWidth = width
    }

    blockMeasurementInvocationCount = 0
    return measureContinuityContent(for: lastMeasuredWidth)
  }

  @discardableResult
  private func measureContinuityContent(for width: CGFloat) -> CGFloat {
    var total: CGFloat = 0

    for index in continuityLayoutEntries.indices {
      guard let view = continuityLayoutEntries[index].view else { continue }
      let key = continuityLayoutEntries[index].measurementKey.replacingWidth(width)
      let size: CGSize
      if let cached = continuityMeasurementCache[key] {
        size = cached
      } else {
        blockMeasurementInvocationCount += 1
        size = view.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        continuityMeasurementCache[key] = size
      }
      continuityLayoutEntries[index].size = size
      total += size.height
    }

    cachedTotalHeightForTesting = total
    return total
  }

  private func wireContinuityHeightInvalidation(
    for view: UIView,
    lineageID: InkBlockPresentationLineageID,
    attachmentGeneration: UInt64,
    attachmentToken: InkBlockPresentationAttachmentToken
  ) {
    if let imageView = view as? InkImageBlock {
      imageView.onReservedHeightChanged = { [weak self, weak imageView, attachmentToken] in
        guard let self, let imageView else { return }
        guard attachmentToken.isValid else { return }
        self.updateContinuityReservedHeightSlot(
          lineageID: lineageID,
          view: imageView,
          attachmentGeneration: attachmentGeneration
        )
      }
    }
    if let thoughtView = view as? InkThoughtBlockView {
      thoughtView.onReservedHeightChanged = { [weak self, weak thoughtView, attachmentToken] in
        guard let self, let thoughtView else { return }
        guard attachmentToken.isValid else { return }
        self.updateContinuityReservedHeightSlot(
          lineageID: lineageID,
          view: thoughtView,
          attachmentGeneration: attachmentGeneration
        )
      }
    }
  }

  private func applyRenderEnvironmentTraits(from configuration: InkConfiguration) {
    let environment = configuration.renderEnvironment
    overrideUserInterfaceStyle = environment.userInterfaceStyle

    if environment != lastAppliedRenderEnvironment {
      lastAppliedRenderEnvironment = environment
      setNeedsLayout()
    }
  }
}
