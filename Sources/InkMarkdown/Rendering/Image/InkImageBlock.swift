import UIKit

/// 块级图片通道：独占成行的图片以 `UIView` 渲染，并符合 ``InkRenderableBlock``。
///
/// 通过 ``configure(containerWidth:loader:)`` 绑定容器宽度后向 ``InkImageStore`` 解析；
/// Store 观察与过期结果抑制由 ``InkImagePresentationLoad`` 负责。
///
/// 须在主线程使用：内部依赖 ``InkImageStore``（``@MainActor``）。
///
/// - Note: v0.0.1 起即为 ``UIView`` 子类；``makeView()`` 返回 `self` 供 adapter 挂载。
public final class InkImageBlock: UIView, InkRenderableBlock, InkReusableBlock {
  /// 图片源（URL、Bundle、generated 等）。
  public let source: ImageSource
  /// 保留高度变化时通知宿主 adapter；由 SwiftUI/UIKit adapter 绑定，非公开渲染契约。
  public var onReservedHeightChanged: (() -> Void)?

  private let store: InkImageStore
  private let rendering: InkImageRendering
  private var lastReservedHeight: CGFloat = -1
  private let presentationLoad = InkImagePresentationLoad()
  private var isConfigured = false
  private var configuredMaxWidth: CGFloat = 0
  private var failureContentView: UIView?
  private var cachedFailureContentHeight: CGFloat = 0
  private var isShowingLoadingPlaceholder = false

  private let imageView: UIImageView
  private let placeholderView: UIView

  /// 创建块级图片视图（块 handler 与默认 ``makeView()`` 路径）。
  ///
  /// - Parameters:
  ///   - source: 图片源。
  ///   - rendering: 图片渲染配置；须已按需开启 ``InkImageRendering/isEnabled``。
  /// - Note: Block 路由在 UIKit 主线程调用；须在主线程构造。
  @MainActor
  public convenience init(source: ImageSource, rendering: InkImageRendering) {
    self.init(
      source: source,
      resolvedStore: InkImageStore.defaultStore(for: rendering),
      rendering: rendering
    )
  }

  /// 0.0.1 兼容初始化器：显式注入 ``InkImageStore``。
  ///
  /// - Parameters:
  ///   - source: 图片源。
  ///   - store: 图片加载与缓存 Store。
  ///   - rendering: 图片渲染配置。
  @available(*, deprecated, renamed: "init(source:rendering:)", message: "请改用 init(source:rendering:)；默认 Store 按 rendering.storeConfiguration 隔离。")
  @MainActor
  public convenience init(source: ImageSource, store: InkImageStore, rendering: InkImageRendering) {
    self.init(source: source, resolvedStore: store, rendering: rendering)
  }

  /// 模块内部的显式 Store 注入 seam；用于确定性测试与内部集成。
  @MainActor
  convenience init(source: ImageSource, rendering: InkImageRendering, store: InkImageStore) {
    self.init(source: source, resolvedStore: store, rendering: rendering)
  }

  @MainActor
  private init(source: ImageSource, resolvedStore store: InkImageStore, rendering: InkImageRendering) {
    self.source = source
    self.store = store
    self.rendering = rendering
    self.imageView = UIImageView()
    self.placeholderView = UIView()
    super.init(frame: .zero)
    setupViews()
  }

  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @MainActor
  public func makeView() -> UIView {
    setNeedsLayout()
    return self
  }

  @MainActor
  public func updateExistingView(_ view: UIView) -> Bool {
    false
  }

