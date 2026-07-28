import UIKit

/// 行内图片通道：以 `NSTextAttachment` 嵌入 `NSAttributedString`。
///
/// 通过 ``InkImageStore`` 解析图片；加载完成后更新 `image` / `bounds`，
/// 并在已绑定 `layoutManager` 与 `characterRange` 时触发布局失效。
///
/// 须在主线程使用：内部依赖 ``InkImageStore``（``@MainActor``）。
public final class InkImageAttachment: NSTextAttachment {

  /// 图片加载完成时发送；宿主可监听并刷新 `UITextView` 布局。
  public static let imageDidLoadNotification = Notification.Name("InkImageAttachmentDidLoad")

  /// 规范化后的图片来源。
  public let source: ImageSource

  private let store: InkImageStore
  private let rendering: InkImageRendering
  /// 宿主布局管理器；加载完成后用于局部 invalidate。
  weak var layoutManager: NSLayoutManager?
  /// 本 attachment 在文本中的字符范围；未绑定时为 `NSNotFound`。
  var characterRange: NSRange = .init(location: NSNotFound, length: 0)
  private var subscription: InkImageStore.ImageLoadSubscription?

  /// - Parameters:
  ///   - source: 图片来源。
  ///   - store: 图片状态管理器（可由外部注入，或传入 ``InkImageStore/shared``）。
  ///   - rendering: 图片渲染配置（尺寸、占位高度等）。
  public init(
    source: ImageSource,
    store: InkImageStore,
    rendering: InkImageRendering
  ) {
    self.source = source
    self.store = store
    self.rendering = rendering
    super.init(data: nil, ofType: nil)
  }

  /// 使用共享 Store 创建（须在主线程调用）。
  @MainActor
  public convenience init(source: ImageSource, rendering: InkImageRendering) {
    self.init(source: source, store: .shared, rendering: rendering)
  }

  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func attachmentBounds(
    for textContainer: NSTextContainer?,
    proposedLineFragment lineFrag: CGRect,
    glyphPosition position: CGPoint,
    characterIndex charIndex: Int
  ) -> CGRect {
    let sizing = rendering.sizing
    let maxW = min(sizing.maxInlineImageWidth ?? lineFrag.width, lineFrag.width)
    if let img = image {
      return CGRect(
        origin: .zero,
        size: fitted(
          img.size,
          maxWidth: maxW,
          upscales: sizing.upscalesSmallImages,
          minPlaceholder: rendering.placeholderHeight,
          maxHeight: sizing.maxImageHeight
        )
      )
    }
    return CGRect(origin: .zero, size: CGSize(width: maxW, height: rendering.placeholderHeight))
  }

  /// 向 Store 发起解析，并在就绪或加载完成时应用到 attachment。
  ///
  /// - Parameters:
  ///   - display: 目标显示上下文。
  ///   - loader: 实际执行解码的加载器。
  @MainActor
  public func materialize(display: DisplayContext, loader: InkImageLoading) {
    subscription?.cancel()
    let sizing = rendering.sizing
    let result = store.resolve(source: source, display: display, loader: loader)
    switch result {
    case .ready(let img):
      applyImage(img, sizing: sizing)
    case .loading(let subscribe):
      subscription = subscribe { [weak self] image in
        guard let self else { return }
        if let image {
          self.applyImage(image, sizing: sizing)
        }
      }
    case .queued(let subscribe):
      subscription = subscribe { [weak self] image in
        guard let self else { return }
        if let image {
          self.applyImage(image, sizing: sizing)
        }
      }
    case .rejected:
      break
    }
  }

  @MainActor
  private func applyImage(_ loadedImage: UIImage, sizing: ImageSizing) {
    let fittedSize = fitted(
      loadedImage.size,
      maxWidth: sizing.maxInlineImageWidth ?? 300,
      upscales: sizing.upscalesSmallImages,
      minPlaceholder: rendering.placeholderHeight,
      maxHeight: sizing.maxImageHeight
    )
    bounds = CGRect(origin: .zero, size: fittedSize)
    image = loadedImage

    NotificationCenter.default.post(
      name: InkImageAttachment.imageDidLoadNotification,
      object: self
    )

    guard characterRange.location != NSNotFound else { return }
    layoutManager?.invalidateLayout(forCharacterRange: characterRange, actualCharacterRange: nil)
  }

  deinit {
    subscription?.cancel()
  }
}
