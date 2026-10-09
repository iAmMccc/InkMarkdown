import UIKit

/// 主线程捕获、后台解析可安全消费的 trait 快照。
///
/// 流式渲染在 ``InkStreamRenderer`` 的公开 API（主线程）上捕获当前
/// `userInterfaceStyle` 与 Dynamic Type category，再随 ``InkConfiguration/renderEnvironment``
/// 传入后台 parse 队列，供 ``InkLaTeXColor`` 等路径解析动态 `UIColor` 而无需触碰 UIKit 主 actor。
public struct InkRenderEnvironment: Sendable, Hashable {
  /// 解析动态色时使用的外观；`.unspecified` 表示尚未注入，将按 light 解析。
  public var userInterfaceStyle: UIUserInterfaceStyle
  /// Dynamic Type 档位；`.unspecified` 表示沿用系统当前 trait。
  public var contentSizeCategory: UIContentSizeCategory

  public init(
    userInterfaceStyle: UIUserInterfaceStyle = .unspecified,
    contentSizeCategory: UIContentSizeCategory = .unspecified
  ) {
    self.userInterfaceStyle = userInterfaceStyle
    self.contentSizeCategory = contentSizeCategory
  }

  /// 从当前 trait 环境捕获快照；须在主线程调用。
  @MainActor
  public static var current: InkRenderEnvironment {
    InkRenderEnvironment(
      userInterfaceStyle: UITraitCollection.current.userInterfaceStyle,
      contentSizeCategory: UITraitCollection.current.preferredContentSizeCategory
    )
  }

  var traitCollection: UITraitCollection {
    var traits: [UITraitCollection] = []
    switch userInterfaceStyle {
    case .dark:
      traits.append(UITraitCollection(userInterfaceStyle: .dark))
    case .light:
      traits.append(UITraitCollection(userInterfaceStyle: .light))
    case .unspecified:
      traits.append(UITraitCollection(userInterfaceStyle: .light))
    @unknown default:
      traits.append(UITraitCollection(userInterfaceStyle: .light))
    }
    if contentSizeCategory != .unspecified {
      traits.append(UITraitCollection(preferredContentSizeCategory: contentSizeCategory))
    }
    return UITraitCollection(traitsFrom: traits)
  }
}
