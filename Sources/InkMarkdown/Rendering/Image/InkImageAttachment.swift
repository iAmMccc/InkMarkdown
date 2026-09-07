import UIKit

/// 大图只抬升段落上限；段落缩进、对齐、间距与既有最小行高均由调用方保留。
enum InkImageParagraphStyle {
  static func elevating(_ existing: NSParagraphStyle?, toAtLeast height: CGFloat) -> NSMutableParagraphStyle {
    let result = (existing?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
    result.maximumLineHeight = max(result.maximumLineHeight, height)
    return result
  }
}

/// 行内图片通道：以 `NSTextAttachment` 嵌入 `NSAttributedString`。
///
/// **纯变换阶段**（``InkAttributedRenderer``）仅构造 attachment，不触发 Store 解析。
/// **显示层**（textStorage 安装 / ``bindAttachments`` / 主线程 ``attachmentBounds``）
/// 绑定 `layoutManager` 后惰性 ``materialize(display:loader:)``；加载完成回调只更新
/// 已有实例的 `image` / `bounds` 并触发布局失效。
@MainActor
public final class InkImageAttachment: NSTextAttachment, @unchecked Sendable {

  /// 图片加载完成时发送；宿主可监听并刷新 `UITextView` 布局。
  public static let imageDidLoadNotification = Notification.Name("InkImageAttachmentDidLoad")

  /// 规范化后的图片来源。
  nonisolated public let source: ImageSource

  nonisolated private let rendering: InkImageRendering
  private var boundStore: InkImageStore?
  /// 宿主布局管理器；显示层绑定时写入，用于加载完成后 invalidate。
  weak var layoutManager: NSLayoutManager?
  /// 布局高度变化通知（流式路径复用 ``InkStreamRenderer`` 的高度检测）。
  var onHeightChange: (() -> Void)?
  /// 标志位：标识下一次 `onHeightChange` 触发的高度变更是否推荐执行动画过渡。
  /// 在 `applyImage` 中当图片实际高度与占位高度差值超过 50pt 时设为 `true`，
  /// 回调完成后重置为 `false`。
  public internal(set) var shouldAnimateNextHeightChange: Bool = false
  nonisolated(unsafe) private var subscription: InkImageStore.ImageLoadSubscription?
  private enum LoaderIdentity: Equatable {
    case semantic(String)
    case instance(ObjectIdentifier)
    case unknown(UUID)
  }

  private struct MaterializationIdentity: Equatable {
    let display: DisplayContext
    let store: ObjectIdentifier
    let loader: LoaderIdentity
  }

  private var materializationIdentity: MaterializationIdentity?
  private var materializationGeneration = UUID()
  private var lastLineFragmentWidth: CGFloat = 0
  /// `attachmentBounds` 是 TextKit 的 nonisolated 纯测量回调，只读取主线程发布的图片快照。
  nonisolated(unsafe) private var renderedImage: UIImage?

  /// - Parameters:
  ///   - source: 图片来源。
  ///   - rendering: 图片渲染配置（尺寸、占位高度等）。
  ///   - store: 可选 Store；渲染阶段可省略，显示层绑定时按 rendering 选择默认 Store。
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

