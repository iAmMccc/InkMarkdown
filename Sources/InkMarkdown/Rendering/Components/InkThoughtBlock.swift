//
//  InkThoughtBlock.swift
//  InkMarkdown
//

import UIKit

/// Thought 正文在 String → Markup 边界上的预处理阶段。
fileprivate enum InkThoughtSource: Equatable {
  case raw(String)
  case prepared(InkPreparedMarkdownSource)

  var value: String {
    switch self {
    case .raw(let value):
      return value
    case .prepared(let source):
      return source.value
    }
  }

  func render(configuration: InkConfiguration) -> NSAttributedString {
    switch self {
    case .raw(let value):
      return InkAttributedRenderer.render(
        value.trimmingCharacters(in: .whitespacesAndNewlines),
        configuration: configuration
      )
    case .prepared(let source):
      return InkAttributedRenderer.render(
        preparedSource: source.trimmingCharacters(in: .whitespacesAndNewlines),
        configuration: configuration
      )
    }
  }
}

/// 思考过程（`<think>...</think>` / `<thought>...</thought>`）Block：展示为可折叠/展开的深度思考卡片。
public struct InkThoughtBlock: InkRenderableBlock, InkReusableBlock {
  private let source: InkThoughtSource

  /// 思考过程的 Markdown 源码。
  public var thought: String { source.value }
  /// 思考过程是否已结束（影响标题文案与指示器）。
  public let isComplete: Bool
  /// 样式配置。
  public var config: InkAppearance.Thought
  /// 整体渲染配置（用于递归渲染思考块内部的行内语法/代码/链接等）。
  public var renderConfiguration: InkConfiguration
  /// 初始或调用方提供的状态；同一呈现周期内的 live state 由 SwiftUI continuity module 持有。
  public var isCollapsed: Bool

  /// 使用全局 Thought 样式和标准渲染配置创建思考块。
  ///
  /// `isCollapsed` 为 `nil` 时遵循当前样式的初始折叠配置；生成视图时会把
  /// 不可折叠样式归一化为展开状态。
  @MainActor
  public init(
    thought: String,
    isComplete: Bool = true,
    isCollapsed: Bool? = nil
  ) {
    self.init(thought: thought, isComplete: isComplete, config: InkAppearance.shared.thought, renderConfiguration: .standard, isCollapsed: isCollapsed)
  }

  /// 使用显式样式与渲染配置创建思考块。
  ///
  /// 调用方负责传入与外层渲染一致的配置，使内部 Markdown 共享扩展和链接语义。
  public init(
    thought: String,
    isComplete: Bool = true,
    config: InkAppearance.Thought,
    renderConfiguration: InkConfiguration,
    isCollapsed: Bool? = nil
  ) {
    self.init(
      source: .raw(thought),
      isComplete: isComplete,
      config: config,
      renderConfiguration: renderConfiguration,
      isCollapsed: isCollapsed
    )
  }

  init(
    preparedThought: InkPreparedMarkdownSource,
    isComplete: Bool,
    config: InkAppearance.Thought,
    renderConfiguration: InkConfiguration,
    isCollapsed: Bool?
  ) {
    self.init(
      source: .prepared(preparedThought),
      isComplete: isComplete,
      config: config,
      renderConfiguration: renderConfiguration,
      isCollapsed: isCollapsed
    )
  }

  private init(
    source: InkThoughtSource,
    isComplete: Bool,
    config: InkAppearance.Thought,
    renderConfiguration: InkConfiguration,
    isCollapsed: Bool?
  ) {
    self.source = source
    self.isComplete = isComplete
    self.config = config
    self.renderConfiguration = renderConfiguration
    self.isCollapsed = isCollapsed ?? (config.isCollapsible && config.isInitiallyCollapsed)
  }

  /// 创建承载当前思考内容和交互状态的 UIKit 视图。
  @MainActor public func makeView() -> UIView {
    return InkThoughtBlockView(
      source: source,
      isComplete: isComplete,
      config: config,
      renderConfiguration: renderConfiguration,
      isCollapsed: isCollapsed,
      onToggleCollapse: nil
    )
  }

  /// 尝试把当前完整呈现状态应用到既有 Thought 视图。
  ///
  /// 仅接受 ``InkThoughtBlockView``；类型不匹配时返回 `false`，由调用方安全重建。
  @MainActor
  public func updateExistingView(_ view: UIView) -> Bool {
    guard let thoughtView = view as? InkThoughtBlockView else { return false }
    thoughtView.apply(
      source: source,
      isComplete: isComplete,
      isCollapsed: isCollapsed,
      config: config,
      renderConfiguration: renderConfiguration
    )
    return true
  }

