//
//  InkMarkdownContainerView.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import UIKit

enum InkIntrinsicMeasurementWidthResolver {
  /// 固有尺寸宽度顺序：自身已布局宽 → 宿主 `preferredMeasurementWidth` → 父级估算宽 → window → Scene fallback。
  static func resolve(
    preferredWidth: CGFloat = 0,
    contentWidth: CGFloat,
    parentWidth: CGFloat = 0,
    windowWidth: CGFloat,
    sceneFallbackWidth: CGFloat
  ) -> CGFloat {
    if contentWidth > 0 { return contentWidth }
    if preferredWidth > 0 { return preferredWidth }
    if parentWidth > 0 { return parentWidth }
    if windowWidth > 0 { return windowWidth }
    return max(sceneFallbackWidth, 0)
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

  /// 宿主在首轮 layout 前提供的最终内容宽度（pt）。
  ///
  /// 大于 0 时，在自身 `bounds` 仍为零的阶段参与固有尺寸测量，避免 chat cell
  /// 「先矮后高」二次 layout。自身已布局的 `bounds.width` 仍优先于该值；父级估算宽排在其后。
  /// 变化超过 0.1pt 时清空测量缓存并失效固有尺寸。
  var preferredMeasurementWidth: CGFloat = 0 {
    didSet {
      guard abs(oldValue - preferredMeasurementWidth) > 0.1 else { return }
      continuityMeasurementCache.removeAll(keepingCapacity: true)
      lastMeasuredWidth = 0
      setNeedsLayout()
      invalidateIntrinsicContentSize()
      superview?.setNeedsLayout()
    }
  }

  /// 仅报告容器观察到的环境事实；Coordinator 决定是否生成新的 continuity plan。
  internal var onContinuityLayoutEnvironmentChanged:
    (@MainActor (CGFloat, InkBlockPresentationEnvironmentSignature) -> Bool)?

  /// 容器内某个 block 的保留高度更新后通知宿主（如图片加载完成、Thought 异步展开）。
  internal var onContinuityHeightChanged: (@MainActor () -> Void)?

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
    if laidOutContentWidth > 0 { return laidOutContentWidth }
    if preferredMeasurementWidth > 0 { return preferredMeasurementWidth }
    if parentEstimatedWidth > 0 { return parentEstimatedWidth }
    return lastMeasuredWidth
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

    let currentWidth = laidOutContentWidth
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
    onContinuityHeightChanged?()
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
    let width = size.width > 0 ? size.width : laidOutContentWidth
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

  /// 自身已完成布局的内容宽；为零时不算已确认列宽。
  private var laidOutContentWidth: CGFloat {
    bounds.width > 0 ? bounds.width : 0
  }

  /// 父视图宽，仅作固有尺寸估算，不等于扣除 inset 后的宿主内容宽。
  private var parentEstimatedWidth: CGFloat {
    guard let superviewWidth = superview?.bounds.width, superviewWidth > 0 else { return 0 }
    return superviewWidth
  }

  /// iOS 15 的 `UIViewRepresentable` 没有 proposal-based 测量入口。自身 bounds 仍为零时，
  /// 依次采用 `preferredMeasurementWidth`、父级估算宽、window / 前台 Scene 宽度。
  private var intrinsicMeasurementWidth: CGFloat {
    let sceneFallbackWidth: CGFloat
    if #unavailable(iOS 16.0) {
      sceneFallbackWidth = foregroundSceneWidth
    } else {
      sceneFallbackWidth = 0
    }
    return InkIntrinsicMeasurementWidthResolver.resolve(
      preferredWidth: preferredMeasurementWidth,
      contentWidth: laidOutContentWidth,
      parentWidth: parentEstimatedWidth,
      windowWidth: window?.bounds.width ?? 0,
      sceneFallbackWidth: sceneFallbackWidth
    )
  }

  private var foregroundSceneWidth: CGFloat {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first(where: { $0.activationState == .foregroundActive })?
      .screen.bounds.width ?? 0
  }

  private func reportContinuityLayoutEnvironmentIfNeeded(
    _ proposedWidth: CGFloat? = nil,
    forceEnvironmentChange: Bool = false
  ) {
    guard let configuration = currentConfiguration else {
      return
    }

    let width = proposedWidth.flatMap { $0 > 0 ? $0 : nil } ?? laidOutContentWidth
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
