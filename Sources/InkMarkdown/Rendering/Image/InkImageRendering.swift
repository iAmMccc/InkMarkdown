import UIKit

/// 0.0.1 的图片回调没有 `@Sendable` / actor 约束；兼容存储不改变其调用线程契约。
private struct InkImageCallbackStorage: @unchecked Sendable {
  var imageTap: ((ImageSource, UIImage?) -> Void)?
  var loadFinished: ((ImageSource, UIImage?) -> Void)?
}

// MARK: - ImageSizing

/// 块级与行内图片的尺寸约束。
public struct ImageSizing: Sendable {

  /// 块级图片最大宽度（pt）。`nil` 表示使用容器可用宽度。
  public var maxBlockImageWidth: CGFloat?

  /// 行内图片最大宽度（pt）。`nil` 表示使用行片段宽度。
  public var maxInlineImageWidth: CGFloat? = nil

  /// 原始宽度小于上限时是否放大至上限。
  public var upscalesSmallImages: Bool = false

  /// 可选的最大高度（pt），配合 ``HeightPolicy`` 使用。
  public var maxImageHeight: CGFloat? = 2000

  /// 超出 `maxImageHeight` 时的处理方式。
  public var heightPolicy: HeightPolicy = .scaleToFit

  /// 图片高度策略（v1.0 预留，当前未生效）
  public enum HeightPolicy: Sendable, Hashable {
    /// 等比缩放，高度随宽度同比变化。
    case scaleToFit
    /// 高度钳制在 `maxImageHeight`，超出部分由布局层裁剪。
    case clip
  }

  public init() {}
}

// MARK: - ImageTapAction

/// 图片点击行为。
///
/// 块级通道（``InkImageBlock``）在 `tapAction != .none` 时自动安装点击手势并分发。
/// 行内 ``InkImageAttachment`` 仍需宿主对 `UITextView` 做命中检测后自行调用回调或打开 URL。
public enum ImageTapAction: Sendable, Hashable {
  /// 不响应点击。
  case none
  /// 尝试用系统打开图片 URL（http / https / file）；若同时设置了 ``InkImageRendering/onImageTap`` 也会调用。
  case openURL
  /// 仅触发 ``InkImageRendering/onImageTap`` 回调。
  case callback
}

// MARK: - AnimatedImagePolicy

/// 动图策略（v1.0 预留，当前未生效）
public enum AnimatedImagePolicy: Sendable, Hashable {
  /// 仅显示第一帧，不播放动画。
  case staticFirstFrame
  /// 循环播放。
  case loop
  /// 播放一次后停止。
  case playOnce
}

// MARK: - InkImageFailureFallback

/// 块级图片加载失败时的可选备用展示（模块内 API）。
///
/// 采用值类型而非闭包，避免破坏 ``InkImageRendering`` 在配置层的值语义，
/// 也无需让公开配置承担 `@Sendable` 闭包约束；具体集成方（如 Mermaid handler）
/// 在创建 ``InkImageBlock`` 前注入即可。
enum InkImageFailureFallback: Hashable {
  /// 以围栏代码块样式展示原始源码，便于复制与审查。
  case sourceCode(String, language: String?)
}

// MARK: - InkImageRendering

/// 图片渲染的完整公开配置。
///
/// 聚合开关、加载器、缓存、安全策略、尺寸与交互行为。
/// 闭包与自定义 loader 通过 ``InkSemanticIdentity`` 补足可比较的值语义。
public struct InkImageRendering: Sendable {

  /// 是否启用图片渲染。默认 `false`，保持 v1 占位行为。
  public var isEnabled: Bool = false

  private var storedLoader: (any InkImageLoading)?
  private var loaderSemanticIdentity: InkSemanticIdentity?

  /// 自定义图片加载器。`nil` 时 Store 使用内置 `DefaultURLSessionImageLoader`。
  /// 直接赋值会保守地生成新语义身份；反复构造等价 loader 时使用
  /// ``setLoader(_:semanticIdentity:)``。
  public var loader: (any InkImageLoading)? {
    get { storedLoader }
    set {
      storedLoader = newValue
      if let identity = newValue?.semanticIdentity {
        loaderSemanticIdentity = identity
      } else if newValue is (any InkConfigurationSemanticsProviding) {
        loaderSemanticIdentity = nil
      } else {
        loaderSemanticIdentity = newValue == nil ? nil : .unique()
      }
    }
  }

