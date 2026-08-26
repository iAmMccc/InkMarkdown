import UIKit

/// 行内图片通道：以 `NSTextAttachment` 嵌入 `NSAttributedString`。
///
/// **纯变换阶段**（``InkAttributedRenderer``）仅构造 attachment，不触发 Store 解析。
/// **显示层**（textStorage 安装 / ``bindAttachments`` / 主线程 ``attachmentBounds``）
/// 绑定 `layoutManager` 后惰性 ``materialize(display:loader:)``；加载完成回调只更新
/// 已有实例的 `image` / `bounds` 并触发布局失效。
public final class InkImageAttachment: NSTextAttachment {

  /// 图片加载完成时发送；宿主可监听并刷新 `UITextView` 布局。
  public static let imageDidLoadNotification = Notification.Name("InkImageAttachmentDidLoad")

  /// 规范化后的图片来源。
  public let source: ImageSource

  private let rendering: InkImageRendering
  private var boundStore: InkImageStore?
  /// 宿主布局管理器；显示层绑定时写入，用于加载完成后 invalidate。
  weak var layoutManager: NSLayoutManager?
  /// 布局高度变化通知（流式路径复用 ``InkStreamRenderer`` 的高度检测）。
  var onHeightChange: (() -> Void)?
  /// 标志位：标识下一次 `onHeightChange` 触发的高度变更是否推荐执行动画过渡。
  /// 在 `applyImage` 中当图片实际高度与占位高度差值超过 50pt 时设为 `true`，
  /// 回调完成后重置为 `false`。
  public internal(set) var shouldAnimateNextHeightChange: Bool = false
  private var subscription: InkImageStore.ImageLoadSubscription?
  private var didMaterialize = false
  private var pendingLayoutMaterialize = false
  private var lastLineFragmentWidth: CGFloat = 0

  /// - Parameters:
  ///   - source: 图片来源。
  ///   - rendering: 图片渲染配置（尺寸、占位高度等）。
  ///   - store: 可选 Store；渲染阶段可省略，显示层绑定时注入 ``InkImageStore/shared``。
  nonisolated public init(
    source: ImageSource,
    rendering: InkImageRendering,
    store: InkImageStore? = nil
  ) {
    self.source = source
    self.rendering = rendering
    self.boundStore = store
    super.init(data: nil, ofType: nil)
  }

  /// 使用共享 Store 创建（须在主线程调用）。
  @MainActor
  public convenience init(source: ImageSource, rendering: InkImageRendering) {
    self.init(source: source, rendering: rendering, store: .shared)
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
    if Thread.isMainThread {
      lastLineFragmentWidth = lineFrag.width
      MainActor.assumeIsolated {
        scheduleMaterializeFromLayoutIfNeeded(lineFragmentWidth: lineFrag.width)
      }
    }

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
    return CGRect(origin: .zero, size: CGSize(width: maxW, height: inlineUnresolvedAttachmentHeight()))
  }

  /// 显示层绑定：注入 Store / layoutManager，并在容器宽度已知时触发首次 materialize。
  @MainActor
  func bind(
    to layoutManager: NSLayoutManager,
    store: InkImageStore,
    onHeightChange: (() -> Void)?
  ) {
    let alreadyBound = didMaterialize
      && self.layoutManager === layoutManager
      && boundStore === store

    self.layoutManager = layoutManager
    self.boundStore = store
    self.onHeightChange = onHeightChange

    guard !alreadyBound else { return }

    if let container = layoutManager.textContainers.first {
      let width = container.size.width - container.lineFragmentPadding * 2
      if width > 0 {
        lastLineFragmentWidth = width
        ensureMaterializedIfNeeded(lineFragmentWidth: width)
      }
    }
  }

  /// 扫描 textStorage 内 attachment 并完成显示层绑定。
  ///
  /// - Parameter range: 限定扫描区间；`nil` 时扫描全文（低频全量灌入路径）。
  @MainActor
  public static func bindAttachments(
    in textStorage: NSTextStorage,
    layoutManager: NSLayoutManager,
    store: InkImageStore? = nil,
    onHeightChange: (() -> Void)? = nil,
    range: NSRange? = nil
  ) {
    let resolvedStore = store ?? .shared
    guard textStorage.length > 0 else { return }
    let searchRange: NSRange
    if let range {
      let clampedLocation = max(0, min(range.location, textStorage.length))
      let maxLength = textStorage.length - clampedLocation
      searchRange = NSRange(location: clampedLocation, length: min(range.length, maxLength))
      guard searchRange.length > 0 else { return }
    } else {
      searchRange = NSRange(location: 0, length: textStorage.length)
    }
    textStorage.enumerateAttribute(.attachment, in: searchRange, options: []) { value, _, _ in
      guard let attachment = value as? InkImageAttachment else { return }
      attachment.bind(to: layoutManager, store: resolvedStore, onHeightChange: onHeightChange)
    }
  }

  /// 向 Store 发起解析，并在就绪或加载完成时应用到 attachment。幂等：重复调用安全。
  ///
  /// - Parameters:
  ///   - display: 目标显示上下文。
  ///   - loader: 实际执行解码的加载器。
  @MainActor
  public func materialize(display: DisplayContext, loader: InkImageLoading) {
    guard let store = boundStore else { return }
    subscription?.cancel()
    store.prepareForRendering(rendering)
    let sizing = rendering.sizing
    let result = store.resolve(source: source, display: display, loader: loader)
    switch result {
    case .ready(let img):
      applyImage(img, sizing: sizing, lineFragmentWidth: resolvedLineFragmentWidth())
    case .loading(let subscribe):
      subscription = subscribe { [weak self] image in
        guard let self else { return }
        if let image {
          self.applyImage(image, sizing: sizing, lineFragmentWidth: self.resolvedLineFragmentWidth())
        }
      }
    case .queued(let subscribe):
      subscription = subscribe { [weak self] image in
        guard let self else { return }
        if let image {
          self.applyImage(image, sizing: sizing, lineFragmentWidth: self.resolvedLineFragmentWidth())
        }
      }
    case .rejected:
      break
    }
  }

