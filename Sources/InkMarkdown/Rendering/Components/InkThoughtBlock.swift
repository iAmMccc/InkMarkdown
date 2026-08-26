//
//  InkThoughtBlock.swift
//  InkMarkdown
//

import UIKit

/// 思考过程（`<think>...</think>` / `<thought>...</thought>`）Block：展示为可折叠/展开的深度思考卡片。
public struct InkThoughtBlock: InkRenderableBlock {
  /// 思考过程的 Markdown 源码。
  public let thought: String
  /// 思考过程是否已结束（影响标题文案与指示器）。
  public let isComplete: Bool
  /// 样式配置。
  public var config: InkAppearance.Thought
  /// 整体渲染配置（用于递归渲染思考块内部的行内语法/代码/链接等）。
  public var renderConfiguration: InkConfiguration
  /// 用户折叠态（SSOT）；仅当 `config.isCollapsible == true` 时生效。
  public var isCollapsed: Bool

  public init(
    thought: String,
    isComplete: Bool = true,
    config: InkAppearance.Thought = InkAppearance.shared.thought,
    renderConfiguration: InkConfiguration = .standard,
    isCollapsed: Bool? = nil
  ) {
    self.thought = thought
    self.isComplete = isComplete
    self.config = config
    self.renderConfiguration = renderConfiguration
    self.isCollapsed = isCollapsed ?? (config.isCollapsible && config.isInitiallyCollapsed)
  }

  public func makeView() -> UIView {
    InkThoughtBlockView(
      thought: thought,
      isComplete: isComplete,
      config: config,
      renderConfiguration: renderConfiguration,
      isCollapsed: isCollapsed
    )
  }
}

// MARK: - 思考卡片原生视图

/// 原生可折叠思考过程卡片视图。
public final class InkThoughtBlockView: UIView {

  public private(set) var thought: String
  public private(set) var isComplete: Bool
  public private(set) var config: InkAppearance.Thought
  public private(set) var renderConfiguration: InkConfiguration

  public private(set) var isCollapsed: Bool
  public var onToggleCollapse: ((Bool) -> Void)?

  private let container = UIView()
  public let headerContainer = UIControl()
  private let iconImageView = UIImageView()
  private let titleLabel = UILabel()
  private let chevronImageView = UIImageView()
  private let bodyContainer = UIView()
  private let bodyTextView: UIView

