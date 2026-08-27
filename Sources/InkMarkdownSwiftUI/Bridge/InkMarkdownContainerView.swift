//
//  InkMarkdownContainerView.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import UIKit

/// 承载 Markdown 块级视图的 UIKit 容器视图。
///
/// 测量入口唯一：`sizeThatFits` 与 `intrinsicContentSize` 调用 `measureContent`。
/// `layoutSubviews` 仅把已缓存的测量结果写成 frame，禁止二次 `sizeThatFits`。
final class InkMarkdownContainerView: UIView {

  private struct MeasurementCacheKey: Hashable {
    let identity: InkBlockIdentity
    let widthBits: UInt64
  }

  private struct LayoutEntry {
    let identity: InkBlockIdentity
    weak var view: UIView?
    var size: CGSize
  }

  private var blockViews: [UIView] = []
  private var blockIdentities: [InkBlockIdentity] = []
  private var identityToView: [InkBlockIdentity: UIView] = [:]
  private var contentFingerprints: [InkBlockIdentity: UInt64] = [:]
  private var slotCache: [MeasurementCacheKey: CGSize] = [:]
  private var layoutEntries: [LayoutEntry] = []

  internal private(set) var currentConfiguration: InkConfiguration?
  private var lastMeasuredWidth: CGFloat = 0

  /// 流式 attachment（不在 blockViews 内，但参与测量序）。
  private var streamThoughtIdentity: InkBlockIdentity?
  private weak var streamThoughtView: UIView?
  private var streamTextIdentity: InkBlockIdentity?
  private weak var streamTextView: UIView?

  internal private(set) var cachedTotalHeightForTesting: CGFloat = 0
  internal private(set) var blockMeasurementInvocationCount = 0
  internal private(set) var layoutSubviewsICSInvalidateCount = 0
  internal private(set) var reservedHeightSlotUpdateCount = 0

  internal func resetLayoutSubviewsICSInvalidateCountForTesting() {
    layoutSubviewsICSInvalidateCount = 0
  }

  internal func cachedSlotHeight(for identity: InkBlockIdentity, width: CGFloat) -> CGFloat? {
    slotCache[MeasurementCacheKey(identity: identity, widthBits: UInt64(width.bitPattern))]?.height
  }

  internal var effectiveMeasureWidth: CGFloat {
    lastMeasuredWidth > 0 ? lastMeasuredWidth : resolvedWidth
  }

  private var isInsideLayoutSubviews = false
  private var appliedEnvironmentTraits: UITraitCollection?
  private var lastAppliedRenderEnvironment: InkRenderEnvironment?

  override var traitCollection: UITraitCollection {
    if let appliedEnvironmentTraits {
      return UITraitCollection(traitsFrom: [super.traitCollection, appliedEnvironmentTraits])
    }
    return super.traitCollection
  }

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

  internal func invalidateAllMeasurementSlots() {
    let preservedWidth = lastMeasuredWidth
    slotCache.removeAll()
    layoutEntries.removeAll()
    lastMeasuredWidth = preservedWidth
    cachedTotalHeightForTesting = 0
  }

  internal func preRegisterView(_ view: UIView, for identity: InkBlockIdentity) {
    identityToView[identity] = view
  }

  internal func configureStreamingAttachments(
    thought: (identity: InkBlockIdentity, view: UIView)?,
    text: (identity: InkBlockIdentity, view: UIView)?
  ) {
    streamThoughtIdentity = thought?.identity
    streamThoughtView = thought?.view
    streamTextIdentity = text?.identity
    streamTextView = text?.view
  }

  internal func clearStreamingAttachments() {
    streamThoughtIdentity = nil
    streamThoughtView = nil
    streamTextIdentity = nil
    streamTextView = nil
  }

  /// 单槽保留高更新：只改写对应 cache 项，再宣告 ICS 一次；不清整表。
  internal func updateReservedHeightSlot(identity: InkBlockIdentity, view: UIView) {
    reservedHeightSlotUpdateCount += 1
    let width = lastMeasuredWidth > 0 ? lastMeasuredWidth : resolvedWidth
    guard width > 0 else { return }

    let size = view.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    slotCache[MeasurementCacheKey(identity: identity, widthBits: UInt64(width.bitPattern))] = size

    if let index = layoutEntries.firstIndex(where: { $0.identity == identity }) {
      layoutEntries[index].size = size
      cachedTotalHeightForTesting = layoutEntries.reduce(0) { $0 + $1.size.height }
    }

    invalidateIntrinsicContentSize()
    superview?.setNeedsLayout()
  }

  internal func invalidateMeasurementSlot(identity: InkBlockIdentity, width: CGFloat? = nil) {
    let measureWidth = width ?? lastMeasuredWidth
    guard measureWidth > 0 else { return }
    slotCache.removeValue(forKey: MeasurementCacheKey(identity: identity, widthBits: UInt64(measureWidth.bitPattern)))
  }