  /// `attachmentBounds` 处于 TextKit 布局回调中；缓存命中时同步 materialize 会立刻
  /// 改写 textStorage / invalidateLayout，构成布局重入。这里推迟到下一个 runloop 执行。
  @MainActor
  private func scheduleMaterializeFromLayoutIfNeeded(lineFragmentWidth: CGFloat) {
    guard !didMaterialize, boundStore != nil, !pendingLayoutMaterialize else { return }
    pendingLayoutMaterialize = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.pendingLayoutMaterialize = false
      self.ensureMaterializedIfNeeded(lineFragmentWidth: lineFragmentWidth)
    }
  }

  @MainActor
  private func ensureMaterializedIfNeeded(lineFragmentWidth: CGFloat) {
    guard !didMaterialize, let store = boundStore else { return }
    didMaterialize = true
    lastLineFragmentWidth = lineFragmentWidth
    let sizing = rendering.sizing
    let maxW = min(sizing.maxInlineImageWidth ?? lineFragmentWidth, lineFragmentWidth)
    let scale = UIScreen.main.scale
    let display = DisplayContext(
      maxPixelWidth: max(maxW, 1) * scale,
      scale: scale,
      contentMode: .fit
    )
    let loader = store.loader(for: rendering, source: source)
    materialize(display: display, loader: loader)
  }

  @MainActor
  private func applyImage(_ loadedImage: UIImage, sizing: ImageSizing, lineFragmentWidth: CGFloat?) {
    let maxW = resolvedMaxWidth(lineFragmentWidth: lineFragmentWidth)
    let fittedSize = fitted(
      loadedImage.size,
      maxWidth: maxW,
      upscales: sizing.upscalesSmallImages,
      minPlaceholder: rendering.placeholderHeight,
      maxHeight: sizing.maxImageHeight
    )

    let heightDelta = abs(fittedSize.height - inlineUnresolvedAttachmentHeight())
    let needsAnimation = heightDelta > 50
    shouldAnimateNextHeightChange = needsAnimation
    defer {
      shouldAnimateNextHeightChange = false
    }

    bounds = CGRect(origin: .zero, size: fittedSize)
    image = loadedImage

    NotificationCenter.default.post(
      name: InkImageAttachment.imageDidLoadNotification,
      object: self
    )

    guard let layoutManager,
          let textStorage = layoutManager.textStorage else { return }
    guard let attachmentRange = Self.characterRange(of: self, in: textStorage) else { return }

    let paragraphRange = (textStorage.string as NSString).paragraphRange(for: attachmentRange)
    elevateParagraphMaximumLineHeight(in: textStorage, paragraphRange: paragraphRange)

    layoutManager.invalidateLayout(forCharacterRange: paragraphRange, actualCharacterRange: nil)
    onHeightChange?()
  }

  private func resolvedLineFragmentWidth() -> CGFloat? {
    if lastLineFragmentWidth > 0 { return lastLineFragmentWidth }
    return effectiveMaxWidth(from: layoutManager)
  }

  private func resolvedMaxWidth(lineFragmentWidth: CGFloat?) -> CGFloat {
    if let width = lineFragmentWidth, width > 0 {
      return min(rendering.sizing.maxInlineImageWidth ?? width, width)
    }
    return effectiveMaxWidth(from: layoutManager) ?? rendering.sizing.maxInlineImageWidth ?? 300
  }

  private func effectiveMaxWidth(from layoutManager: NSLayoutManager?) -> CGFloat? {
    guard let container = layoutManager?.textContainers.first else { return nil }
    let containerWidth = container.size.width - container.lineFragmentPadding * 2
    guard containerWidth > 0 else { return nil }
    return min(rendering.sizing.maxInlineImageWidth ?? containerWidth, containerWidth)
  }

  /// 段内 oversized 图抬升：整段写入 `maximumLineHeight`，取段内所有图片高度的 max，且不降低已有抬升。
  @MainActor
  private func elevateParagraphMaximumLineHeight(in textStorage: NSTextStorage, paragraphRange: NSRange) {
    var maxImageHeight: CGFloat = 0
    textStorage.enumerateAttribute(.attachment, in: paragraphRange, options: []) { value, _, _ in
      guard let attachment = value as? InkImageAttachment else { return }
      maxImageHeight = max(maxImageHeight, attachment.bounds.height)
    }
    guard maxImageHeight > 0 else { return }

    let existing = textStorage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil)
      as? NSParagraphStyle
    let para = (existing?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
    let lockedMinimum = para.minimumLineHeight
    let targetMaximum = max(lockedMinimum, maxImageHeight)
    guard targetMaximum > para.maximumLineHeight else { return }

    para.maximumLineHeight = targetMaximum
    textStorage.addAttribute(.paragraphStyle, value: para, range: paragraphRange)
  }

  private static func characterRange(of attachment: InkImageAttachment, in textStorage: NSTextStorage) -> NSRange? {
    var found: NSRange?
    let fullRange = NSRange(location: 0, length: textStorage.length)
    textStorage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, stop in
      if value as AnyObject === attachment {
        found = range
        stop.pointee = true
      }
    }
    return found
  }

  deinit {
    subscription?.cancel()
  }
}