  @MainActor
  public func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    guard let previous = previous as? InkImageBlock else { return false }
    return source == previous.source
      && rendering == previous.rendering
      && store === previous.store
  }

  private func setupViews() {
    imageView.contentMode = .scaleAspectFit
    imageView.clipsToBounds = true
    placeholderView.backgroundColor = UIColor.systemGray5
    placeholderView.layer.cornerRadius = 8
    addSubview(placeholderView)
    addSubview(imageView)
    imageView.isHidden = true
    placeholderView.isHidden = true
    setupTapHandlingIfNeeded()
  }

  private func setupTapHandlingIfNeeded() {
    guard rendering.tapAction != .none else { return }
    isUserInteractionEnabled = true
    isAccessibilityElement = true
    accessibilityTraits.insert(.button)
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
    addGestureRecognizer(tap)
  }

  @objc
  private func handleImageTap() {
    handleConfiguredTap()
  }

  /// 分发 ``InkImageRendering/tapAction``（手势与测试共用）。
  @MainActor
  func handleConfiguredTap() {
    switch rendering.tapAction {
    case .none:
      break
    case .callback:
      rendering.onImageTap?(source, imageView.image)
    case .openURL:
      rendering.onImageTap?(source, imageView.image)
      openImageURLIfPossible()
    }
  }

  @MainActor
  private func openImageURLIfPossible() {
    switch source.scheme {
    case .http, .https, .file:
      UIApplication.shared.open(source.rawURL)
    case .data, .asset, .bundle, .relative, .generated, .unknown:
      break
    }
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    guard bounds.width > 0 else { return }

    imageView.frame = bounds
    if let failure = failureContentView {
      failure.frame = bounds
    }

    // D3：SSE 复用宿主时容器宽度会变；错宽下栅格化的位图被拉伸会糊化，允许按新宽度重配。
    if isConfigured, abs(bounds.width - configuredMaxWidth) > 1 {
      isConfigured = false
    }
    if !isConfigured {
      configureIfNeeded()
    }
  }

  @MainActor
  private func configureIfNeeded() {
    let loader = store.loader(for: rendering, source: source)
    configure(containerWidth: bounds.width, loader: loader)
  }

  /// 按容器宽度配置尺寸并向 Store 发起解析。
  ///
  /// - Parameters:
  ///   - containerWidth: 宿主容器可用宽度（pt）。
  ///   - loader: 实际执行解码的加载器。
  @MainActor
  public func configure(containerWidth: CGFloat, loader: InkImageLoading) {
    isConfigured = true

    let effectiveWidth = min(containerWidth, rendering.sizing.maxBlockImageWidth ?? containerWidth)
    configuredMaxWidth = containerWidth
    let scale = InkDisplayMetrics.resolve(for: self).scale
    let display = DisplayContext(
      maxPixelWidth: effectiveWidth * scale,
      scale: scale,
      contentMode: .fit
    )

    presentationLoad.start(
      source: source,
      display: display,
      loader: loader,
      store: store,
      onPending: { [weak self] in
        self?.showPlaceholder(maxWidth: effectiveWidth)
      },
      onCompletion: { [weak self] completion in
        guard let self else { return }
        switch completion {
        case .image(let image):
          self.showImage(image, maxWidth: effectiveWidth)
        case .loadFailed, .rejected:
          self.showError()
        }
      }
    )
  }

  @MainActor
  private func showImage(_ img: UIImage, maxWidth: CGFloat) {
    clearFailureContent()
    isShowingLoadingPlaceholder = false
    placeholderView.isHidden = true
    imageView.isHidden = false
    imageView.image = img
    notifyReservedHeightChangedIfNeeded(maxWidth: maxWidth)
    setNeedsLayout()
    rendering.onLoadFinished?(source, img)
  }

  private func notifyReservedHeightChangedIfNeeded(maxWidth: CGFloat? = nil) {
    let width = maxWidth ?? resolvedMaxWidth()
    let height = sizeThatFits(CGSize(width: max(width, 1), height: .greatestFiniteMagnitude)).height
    guard abs(height - lastReservedHeight) > 0.5 else { return }
    lastReservedHeight = height
    onReservedHeightChanged?()
  }

  private func showPlaceholder(maxWidth: CGFloat) {
    clearFailureContent()
    isShowingLoadingPlaceholder = true
    placeholderView.frame = CGRect(
      x: 0,
      y: 0,
      width: maxWidth,
      height: rendering.placeholderHeight
    )
    placeholderView.isHidden = false
    imageView.isHidden = true
    notifyReservedHeightChangedIfNeeded(maxWidth: maxWidth)
  }

  private func showError() {
    showFailureFallback(maxWidth: resolvedMaxWidth())
    rendering.onLoadFinished?(source, nil)
  }

  private func resolvedMaxWidth() -> CGFloat {
    if configuredMaxWidth > 0 { return configuredMaxWidth }
    if bounds.width > 0 { return bounds.width }
    return max(rendering.sizing.maxBlockImageWidth ?? 0, 1)
  }

  private func clearFailureContent() {
    failureContentView?.removeFromSuperview()
    failureContentView = nil
    cachedFailureContentHeight = 0
  }

  private func showFailureFallback(maxWidth: CGFloat) {
    clearFailureContent()
    isShowingLoadingPlaceholder = false
    imageView.isHidden = true
    placeholderView.isHidden = true

    guard let fallback = rendering.failureFallback else {
      installFailureContentView(makeCompactFailureLabel(), maxWidth: maxWidth)
      return
    }

    switch fallback {
    case .sourceCode(let code, let language):
      let view = InkCodeBlockViewFactory.makeView(
        code: code,
        language: language,
        config: rendering.failureCodeBlockStyle,
        appearance: InkAppearance.shared
      )
      installFailureContentView(view, maxWidth: maxWidth)
    }
  }

  private func installFailureContentView(_ view: UIView, maxWidth: CGFloat) {
    addSubview(view)
    failureContentView = view
    relayoutFailureContent(maxWidth: maxWidth)
  }

  private func relayoutFailureContent(maxWidth: CGFloat) {
    guard let failureContentView else { return }
    let height = measuredFailureContentHeight(maxWidth: maxWidth)
    cachedFailureContentHeight = height
    failureContentView.frame = CGRect(x: 0, y: 0, width: maxWidth, height: height)
    notifyReservedHeightChangedIfNeeded(maxWidth: maxWidth)
    setNeedsLayout()
  }

  private func makeCompactFailureLabel() -> UILabel {
    let label = UILabel()
    label.adjustsFontForContentSizeCategory = true
    label.numberOfLines = 0
    label.font = UIFont.systemFont(ofSize: UIFont.labelFontSize)
    label.textColor = UIColor.secondaryLabel
    label.text = "[\u{1F5BC} image]"
    return label
  }

  private func measuredFailureContentHeight(maxWidth: CGFloat) -> CGFloat {
    guard let failureContentView else { return inlineUnresolvedAttachmentHeight() }
    let savedFrame = failureContentView.frame
    failureContentView.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: 0)
    failureContentView.setNeedsLayout()
    failureContentView.layoutIfNeeded()
    let height = failureContentView.systemLayoutSizeFitting(
      CGSize(width: maxWidth, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
    failureContentView.frame = savedFrame
    return max(1, height)
  }

  private func updateFrameForFailureContent(maxWidth: CGFloat) {
    relayoutFailureContent(maxWidth: maxWidth)
  }

  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let width = size.width > 0 ? size.width : resolvedMaxWidth()
    if failureContentView != nil {
      let height = cachedFailureContentHeight > 0 ? cachedFailureContentHeight : measuredFailureContentHeight(maxWidth: width)
      return CGSize(width: width, height: height)
    }
    if let img = imageView.image {
      let desiredWidth = min(width, rendering.sizing.maxBlockImageWidth ?? img.size.width)
      let fitSize = fitted(
        img.size,
        maxWidth: max(width, 1),
        upscales: rendering.sizing.upscalesSmallImages,
        minPlaceholder: rendering.placeholderHeight,
        maxHeight: rendering.sizing.maxImageHeight
      )
      return CGSize(width: desiredWidth, height: fitSize.height)
    }
    if isShowingLoadingPlaceholder {
      return CGSize(width: width, height: rendering.placeholderHeight)
    }
    return CGSize(width: width, height: 0)
  }

  public override var intrinsicContentSize: CGSize {
    if failureContentView != nil {
      let maxWidth = resolvedMaxWidth()
      if maxWidth > 0, cachedFailureContentHeight > 0 {
        return CGSize(width: UIView.noIntrinsicMetric, height: cachedFailureContentHeight)
      }
    }
    if let img = imageView.image {
      let desiredWidth = rendering.sizing.maxBlockImageWidth ?? img.size.width
      let actualWidth = bounds.width > 0 ? bounds.width : desiredWidth
      let fitSize = fitted(
        img.size,
        maxWidth: max(actualWidth, 1),
        upscales: rendering.sizing.upscalesSmallImages,
        minPlaceholder: rendering.placeholderHeight,
        maxHeight: rendering.sizing.maxImageHeight
      )
      return CGSize(width: desiredWidth, height: fitSize.height)
    }
    if isShowingLoadingPlaceholder {
      return CGSize(width: UIView.noIntrinsicMetric, height: rendering.placeholderHeight)
    }
    return CGSize(width: UIView.noIntrinsicMetric, height: 0)
  }

  /// 取消订阅并重置为占位态，供列表复用。
  @MainActor
  public func prepareForReuse() {
    presentationLoad.cancel()
    isConfigured = false
    configuredMaxWidth = 0
    imageView.image = nil
    imageView.isHidden = true
    clearFailureContent()
    isShowingLoadingPlaceholder = false
    placeholderView.isHidden = true
  }
}

/// 0.0.1 类型名兼容别名；请改用 ``InkImageBlock``。
@available(*, deprecated, renamed: "InkImageBlock", message: "请改用 InkImageBlock。")
public typealias InkImageBlockView = InkImageBlock