  private var storedGeneratedLoader: (any InkImageLoading)?
  private var generatedLoaderSemanticIdentity: InkSemanticIdentity?

  /// 本地生成型图片的 loader。仅当 ``ImageSource/generatedRequest`` 非空时使用。
  /// 其结果仍进入同一个 ``InkImageStore``，不会创建独立缓存。
  public var generatedLoader: (any InkImageLoading)? {
    get { storedGeneratedLoader }
    set {
      storedGeneratedLoader = newValue
      if let identity = newValue?.semanticIdentity {
        generatedLoaderSemanticIdentity = identity
      } else if newValue is (any InkConfigurationSemanticsProviding) {
        generatedLoaderSemanticIdentity = nil
      } else {
        generatedLoaderSemanticIdentity = newValue == nil ? nil : .unique()
      }
    }
  }

  /// 内存缓存配置。
  public var storeConfiguration: InkImageStore.Configuration = .init()

  /// 加载安全策略（scheme / host 白名单、重定向限制等）。
  public var securityPolicy: ImageSecurityPolicy = .init()

  /// 独立成行的图片是否提升为块级视图（而非行内 attachment）。
  public var promotesToBlock: Bool = true

  /// 块级与行内图片的尺寸约束。
  public var sizing: ImageSizing = .init()

  /// 块级 ``InkImageBlock`` 处于 **加载中**（`.loading` / `.queued`）时的骨架高度（pt）。
  ///
  /// 不用于加载失败态（失败走紧凑 alt 标签或 ``failureFallback``），
  /// 也不用于行内 ``InkImageAttachment``（行内未就绪高度见 ``inlineUnresolvedAttachmentHeight()``）。
  public var placeholderHeight: CGFloat = 160

  /// 点击图片时的默认行为。块级 ``InkImageBlock`` 会自动分发；默认 `.none`。
  public var tapAction: ImageTapAction = .none

  private var callbackStorage = InkImageCallbackStorage()
  private var imageTapSemanticIdentity: InkSemanticIdentity?

  /// 图片点击回调（仅在 ``tapAction`` 为 `.callback` 或 `.openURL` 时触发）。
  public var onImageTap: ((ImageSource, UIImage?) -> Void)? {
    get { callbackStorage.imageTap }
    set {
      callbackStorage.imageTap = newValue
      imageTapSemanticIdentity = newValue == nil ? nil : .unique()
    }
  }

  private var loadFinishedSemanticIdentity: InkSemanticIdentity?

  /// 加载完成回调（成功返回图片，失败返回 nil）。
  /// 在块级图片等展示层收到 Store 结果并应用后触发。
  public var onLoadFinished: ((ImageSource, UIImage?) -> Void)? {
    get { callbackStorage.loadFinished }
    set {
      callbackStorage.loadFinished = newValue
      loadFinishedSemanticIdentity = newValue == nil ? nil : .unique()
    }
  }

  /// 动图播放策略。
  public var animatedImagePolicy: AnimatedImagePolicy = .staticFirstFrame

  /// 相对图片地址的解析基准（ADR-006 相对 URL 契约）。
  ///
  /// - 提供 `baseURL`：相对 source（无 scheme，如 `docs/img.png`）解析为**确定**的
  ///   绝对请求 URL，参与加载与缓存身份规范化。
  /// - 未提供（默认）：相对 source 返回明确的 unsupported/no-base-URL 结果
  ///   （行内/块级通道按既有占位契约呈现），库不猜测来源。
  /// - 带 scheme 的绝对地址不受本字段影响。
  public var baseURL: URL? = nil

  /// 块级通道加载失败（含 Store rejected）时的备用展示；`nil` 时显示紧凑 alt 标签（约一行）。
  var failureFallback: InkImageFailureFallback?

  /// ``failureFallback`` 为源码代码块时使用的外观；Mermaid 等 handler 注入前应显式赋值。
  var failureCodeBlockStyle: InkAppearance.CodeBlock = .init()

  public init() {}

