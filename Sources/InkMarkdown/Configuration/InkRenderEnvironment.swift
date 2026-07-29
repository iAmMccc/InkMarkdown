import UIKit

/// 主线程捕获、后台解析可安全消费的 trait 快照。
///
/// 流式渲染在 ``InkStreamRenderer`` 的公开 API（主线程）上捕获当前
/// `userInterfaceStyle`，再随 ``InkConfiguration/renderEnvironment`` 传入后台
/// parse 队列，供 ``InkLaTeXColor`` 等路径解析动态 `UIColor` 而无需触碰 UIKit 主 actor。
public struct InkRenderEnvironment: Sendable, Hashable {
  /// 解析动态色时使用的外观；`.unspecified` 表示尚未注入，将按 light 解析。
  public var userInterfaceStyle: UIUserInterfaceStyle

  public init(userInterfaceStyle: UIUserInterfaceStyle = .unspecified) {
    self.userInterfaceStyle = userInterfaceStyle
  }

  /// 从当前 trait 环境捕获快照；须在主线程调用。
  @MainActor
  public static var current: InkRenderEnvironment {
    InkRenderEnvironment(userInterfaceStyle: UITraitCollection.current.userInterfaceStyle)
  }

  var traitCollection: UITraitCollection {
    switch userInterfaceStyle {
    case .dark:
      return UITraitCollection(userInterfaceStyle: .dark)
    case .light:
      return UITraitCollection(userInterfaceStyle: .light)
    case .unspecified:
      return UITraitCollection(userInterfaceStyle: .light)
    @unknown default:
      return UITraitCollection(userInterfaceStyle: .light)
    }
  }
}