  /// 使用默认渲染 Store 创建（须在主线程调用）。
  @MainActor
  public convenience init(source: ImageSource, rendering: InkImageRendering) {
    self.init(
      source: source,
      rendering: rendering,
      store: InkImageStore.defaultStore(for: rendering)
    )
  }

  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  nonisolated public override func attachmentBounds(
    for textContainer: NSTextContainer?,
    proposedLineFragment lineFrag: CGRect,
    glyphPosition position: CGPoint,
    characterIndex charIndex: Int
  ) -> CGRect {
    let sizing = rendering.sizing
    let maxW = min(sizing.maxInlineImageWidth ?? lineFrag.width, lineFrag.width)
    if let img = renderedImage {
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
    bind(
      to: layoutManager,
      store: store,
      displayContext: nil,
      onHeightChange: onHeightChange
    )
  }

  /// 显示层绑定兼容重载：宿主可传入真实容器的显示上下文，避免从全局屏幕推断
  /// scale 或像素宽度。旧版 ``bind(to:store:onHeightChange:)`` 继续可用。
  @MainActor
  func bind(
    to layoutManager: NSLayoutManager,
    store: InkImageStore?,
    displayContext: DisplayContext?,
    onHeightChange: (() -> Void)?
  ) {

    self.layoutManager = layoutManager
    self.boundStore = store ?? boundStore ?? InkImageStore.defaultStore(for: rendering)
    self.onHeightChange = onHeightChange

    if let container = layoutManager.textContainers.first {
      let width = container.size.width - container.lineFragmentPadding * 2
      if width > 0 {
        lastLineFragmentWidth = width
        ensureMaterializedIfNeeded(
          lineFragmentWidth: width,
          displayContext: displayContext
        )
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
    _bindAttachments(
      in: textStorage,
      layoutManager: layoutManager,
      store: store,
      displayContext: nil,
      onHeightChange: onHeightChange,
      range: range
    )
  }

  /// 带宿主显示上下文的绑定入口。用于 SwiftUI/UIKit adapter 已知真实容器宽度与
  /// scale 的路径；旧签名保留，未提供时继续使用兼容测量逻辑。
  @MainActor
  public static func bindAttachments(
    in textStorage: NSTextStorage,
    layoutManager: NSLayoutManager,
    store: InkImageStore? = nil,
    displayContext: DisplayContext,
    onHeightChange: (() -> Void)? = nil,
    range: NSRange? = nil
  ) {
    _bindAttachments(
      in: textStorage,
      layoutManager: layoutManager,
      store: store,
      displayContext: displayContext,
      onHeightChange: onHeightChange,
      range: range
    )
  }

  @MainActor
  private static func _bindAttachments(
    in textStorage: NSTextStorage,
    layoutManager: NSLayoutManager,
    store: InkImageStore?,
    displayContext: DisplayContext?,
    onHeightChange: (() -> Void)?,
    range: NSRange?
  ) {
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
      attachment.bind(
        to: layoutManager,
        store: store,
        displayContext: displayContext,
        onHeightChange: onHeightChange
      )
    }
  }

  /// 向 Store 发起解析，并在就绪或加载完成时应用到 attachment。幂等：重复调用安全。
  ///
  /// - Parameters:
  ///   - display: 目标显示上下文。
  ///   - loader: 实际执行解码的加载器。
  @MainActor
  public func materialize(display: DisplayContext, loader: InkImageLoading) {
    let store = boundStore ?? InkImageStore.defaultStore(for: rendering)
    boundStore = store

    let identity = MaterializationIdentity(
      display: display,
      store: ObjectIdentifier(store),
      loader: loaderIdentity(for: loader)
    )
    guard materializationIdentity != identity else { return }

    subscription?.cancel()
    subscription = nil
    materializationIdentity = identity
    let generation = UUID()
    materializationGeneration = generation
    let sizing = rendering.sizing
    let result = store.resolve(source: source, display: display, loader: loader)
    switch result {
    case .ready(let img):
      applyImage(
        img,
        sizing: sizing,
        lineFragmentWidth: resolvedLineFragmentWidth(),
        generation: generation
      )
    case .loading(let subscribe):
      subscription = subscribe { [weak self] image in
        guard let self else { return }
        guard self.materializationGeneration == generation,
              self.materializationIdentity == identity else { return }
        if let image {
          self.applyImage(
            image,
            sizing: sizing,
            lineFragmentWidth: self.resolvedLineFragmentWidth(),
            generation: generation
          )
        }
      }
    case .queued(let subscribe):
      subscription = subscribe { [weak self] image in
        guard let self else { return }
        guard self.materializationGeneration == generation,
              self.materializationIdentity == identity else { return }
        if let image {
          self.applyImage(
            image,
            sizing: sizing,
            lineFragmentWidth: self.resolvedLineFragmentWidth(),
            generation: generation
          )
        }
      }
    case .rejected:
      break
    }
  }

  @MainActor
  private func ensureMaterializedIfNeeded(
    lineFragmentWidth: CGFloat,
    displayContext: DisplayContext?
  ) {
    let store = boundStore ?? InkImageStore.defaultStore(for: rendering)
    boundStore = store
    lastLineFragmentWidth = lineFragmentWidth
    let display = displayContext.map {
      constrainedDisplayContext($0, lineFragmentWidth: lineFragmentWidth)
    } ?? {
      let sizing = rendering.sizing
      let maxW = min(sizing.maxInlineImageWidth ?? lineFragmentWidth, lineFragmentWidth)
      let scale = InkDisplayMetrics.resolve().scale
      return DisplayContext(
        maxPixelWidth: max(maxW, 1) * scale,
        scale: scale,
        contentMode: .fit
      )
    }()
    let loader = store.loader(for: rendering, source: source)
    materialize(display: display, loader: loader)
  }

  /// 收敛宿主宽度与当前 attachment 自身的 inline 宽度上限。
  ///
  /// 宿主 helper 只计算一次真实 text view 宽度；每个 attachment 仍须把自己的
  /// `maxInlineImageWidth` 纳入解码身份，避免较小的图片配置拿到过宽位图。
  @MainActor
  private func constrainedDisplayContext(
    _ context: DisplayContext,
    lineFragmentWidth: CGFloat
  ) -> DisplayContext {
    let maxWidth = min(
      rendering.sizing.maxInlineImageWidth ?? lineFragmentWidth,
      lineFragmentWidth
    )
    return DisplayContext(
      maxPixelWidth: min(context.maxPixelWidth, max(maxWidth, 1) * context.scale),
      scale: context.scale,
      contentMode: context.contentMode
    )
  }

  @MainActor
  private func applyImage(
    _ loadedImage: UIImage,
    sizing: ImageSizing,
    lineFragmentWidth: CGFloat?,
    generation: UUID
  ) {
    guard materializationGeneration == generation else { return }
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
    renderedImage = loadedImage

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

  @MainActor
  private func loaderIdentity(for loader: InkImageLoading) -> LoaderIdentity {
    if let semanticIdentity = loader.semanticIdentity {
      return .semantic(semanticIdentity.rawValue)
    }
    // Class loaders can be compared by reference. Value-type loaders without a declared
    // semantic identity are intentionally treated as unknown and rematerialized conservatively.
    if Mirror(reflecting: loader).displayStyle == .class {
      return .instance(ObjectIdentifier(loader as AnyObject))
    }
    return .unknown(UUID())
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
    let para = InkImageParagraphStyle.elevating(existing, toAtLeast: maxImageHeight)
    guard para.maximumLineHeight > (existing?.maximumLineHeight ?? 0) else { return }
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

/// UITextView 宿主的行内图片绑定工具。
///
/// 该入口只在宿主已经有真实容器宽度时 materialize。宽度优先取 TextKit 已发布的
/// `textContainer.size`，否则取 text view bounds 减去 textContainer inset；scale 优先
/// 取实际 window screen，再回退到该 view 的 trait。未挂载且无有效宽度时留到下一次
/// layout / sizeThatFits 调用，不从前台 scene 或全局 screen 猜测宿主尺寸。
@MainActor
public extension InkImageAttachment {

  /// 在 UITextView 的真实容器上下文中绑定行内图片。
  ///
  /// - Parameters:
  ///   - textView: 已安装 attachment 的文本宿主。
  ///   - store: 可选的宿主 Store；省略时按 attachment 的 rendering 配置选择默认 Store。
  ///   - onHeightChange: 图片实际高度变化后的宿主回调。
  ///   - range: 可选增量绑定范围。
  ///
  /// 宿主在宽度、window screen 或 display scale 改变后应再次调用；attachment 会按完整
  /// display / Store / loader identity 取消旧订阅并重新 materialize。
  static func bindAttachments(
    in textView: UITextView,
    store: InkImageStore? = nil,
    onHeightChange: (() -> Void)? = nil,
    range: NSRange? = nil
  ) {
    guard let displayContext = displayContext(for: textView) else { return }
    guard let layoutManager = textView.textContainer.layoutManager else { return }
    bindAttachments(
      in: textView.textStorage,
      layoutManager: layoutManager,
      store: store,
      displayContext: displayContext,
      onHeightChange: onHeightChange,
      range: range
    )
  }

  /// 返回宿主当前真实的行片段显示上下文；宽度无效时返回 `nil`。
  ///
  /// 该接口供跨模块 SwiftUI/UIKit bridge 在需要自定义绑定时复用同一套 width / scale
  /// 规则；一般宿主直接调用 ``bindAttachments(in:store:onHeightChange:range:)`` 即可。
  static func displayContext(for textView: UITextView) -> DisplayContext? {
    let lineFragmentPadding = textView.textContainer.lineFragmentPadding
    let rawContainerWidth = textView.textContainer.size.width
    let width: CGFloat
    if rawContainerWidth.isFinite, rawContainerWidth > 0 {
      width = rawContainerWidth - lineFragmentPadding * 2
    } else {
      let insetWidth = textView.textContainerInset.left + textView.textContainerInset.right
      width = textView.bounds.width - insetWidth - lineFragmentPadding * 2
    }
    guard width.isFinite, width > 0 else { return nil }

    let scale: CGFloat?
    if let screenScale = textView.window?.screen.scale,
       screenScale.isFinite,
       screenScale > 0 {
      scale = screenScale
    } else {
      let traitScale = textView.traitCollection.displayScale
      scale = traitScale.isFinite && traitScale > 0 ? traitScale : nil
    }
    guard let scale else { return nil }

    return DisplayContext(
      maxPixelWidth: width * scale,
      scale: scale,
      contentMode: .fit
    )
  }
}