  /// 比较正文、完成态、折叠态、样式和扩展语义是否等价。
  @MainActor
  public func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    guard let previous = previous as? InkThoughtBlock else { return false }
    return source == previous.source
      && isComplete == previous.isComplete
      && isCollapsed == previous.isCollapsed
      && config == previous.config
      && renderConfiguration.isSemanticallyEqualTo(previous.renderConfiguration)
  }
}

// MARK: - 思考卡片原生视图

/// 原生可折叠思考过程卡片视图。
public final class InkThoughtBlockView: UIView {

  /// 当前展示的 Thought Markdown 源码。
  public private(set) var thought: String
  /// 当前 Thought 是否已经结束。
  public private(set) var isComplete: Bool
  /// 当前卡片样式快照。
  public private(set) var config: InkAppearance.Thought
  /// 渲染 Thought 正文时使用的完整配置。
  public private(set) var renderConfiguration: InkConfiguration

  /// 当前正文是否折叠；不可折叠配置下始终为 `false`。
  public private(set) var isCollapsed: Bool
  /// 用户切换折叠状态后的回调，参数为切换后的状态。
  public var onToggleCollapse: ((Bool) -> Void)?
  /// 内容保留高度发生变化时通知宿主 adapter 重新测量。
  ///
  /// 该回调用于承载层协调布局，不替代 ``onToggleCollapse`` 的交互语义。
  public var onReservedHeightChanged: (() -> Void)?

  private var lastNotifiedHeight: CGFloat = 0

  private let container = UIView()
  /// 承载标题、折叠交互与 VoiceOver 语义的头部控件。
  public let headerContainer = UIControl()
  private let iconImageView = UIImageView()
  private let titleLabel = UILabel()
  private let chevronImageView = UIImageView()
  private let bodyContainer = UIView()
  private let bodyTextView: UIView

  /// 创建可复用 Thought 卡片视图。
  ///
  /// 不可折叠配置会忽略传入的折叠态并保持正文可见。
  public convenience init(
    thought: String,
    isComplete: Bool = true,
    config: InkAppearance.Thought = InkAppearance.shared.thought,
    renderConfiguration: InkConfiguration = .standard,
    isCollapsed: Bool? = nil,
    onToggleCollapse: ((Bool) -> Void)? = nil
  ) {
    self.init(
      source: .raw(thought),
      isComplete: isComplete,
      config: config,
      renderConfiguration: renderConfiguration,
      isCollapsed: isCollapsed,
      onToggleCollapse: onToggleCollapse
    )
  }

  fileprivate init(
    source: InkThoughtSource,
    isComplete: Bool,
    config: InkAppearance.Thought,
    renderConfiguration: InkConfiguration,
    isCollapsed: Bool?,
    onToggleCollapse: ((Bool) -> Void)?
  ) {
    self.thought = source.value
    self.isComplete = isComplete
    self.config = config
    self.renderConfiguration = renderConfiguration
    // 归一化状态模型：非折叠卡片严格不可处于折叠态
    let resolvedCollapsed = isCollapsed ?? (config.isCollapsible && config.isInitiallyCollapsed)
    self.isCollapsed = config.isCollapsible ? resolvedCollapsed : false
    self.onToggleCollapse = onToggleCollapse

    let attributedThought = Self.renderThought(
      source: source,
      config: config,
      renderConfiguration: renderConfiguration
    )
    let attributedBlock = InkAttributedTextBlock(
      attributedText: attributedThought,
      insets: .zero,
      linkTapHandler: renderConfiguration.linkTapHandler,
      linkTapSemanticIdentity: renderConfiguration.linkTapSemanticIdentityForBlockReuse
    )
    self.bodyTextView = attributedBlock.makeView()

    super.init(frame: .zero)
    (bodyTextView as? InkAttributedBlockTextView)?.onInlineImageHeightChange = { [weak self] in
      guard let self else { return }
      self.invalidateIntrinsicContentSize()
      self.setNeedsLayout()
      self.notifyReservedHeightIfNeeded()
    }
    setupUI()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    backgroundColor = .clear

    container.backgroundColor = config.backgroundColor
    container.layer.cornerRadius = config.cornerRadius
    container.layer.cornerCurve = .continuous
    container.clipsToBounds = true
    addSubview(container)

    // 头部区域（点击触发折叠）
    headerContainer.backgroundColor = .clear
    container.addSubview(headerContainer)

    // 可访问性配置
    headerContainer.isAccessibilityElement = true
    headerContainer.accessibilityLabel = isComplete ? config.completedTitle : config.title

    // 图标
    iconImageView.contentMode = .scaleAspectFit
    iconImageView.tintColor = config.headerColor
    if #available(iOS 16.0, *), let image = UIImage(systemName: "brain.head.profile") {
      iconImageView.image = image
    } else if let image = UIImage(systemName: "lightbulb.fill") ?? UIImage(systemName: "sparkles") {
      iconImageView.image = image
    }
    headerContainer.addSubview(iconImageView)