  func updateBlocks(
    _ blocks: [InkRenderableBlock],
    configuration: InkConfiguration,
    documentEpoch: UInt64 = 0,
    onThoughtCollapseChanged: (@MainActor (Int, Bool) -> Void)? = nil
  ) {
    let configurationChanged = currentConfiguration.map { !$0.isSemanticallyEqualTo(configuration) } ?? true
    if configurationChanged {
      identityToView.removeAll()
      contentFingerprints.removeAll()
      invalidateAllMeasurementSlots()
    }

    currentConfiguration = configuration
    clearStreamingAttachments()

    var newBlockViews: [UIView] = []
    var newIdentities: [InkBlockIdentity] = []
    var newIdentityMap: [InkBlockIdentity: UIView] = [:]
    var newFingerprints: [InkBlockIdentity: UInt64] = [:]
    var dirtySlotIdentities: Set<InkBlockIdentity> = []

    for (index, block) in blocks.enumerated() {
      let identity = block.resolvedIdentity(documentEpoch: documentEpoch, blockIndex: index)
      let fingerprint = block.contentFingerprint(documentEpoch: documentEpoch, blockIndex: index)
      newFingerprints[identity] = fingerprint

      let view: UIView
      if let existing = identityToView[identity], contentFingerprints[identity] == fingerprint {
        view = existing
      } else if let existing = identityToView[identity] {
        block.updateExistingView(existing)
        view = existing
        dirtySlotIdentities.insert(identity)
      } else {
        view = block.makeView()
        dirtySlotIdentities.insert(identity)
      }

      wireHeightInvalidation(for: view, identity: identity)

      if let thoughtView = view as? InkThoughtBlockView {
        thoughtView.onToggleCollapse = { [weak self] collapsed in
          onThoughtCollapseChanged?(index, collapsed)
          self?.updateReservedHeightSlot(identity: identity, view: thoughtView)
        }
      }

      if view.superview !== self {
        addSubview(view)
      }

      newBlockViews.append(view)
      newIdentities.append(identity)
      newIdentityMap[identity] = view
    }

    let removedIdentities = Set(contentFingerprints.keys).subtracting(newFingerprints.keys)
    for identity in removedIdentities {
      slotCache = slotCache.filter { $0.key.identity != identity }
    }
    for identity in dirtySlotIdentities {
      invalidateMeasurementSlot(identity: identity)
    }

    let removedViews = Set(blockViews).subtracting(newBlockViews)
    for view in removedViews {
      view.removeFromSuperview()
    }

    blockViews = newBlockViews
    blockIdentities = newIdentities
    identityToView = newIdentityMap
    contentFingerprints = newFingerprints

    applyRenderEnvironmentTraits(from: configuration)

    if configurationChanged || !removedIdentities.isEmpty || !dirtySlotIdentities.isEmpty {
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }

  override func invalidateIntrinsicContentSize() {
    if isInsideLayoutSubviews {
      layoutSubviewsICSInvalidateCount += 1
    }
    super.invalidateIntrinsicContentSize()
  }

  override var intrinsicContentSize: CGSize {
    let width = resolvedWidth
    guard width > 0 else {
      return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    let height = measureContent(for: width)
    return CGSize(width: UIView.noIntrinsicMetric, height: height)
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let width = size.width > 0 ? size.width : resolvedWidth
    guard width > 0 else { return .zero }
    let height = measureContent(for: width)
    return CGSize(width: width, height: height)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let width = bounds.width
    guard width > 0 else { return }

    isInsideLayoutSubviews = true
    defer { isInsideLayoutSubviews = false }

    var y: CGFloat = 0
    for entry in layoutEntries {
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

  @discardableResult
  private func measureContent(for width: CGFloat) -> CGFloat {
    guard width > 0 else { return 0 }

    if abs(lastMeasuredWidth - width) > 0.1 {
      slotCache = slotCache.filter { $0.key.widthBits == UInt64(width.bitPattern) }
      lastMeasuredWidth = width
    }

    blockMeasurementInvocationCount = 0
    var entries: [LayoutEntry] = []
    var total: CGFloat = 0

    for (identity, view) in orderedMeasureTargets() {
      let key = MeasurementCacheKey(identity: identity, widthBits: UInt64(width.bitPattern))
      let size: CGSize
      if let cached = slotCache[key] {
        size = cached
      } else {
        blockMeasurementInvocationCount += 1
        size = view.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        slotCache[key] = size
      }
      entries.append(LayoutEntry(identity: identity, view: view, size: size))
      total += size.height
    }

    layoutEntries = entries
    cachedTotalHeightForTesting = total
    return total
  }

  private func orderedMeasureTargets() -> [(InkBlockIdentity, UIView)] {
    var targets: [(InkBlockIdentity, UIView)] = []
    if let identity = streamThoughtIdentity, let view = streamThoughtView {
      targets.append((identity, view))
    }
    if let identity = streamTextIdentity, let view = streamTextView {
      targets.append((identity, view))
    }
    for (identity, view) in zip(blockIdentities, blockViews) {
      targets.append((identity, view))
    }
    return targets
  }

  private func wireHeightInvalidation(for view: UIView, identity: InkBlockIdentity) {
    if let imageView = view as? InkImageBlockView {
      imageView.onReservedHeightChanged = { [weak self, weak imageView] in
        guard let self, let imageView else { return }
        self.updateReservedHeightSlot(identity: identity, view: imageView)
      }
    }
    if let thoughtView = view as? InkThoughtBlockView {
      thoughtView.onReservedHeightChanged = { [weak self, weak thoughtView] in
        guard let self, let thoughtView else { return }
        self.updateReservedHeightSlot(identity: identity, view: thoughtView)
      }
    }
  }

  private func applyRenderEnvironmentTraits(from configuration: InkConfiguration) {
    let environment = configuration.renderEnvironment
    var traits: [UITraitCollection] = []
    if environment.userInterfaceStyle != .unspecified {
      traits.append(UITraitCollection(userInterfaceStyle: environment.userInterfaceStyle))
    }
    if environment.contentSizeCategory != .unspecified {
      traits.append(UITraitCollection(preferredContentSizeCategory: environment.contentSizeCategory))
    }
    appliedEnvironmentTraits = traits.isEmpty ? nil : UITraitCollection(traitsFrom: traits)

    if environment != lastAppliedRenderEnvironment {
      lastAppliedRenderEnvironment = environment
      if !traits.isEmpty {
        invalidateAllMeasurementSlots()
        setNeedsLayout()
      }
    }
  }
}
