import UIKit

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

/// 图片点击行为（v1.0 预留，当前未生效，需宿主自行实现手势分发）
public enum ImageTapAction: Sendable, Hashable {
  /// 不响应点击。
  case none
  /// 尝试用系统打开图片 URL。
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

// MARK: - InkImageRendering

/// 图片渲染的完整公开配置。
///
/// 聚合开关、加载器、缓存、安全策略、尺寸与交互行为。
/// 因含闭包与协议类型，本结构体不 conform `Sendable`。
public struct InkImageRendering {

  /// 是否启用图片渲染。默认 `false`，保持 v1 占位行为。
  public var isEnabled: Bool = false

  /// 自定义图片加载器。`nil` 时 Store 使用内置 `DefaultURLSessionImageLoader`。
  public var loader: (any InkImageLoading)?

  /// 内存缓存配置。
  public var storeConfiguration: InkImageStore.Configuration = .init()

  /// 加载安全策略（scheme / host 白名单、重定向限制等）。
  public var securityPolicy: ImageSecurityPolicy = .init()

  /// 独立成行的图片是否提升为块级视图（而非行内 attachment）。
  public var promotesToBlock: Bool = true

  /// 块级与行内图片的尺寸约束。
  public var sizing: ImageSizing = .init()

  /// 加载中占位视图的高度（pt）。
  public var placeholderHeight: CGFloat = 80

  /// 点击图片时的默认行为。
  public var tapAction: ImageTapAction = .none

  /// 图片点击回调（v1.0 预留，当前未生效），在 ``tapAction`` 为 `.callback` 或需要额外处理时由宿主实现。
  public var onImageTap: ((ImageSource, UIImage?) -> Void)?

  /// 动图播放策略。
  public var animatedImagePolicy: AnimatedImagePolicy = .staticFirstFrame

  /// 相对路径基准 URL（v1.0 预留，当前未生效）
  public var baseURL: URL? = nil

  public init() {}
}