  /// 设置自定义 loader，并显式声明其加载语义身份。
  public mutating func setLoader(
    _ loader: (any InkImageLoading)?,
    semanticIdentity: InkSemanticIdentity
  ) {
    storedLoader = loader
    loaderSemanticIdentity = loader == nil ? nil : semanticIdentity
  }

  /// 设置生成图 loader，并显式声明其加载语义身份。
  public mutating func setGeneratedLoader(
    _ loader: (any InkImageLoading)?,
    semanticIdentity: InkSemanticIdentity
  ) {
    storedGeneratedLoader = loader
    generatedLoaderSemanticIdentity = loader == nil ? nil : semanticIdentity
  }

  /// 设置图片点击回调，并显式声明其交互语义身份。
  public mutating func setImageTapHandler(
    _ handler: ((ImageSource, UIImage?) -> Void)?,
    semanticIdentity: InkSemanticIdentity
  ) {
    callbackStorage.imageTap = handler
    imageTapSemanticIdentity = handler == nil ? nil : semanticIdentity
  }

  /// 设置加载完成回调，并显式声明其交互语义身份。
  public mutating func setLoadFinishedHandler(
    _ handler: ((ImageSource, UIImage?) -> Void)?,
    semanticIdentity: InkSemanticIdentity
  ) {
    callbackStorage.loadFinished = handler
    loadFinishedSemanticIdentity = handler == nil ? nil : semanticIdentity
  }

  /// 把配置层的 fallback identity 解析为 Store 实际使用的 loader identity。
  /// loader 自身声明的 identity 优先；否则使用直接赋值生成或 setter 显式提供的身份。
  func resolvedLoaderSemanticIdentity(
    for loader: any InkImageLoading,
    source: ImageSource?
  ) -> InkSemanticIdentity? {
    if let identity = loader.semanticIdentity {
      return identity
    }
    if source?.generatedRequest != nil {
      return generatedLoaderSemanticIdentity
    }
    return loaderSemanticIdentity
  }
}

// MARK: - Equatable

extension ImageSizing: Equatable {}

extension InkImageRendering: Equatable {
  public static func == (lhs: InkImageRendering, rhs: InkImageRendering) -> Bool {
    lhs.isEnabled == rhs.isEnabled &&
    InkSemanticComparator.imageLoadersAreEquivalent(
      lhs.storedLoader,
      rhs.storedLoader,
      lhsFallbackIdentity: lhs.loaderSemanticIdentity,
      rhsFallbackIdentity: rhs.loaderSemanticIdentity
    ) &&
    InkSemanticComparator.imageLoadersAreEquivalent(
      lhs.storedGeneratedLoader,
      rhs.storedGeneratedLoader,
      lhsFallbackIdentity: lhs.generatedLoaderSemanticIdentity,
      rhsFallbackIdentity: rhs.generatedLoaderSemanticIdentity
    ) &&
    lhs.storeConfiguration == rhs.storeConfiguration &&
    lhs.securityPolicy == rhs.securityPolicy &&
    lhs.promotesToBlock == rhs.promotesToBlock &&
    lhs.placeholderHeight == rhs.placeholderHeight &&
    lhs.tapAction == rhs.tapAction &&
    InkSemanticComparator.opaqueValuesAreEquivalent(
      lhsIsPresent: lhs.onImageTap != nil,
      rhsIsPresent: rhs.onImageTap != nil,
      lhsIdentity: lhs.imageTapSemanticIdentity,
      rhsIdentity: rhs.imageTapSemanticIdentity
    ) &&
    InkSemanticComparator.opaqueValuesAreEquivalent(
      lhsIsPresent: lhs.onLoadFinished != nil,
      rhsIsPresent: rhs.onLoadFinished != nil,
      lhsIdentity: lhs.loadFinishedSemanticIdentity,
      rhsIdentity: rhs.loadFinishedSemanticIdentity
    ) &&
    lhs.sizing == rhs.sizing &&
    lhs.animatedImagePolicy == rhs.animatedImagePolicy &&
    lhs.baseURL == rhs.baseURL &&
    lhs.failureFallback == rhs.failureFallback &&
    lhs.failureCodeBlockStyle == rhs.failureCodeBlockStyle
  }

}
