import UIKit

/// 块级图片通道：独占成行的图片以 `UIView` 渲染，并符合 ``InkRenderableBlock``。
///
/// 通过 ``configure(containerWidth:loader:)`` 绑定容器宽度后向 ``InkImageStore`` 解析；
/// 使用 `loadToken` 丢弃过期的异步回调，避免复用或快速重配时错图。
///
/// 须在主线程使用：内部依赖 ``InkImageStore``（``@MainActor``）。
public final class InkImageBlock: UIView, InkRenderableBlock {

  /// 规范化后的图片来源。
  public let source: ImageSource

  private let store: InkImageStore
  private let rendering: InkImageRendering
  private var loadToken: UUID = UUID()
  private var subscription: InkImageStore.ImageLoadSubscription?
  private var isConfigured = false

  private let imageView: UIImageView = {
    let iv = UIImageView()
    iv.contentMode = .scaleAspectFit
    iv.clipsToBounds = true
    return iv
  }()

  private let placeholderView: UIView = {
    let v = UIView()
    v.backgroundColor = UIColor.systemGray5
    v.layer.cornerRadius = 8
    return v
  }()

  /// - Parameters:
  ///   - source: 图片来源。
  ///   - store: 图片状态管理器（可由外部注入，或传入 ``InkImageStore/shared``）。
  ///   - rendering: 图片渲染配置。
  public init(
    source: ImageSource,
    store: InkImageStore,
    rendering: InkImageRendering
  ) {
    self.source = source
    self.store = store
    self.rendering = rendering
    super.init(frame: .zero)
    setupViews()
  }

  /// 使用共享 Store 创建（须在主线程调用）。
  @MainActor
  public convenience init(source: ImageSource, rendering: InkImageRendering) {
    self.init(source: source, store: .shared, rendering: rendering)
  }

  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews() {
    addSubview(placeholderView)
    addSubview(imageView)
    imageView.isHidden = true
    placeholderView.frame = CGRect(
      x: 0,
      y: 0,
      width: bounds.width,
      height: rendering.placeholderHeight
    )
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    if bounds.width > 0, !isConfigured {
      configureIfNeeded()
    }
  }

  @MainActor
  private func configureIfNeeded() {
    store.prepareForRendering(rendering)
    let loader = store.loader(for: rendering)
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
    subscription?.cancel()
    store.prepareForRendering(rendering)
    let currentToken = UUID()
    loadToken = currentToken

    let effectiveWidth = min(containerWidth, rendering.sizing.maxBlockImageWidth ?? containerWidth)
    let scale = UIScreen.main.scale
    let display = DisplayContext(
      maxPixelWidth: effectiveWidth * scale,
      scale: scale,
      contentMode: .fit
    )

    placeholderView.frame = CGRect(
      x: 0,
      y: 0,
      width: effectiveWidth,
      height: rendering.placeholderHeight
    )

    let result = store.resolve(source: source, display: display, loader: loader)
    switch result {
    case .ready(let img):
      showImage(img, token: currentToken, maxWidth: effectiveWidth)
    case .loading(let subscribe):
      showPlaceholder()
      subscription = subscribe { [weak self] image in
        Task { @MainActor in
          guard let self else { return }
          if let image {
            self.showImage(image, token: currentToken, maxWidth: effectiveWidth)
          } else if currentToken == self.loadToken {
            self.showError()
          }
        }
      }
    case .queued(let subscribe):
      showPlaceholder()
      let token = loadToken
      subscription = subscribe { [weak self] image in
        Task { @MainActor in
          guard let self, self.loadToken == token else { return }
          if let image {
            self.showImage(image, token: token, maxWidth: effectiveWidth)
          } else {
            self.showError()
          }
        }
      }
    case .rejected:
      showError()
    }
  }

  @MainActor
  private func showImage(_ img: UIImage, token: UUID, maxWidth: CGFloat) {
    guard token == loadToken else { return }
    placeholderView.isHidden = true
    imageView.isHidden = false
    let sizing = rendering.sizing
    let size = fitted(
      img.size,
      maxWidth: maxWidth,
      upscales: sizing.upscalesSmallImages,
      minPlaceholder: rendering.placeholderHeight,
      maxHeight: sizing.maxImageHeight
    )
    imageView.image = img
    imageView.frame = CGRect(origin: .zero, size: size)
    frame.size = size
    invalidateIntrinsicContentSize()
  }

  private func showPlaceholder() {
    placeholderView.isHidden = false
    imageView.isHidden = true
  }

  private func showError() {
    placeholderView.isHidden = false
    imageView.isHidden = true
  }

  public override var intrinsicContentSize: CGSize {
    if let img = imageView.image {
      let maxW = rendering.sizing.maxBlockImageWidth ?? bounds.width
      return fitted(
        img.size,
        maxWidth: max(maxW, 1),
        upscales: rendering.sizing.upscalesSmallImages,
        minPlaceholder: rendering.placeholderHeight,
        maxHeight: rendering.sizing.maxImageHeight
      )
    }
    return CGSize(width: UIView.noIntrinsicMetric, height: rendering.placeholderHeight)
  }

  public func makeView() -> UIView {
    setNeedsLayout()
    return self
  }

  /// 取消订阅并重置为占位态，供列表复用。
  @MainActor
  public func prepareForReuse() {
    subscription?.cancel()
    isConfigured = false
    loadToken = UUID()
    imageView.image = nil
    imageView.isHidden = true
    placeholderView.isHidden = false
  }

  deinit {
    subscription?.cancel()
  }
}
