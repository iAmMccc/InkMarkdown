import UIKit
import InkMarkdown

enum DemoPresentationContext {
  /// 返回当前前台 Scene 的最上层展示控制器，供 SwiftUI Demo 注入 UIKit 预览入口。
  static func topViewController() -> UIViewController? {
    guard let root = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive })?
      .windows
      .first(where: \.isKeyWindow)?
      .rootViewController
    else { return nil }

    var top = root
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }
}

extension UIViewController {
  /// 弹出 InkMarkdown 自带的全屏图片预览；无可用 `UIImage` 时不展示。
  ///
  /// - Parameters:
  ///   - source: 图片来源，供预览控制器后台拉取高清图。
  ///   - image: 列表中已有的降采样占位图。
  ///   - loader: 高清图加载器；为 `nil` 时预览仅展示占位图。
  ///   - previewPolicy: 高清解码与缓存策略，默认 bypass Store。
  func presentInkImagePreview(
    source: ImageSource,
    image: UIImage?,
    loader: InkImageLoading? = nil,
    previewPolicy: PreviewLoadPolicy = PreviewLoadPolicy()
  ) {
    guard let image else { return }
    let preview = InkImagePreviewController(
      source: source,
      displayImage: image,
      loader: loader,
      previewPolicy: previewPolicy
    )
    preview.modalPresentationStyle = .fullScreen
    present(preview, animated: true)
  }
}

extension InkAppearance {
  /// 为块级图片通道开启点击放大（行内 `InkImageAttachment` 不受影响）。
  mutating func enableDemoBlockImageTap(presentingViewController: @escaping () -> UIViewController?) {
    imageRendering.tapAction = .callback
    let rendering = imageRendering
    imageRendering.onImageTap = { source, image in
      let loader = InkImageStore.shared.loader(for: rendering)
      presentingViewController()?.presentInkImagePreview(
        source: source,
        image: image,
        loader: loader
      )
    }
  }

  /// 为 Mermaid 生成图块开启点击全屏预览（`InkImageBlock` / generated owner `mermaid`）。
  ///
  /// 复用 SSE 场景的 ``MermaidFullscreenViewController``；非 Mermaid 图源忽略点击。
  mutating func enableDemoMermaidImageTap(presentingViewController: @escaping () -> UIViewController?) {
    imageRendering.tapAction = .callback
    imageRendering.onImageTap = { source, image in
      guard source.generatedRequest?.owner == "mermaid", let image else { return }
      let fullVC = MermaidFullscreenViewController(image: image)
      presentingViewController()?.present(fullVC, animated: true)
    }
  }
}
