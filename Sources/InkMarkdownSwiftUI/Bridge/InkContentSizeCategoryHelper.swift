import SwiftUI
import UIKit

extension UIContentSizeCategory {
  /// 将 SwiftUI 的 ContentSizeCategory 映射为 UIKit 的 UIContentSizeCategory。
  static func from(swiftUICategory: ContentSizeCategory) -> UIContentSizeCategory {
    switch swiftUICategory {
    case .extraSmall: return .extraSmall
    case .small: return .small
    case .medium: return .medium
    case .large: return .large
    case .extraLarge: return .extraLarge
    case .extraExtraLarge: return .extraExtraLarge
    case .extraExtraExtraLarge: return .extraExtraExtraLarge
    case .accessibilityMedium: return .accessibilityMedium
    case .accessibilityLarge: return .accessibilityLarge
    case .accessibilityExtraLarge: return .accessibilityExtraLarge
    case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
    case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
    @unknown default: return .large
    }
  }
}
