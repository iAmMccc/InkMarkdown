import UIKit

/// 从当前 UIKit 上下文解析显示尺寸，避免依赖全局 screen 单例。
struct InkDisplayMetrics {
  let bounds: CGRect
  let scale: CGFloat

  @MainActor
  static func resolve(for view: UIView? = nil) -> InkDisplayMetrics {
    let screen = contextualScreen(for: view)
    let bounds: CGRect
    if let view, view.bounds.width > 0, view.bounds.height > 0 {
      bounds = view.bounds
    } else if let window = view?.window, !window.bounds.isEmpty {
      bounds = window.bounds
    } else {
      bounds = screen?.bounds ?? .zero
    }

    let screenScale = screen?.scale ?? 0
    let traitScale = view?.traitCollection.displayScale ?? 0
    let scale = screenScale > 0 ? screenScale : (traitScale > 0 ? traitScale : 1)
    return InkDisplayMetrics(bounds: bounds, scale: scale)
  }

  @MainActor
  static func availableWidth(for view: UIView, fallback: CGFloat = 320) -> CGFloat {
    if view.bounds.width > 0 { return view.bounds.width }
    if let windowWidth = view.window?.bounds.width, windowWidth > 0 { return windowWidth }
    let sceneWidth = contextualScreen(for: view)?.bounds.width ?? 0
    return sceneWidth > 0 ? sceneWidth : fallback
  }

  @MainActor
  private static func contextualScreen(for view: UIView?) -> UIScreen? {
    if let screen = view?.window?.windowScene?.screen {
      return screen
    }
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first(where: { $0.activationState == .foregroundActive })?
      .screen
  }
}