  public init(
    thought: String,
    isComplete: Bool = true,
    config: InkAppearance.Thought = InkAppearance.shared.thought,
    renderConfiguration: InkConfiguration = .standard,
    isCollapsed: Bool? = nil,
    onToggleCollapse: ((Bool) -> Void)? = nil
  ) {
    self.thought = thought
    self.isComplete = isComplete
    self.config = config
    self.renderConfiguration = renderConfiguration
    // 归一化状态模型：非折叠卡片严格不可处于折叠态
    let resolvedCollapsed = isCollapsed ?? (config.isCollapsible && config.isInitiallyCollapsed)
    self.isCollapsed = config.isCollapsible ? resolvedCollapsed : false
    self.onToggleCollapse = onToggleCollapse

    // 针对思考块定制内部渲染配置并复用统一 TextKit 宿主体系
    var innerConfig = renderConfiguration
    innerConfig.appearance.text.fontSize = config.fontSize
    innerConfig.appearance.text.lineHeight = config.lineHeight
    innerConfig.appearance.text.color = config.textColor
    innerConfig.appearance.text.paragraphSpacing = 6

    let attributedThought = InkAttributedRenderer.render(
      thought.trimmingCharacters(in: .whitespacesAndNewlines),
      configuration: innerConfig
    )
    let attributedBlock = InkAttributedTextBlock(
      attributedText: attributedThought,
      insets: .zero,
      linkTapHandler: renderConfiguration.linkTapHandler
    )
    self.bodyTextView = attributedBlock.makeView()

    super.init(frame: .zero)
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
    if config.isCollapsible {
      headerContainer.addTarget(self, action: #selector(handleHeaderTap), for: .touchUpInside)
    }
    container.addSubview(headerContainer)

    // 可访问性配置
    headerContainer.isAccessibilityElement = true
    headerContainer.accessibilityTraits = config.isCollapsible ? [.button] : [.header]
    headerContainer.accessibilityLabel = isComplete ? config.completedTitle : config.title
    updateAccessibility()

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
    titleLabel.font = .systemFont(ofSize: config.headerFontSize, weight: .medium)
    titleLabel.textColor = config.headerColor
    titleLabel.text = isComplete ? config.completedTitle : config.title
    headerContainer.addSubview(titleLabel)

    // 折叠箭头
    if config.isCollapsible {
      chevronImageView.contentMode = .scaleAspectFit
      chevronImageView.tintColor = config.headerColor
      let configSym = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
      chevronImageView.image = UIImage(systemName: "chevron.right", withConfiguration: configSym)
      chevronImageView.transform = isCollapsed ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
      headerContainer.addSubview(chevronImageView)
    }

    // 正文区域
    bodyContainer.backgroundColor = .clear
    bodyContainer.isHidden = isCollapsed
    container.addSubview(bodyContainer)

    bodyContainer.addSubview(bodyTextView)
  }

  private func updateAccessibility() {
    guard config.isCollapsible else {
      headerContainer.accessibilityValue = nil
      headerContainer.accessibilityHint = nil
      return
    }
    headerContainer.accessibilityValue = isCollapsed ? "已折叠" : "已展开"
    headerContainer.accessibilityHint = isCollapsed ? "连按两次展开思考过程" : "连按两次折叠思考过程"
  }

  @objc public func handleHeaderTap() {
    guard config.isCollapsible else { return }
    isCollapsed.toggle()
    updateAccessibility()
    onToggleCollapse?(isCollapsed)

    UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
      self.chevronImageView.transform = self.isCollapsed ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
      self.bodyContainer.isHidden = self.isCollapsed
      self.bodyContainer.alpha = self.isCollapsed ? 0 : 1
      self.invalidateIntrinsicContentSize()
      self.superview?.invalidateIntrinsicContentSize()
      self.superview?.setNeedsLayout()
      self.superview?.layoutIfNeeded()
    } completion: { _ in
      UIAccessibility.post(
        notification: .announcement,
        argument: self.isCollapsed ? "已折叠思考过程" : "已展开思考过程"
      )
    }
  }

  /// 流式/终态切换时原地更新思考正文、标题与配置，**不**重置 `isCollapsed`。
  public func apply(
    thought: String,
    isComplete: Bool,
    isCollapsed: Bool? = nil,
    config: InkAppearance.Thought? = nil,
    renderConfiguration: InkConfiguration? = nil
  ) {
    self.thought = thought
    self.isComplete = isComplete
    if let config {
      self.config = config
      container.backgroundColor = config.backgroundColor
      container.layer.cornerRadius = config.cornerRadius
      iconImageView.tintColor = config.headerColor
      titleLabel.font = .systemFont(ofSize: config.headerFontSize, weight: .medium)
      titleLabel.textColor = config.headerColor
      chevronImageView.tintColor = config.headerColor
    }
    if let renderConfiguration {
      self.renderConfiguration = renderConfiguration
    }

    if let isCollapsed, self.config.isCollapsible {
      self.isCollapsed = isCollapsed
      bodyContainer.isHidden = self.isCollapsed
      bodyContainer.alpha = self.isCollapsed ? 0 : 1
      chevronImageView.transform = self.isCollapsed ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
    }

    titleLabel.text = isComplete ? self.config.completedTitle : self.config.title
    headerContainer.accessibilityLabel = isComplete ? self.config.completedTitle : self.config.title
    updateAccessibility()

    var innerConfig = self.renderConfiguration
    innerConfig.appearance.text.fontSize = self.config.fontSize
    innerConfig.appearance.text.lineHeight = self.config.lineHeight
    innerConfig.appearance.text.color = self.config.textColor
    innerConfig.appearance.text.paragraphSpacing = 6

    let attributedThought = InkAttributedRenderer.render(
      thought.trimmingCharacters(in: .whitespacesAndNewlines),
      configuration: innerConfig
    )

    if let textView = bodyTextView as? UITextView {
      textView.textStorage.setAttributedString(attributedThought)
      if let layoutManager = textView.textContainer.layoutManager {
        InkImageAttachment.bindAttachments(in: textView.textStorage, layoutManager: layoutManager)
      }
    }

    invalidateIntrinsicContentSize()
    setNeedsLayout()
  }

  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let targetWidth = size.width > 0 ? size.width : (bounds.width > 0 ? bounds.width : 320)
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