    // 标题
    titleLabel.font = renderConfiguration.appearance.scaledFont(
      .systemFont(ofSize: config.headerFontSize, weight: .medium),
      textStyle: .body,
      compatibleWith: renderConfiguration.renderEnvironment.traitCollection
    )
    titleLabel.textColor = config.headerColor
    titleLabel.text = isComplete ? config.completedTitle : config.title
    headerContainer.addSubview(titleLabel)

    syncCollapsibility()
    updateAccessibility()

    // 正文区域
    bodyContainer.backgroundColor = .clear
    container.addSubview(bodyContainer)

    bodyContainer.addSubview(bodyTextView)
  }

  private func syncCollapsibility() {
    headerContainer.removeTarget(self, action: #selector(handleHeaderTap), for: .touchUpInside)

    if config.isCollapsible {
      headerContainer.addTarget(self, action: #selector(handleHeaderTap), for: .touchUpInside)
      chevronImageView.contentMode = .scaleAspectFit
      chevronImageView.tintColor = config.headerColor
      let configSym = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
      chevronImageView.image = UIImage(systemName: "chevron.right", withConfiguration: configSym)
      if chevronImageView.superview == nil {
        headerContainer.addSubview(chevronImageView)
      }
    } else {
      chevronImageView.removeFromSuperview()
    }
    syncCollapsedVisualState()
  }

  private func syncCollapsedVisualState() {
    chevronImageView.transform = isCollapsed ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
    bodyContainer.isHidden = isCollapsed
    bodyContainer.alpha = isCollapsed ? 0 : 1
  }

  private func updateAccessibility() {
    headerContainer.accessibilityTraits = config.isCollapsible ? [.button] : [.header]
    guard config.isCollapsible else {
      headerContainer.accessibilityValue = nil
      headerContainer.accessibilityHint = nil
      return
    }
    headerContainer.accessibilityValue = isCollapsed ? "已折叠" : "已展开"
    headerContainer.accessibilityHint = isCollapsed ? "连按两次展开思考过程" : "连按两次折叠思考过程"
  }

  /// 处理头部激活事件；不可折叠配置下不产生状态变化或回调。
  @objc public func handleHeaderTap() {
    guard config.isCollapsible else { return }
    isCollapsed.toggle()
    updateAccessibility()
    onToggleCollapse?(isCollapsed)

    UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
      self.syncCollapsedVisualState()
    } completion: { _ in
      self.notifyReservedHeightIfNeeded()
      UIAccessibility.post(
        notification: .announcement,
        argument: self.isCollapsed ? "已折叠思考过程" : "已展开思考过程"
      )
    }
  }

  /// 流式更新、终态 promotion 或配置变化时原地更新卡片。
  ///
  /// 未显式传入折叠态且配置仍可折叠时保留 live state；切换为不可折叠时
  /// 归一化为展开，并同步 target、chevron、正文可见性和 VoiceOver 语义。
  public func apply(
    thought: String,
    isComplete: Bool,
    isCollapsed: Bool? = nil,
    config: InkAppearance.Thought? = nil,
    renderConfiguration: InkConfiguration? = nil
  ) {
    apply(
      source: .raw(thought),
      isComplete: isComplete,
      isCollapsed: isCollapsed,
      config: config,
      renderConfiguration: renderConfiguration
    )
  }

  fileprivate func apply(
    source: InkThoughtSource,
    isComplete: Bool,
    isCollapsed: Bool?,
    config: InkAppearance.Thought?,
    renderConfiguration: InkConfiguration?
  ) {
    self.thought = source.value
    self.isComplete = isComplete
    if let config {
      self.config = config
      container.backgroundColor = config.backgroundColor
      container.layer.cornerRadius = config.cornerRadius
      iconImageView.tintColor = config.headerColor
      titleLabel.font = (renderConfiguration ?? self.renderConfiguration).appearance.scaledFont(
        .systemFont(ofSize: config.headerFontSize, weight: .medium),
        textStyle: .body,
        compatibleWith: (renderConfiguration ?? self.renderConfiguration).renderEnvironment.traitCollection
      )
      titleLabel.textColor = config.headerColor
      chevronImageView.tintColor = config.headerColor
    }
    if let renderConfiguration {
      self.renderConfiguration = renderConfiguration
    }

    if let isCollapsed, self.config.isCollapsible {
      self.isCollapsed = isCollapsed
    } else if !self.config.isCollapsible {
      self.isCollapsed = false
    }
    syncCollapsibility()

    titleLabel.text = isComplete ? self.config.completedTitle : self.config.title
    headerContainer.accessibilityLabel = isComplete ? self.config.completedTitle : self.config.title
    updateAccessibility()

    let attributedThought = Self.renderThought(
      source: source,
      config: self.config,
      renderConfiguration: self.renderConfiguration
    )

    let attributedBlock = InkAttributedTextBlock(
      attributedText: attributedThought,
      insets: .zero,
      linkTapHandler: self.renderConfiguration.linkTapHandler,
      linkTapSemanticIdentity: self.renderConfiguration.linkTapSemanticIdentityForBlockReuse
    )
    _ = attributedBlock.updateExistingView(bodyTextView)

    invalidateIntrinsicContentSize()
    setNeedsLayout()
    notifyReservedHeightIfNeeded()
  }

  private static func renderThought(
    source: InkThoughtSource,
    config: InkAppearance.Thought,
    renderConfiguration: InkConfiguration
  ) -> NSAttributedString {
    var innerConfig = renderConfiguration
    innerConfig.appearance.text.fontSize = config.fontSize
    innerConfig.appearance.text.lineHeight = config.lineHeight
    innerConfig.appearance.text.color = config.textColor
    innerConfig.appearance.text.paragraphSpacing = 6

    return source.render(configuration: innerConfig)
  }

  private func notifyReservedHeightIfNeeded() {
    let width = bounds.width > 0 ? bounds.width : (superview?.bounds.width ?? 0)
    guard width > 0 else { return }
    let height = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    guard abs(height - lastNotifiedHeight) > 0.5 else { return }
    lastNotifiedHeight = height
    onReservedHeightChanged?()
  }

  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let targetWidth = InkDisplayMetrics.resolvedMeasurementWidth(
      proposal: size.width,
      bounds: bounds.width
    )
    guard targetWidth > 0 else {
      return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    let insets = config.insets
    let headerH = config.headerHeight

    if isCollapsed {
      let totalH = insets.top + headerH + insets.bottom + config.spacingAfter
      return CGSize(width: targetWidth, height: ceil(totalH))
    }

    let contentW = max(0, targetWidth - insets.left - insets.right)
    let bodySize = bodyTextView.sizeThatFits(CGSize(width: contentW, height: .greatestFiniteMagnitude))
    let totalH = insets.top + headerH + 6 + bodySize.height + insets.bottom + config.spacingAfter
    return CGSize(width: targetWidth, height: ceil(totalH))
  }

  public override var intrinsicContentSize: CGSize {
    sizeThatFits(CGSize(width: bounds.width > 0 ? bounds.width : UIView.noIntrinsicMetric, height: .greatestFiniteMagnitude))
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    let width = bounds.width
    let height = bounds.height
    guard width > 0, height > 0 else { return }

    let insets = config.insets
    let containerH = max(0, height - config.spacingAfter)
    container.frame = CGRect(x: 0, y: 0, width: width, height: containerH)

    let headerW = max(0, width - insets.left - insets.right)
    headerContainer.frame = CGRect(x: insets.left, y: insets.top, width: headerW, height: config.headerHeight)

    let iconSize: CGFloat = 16
    iconImageView.frame = CGRect(x: 0, y: (config.headerHeight - iconSize) / 2, width: iconSize, height: iconSize)

    let chevronSize: CGFloat = 12
    if config.isCollapsible {
      chevronImageView.frame = CGRect(x: headerW - chevronSize, y: (config.headerHeight - chevronSize) / 2, width: chevronSize, height: chevronSize)
      titleLabel.frame = CGRect(x: iconSize + 6, y: 0, width: headerW - iconSize - 6 - chevronSize - 4, height: config.headerHeight)
    } else {
      titleLabel.frame = CGRect(x: iconSize + 6, y: 0, width: headerW - iconSize - 6, height: config.headerHeight)
    }

    if !isCollapsed {
      let bodyY = insets.top + config.headerHeight + 6
      let bodyH = max(0, containerH - bodyY - insets.bottom)
      let bodyW = headerW
      bodyContainer.frame = CGRect(x: insets.left, y: bodyY, width: bodyW, height: bodyH)
      bodyTextView.frame = CGRect(x: 0, y: 0, width: bodyW, height: bodyH)
    }
  }
}
