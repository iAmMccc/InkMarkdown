import UIKit

// MARK: - PreviewLoadPolicy

/// 全屏预览加载高清图时的策略。
///
/// - `maxPreviewPixel`：高清解码的最长边像素上限，默认 4096，
///   避免超大图（如 8000×6000）一次性占用过多内存。
/// 缓存由显式注入的后端管理，预览不添加或绕过独立缓存层。
public struct PreviewLoadPolicy: Sendable {

  /// 高清预览解码的最长边像素上限。
  public var maxPreviewPixel: CGFloat = 4096

  public init() {}
}

// MARK: - InkImagePreviewController

/// 全屏图片预览控制器。
///
/// 支持双指缩放、双击切换 1x/2x、下滑关闭与单击关闭。
/// 入场时先展示已有降采样图（零等待），后台按 ``PreviewLoadPolicy``
/// 异步加载高清图后 crossfade 替换。
public final class InkImagePreviewController: UIViewController {

  // MARK: - Properties

  private let source: ImageSource
  private let displayImage: UIImage
  private let loader: InkImageLoading?
  private let previewPolicy: PreviewLoadPolicy

  private var highResTask: Task<Void, Never>?
  private var highResGeneration = UUID()

  // MARK: - Views

  private let scrollView: UIScrollView = {
    let sv = UIScrollView()
    sv.minimumZoomScale = 1.0
    sv.maximumZoomScale = 3.0
    sv.showsHorizontalScrollIndicator = false
    sv.showsVerticalScrollIndicator = false
    sv.backgroundColor = .clear
    return sv
  }()

  private let imageView: UIImageView = {
    let iv = UIImageView()
    iv.contentMode = .scaleAspectFit
    iv.clipsToBounds = true
    return iv
  }()

  private let backgroundView: UIView = {
    let v = UIView()
    v.backgroundColor = .black
    return v
  }()

  // MARK: - Init

  /// 创建全屏图片预览控制器。
  ///
  /// - Parameters:
  ///   - source: 图片来源，用于后台加载高清图。
  ///   - displayImage: 已有的降采样图，入场立即展示。
  ///   - rendering: 图片配置；为 nil 时仅展示 displayImage，提供时复用完整后端。
  ///   - previewPolicy: 高清解码与缓存策略。
  public init(
    source: ImageSource,
    displayImage: UIImage,
    rendering: InkImageRendering? = nil,
    previewPolicy: PreviewLoadPolicy = .init()
  ) {
    self.source = source
    self.displayImage = displayImage
    self.loader = rendering.map { InkImageStore().loader(for: $0, source: source) }
    self.previewPolicy = previewPolicy
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .overFullScreen
    modalTransitionStyle = .crossDissolve
  }

  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Status Bar

  public override var preferredStatusBarStyle: UIStatusBarStyle {
    .lightContent
  }

  // MARK: - Lifecycle

  public override func viewDidLoad() {
    super.viewDidLoad()
    setupViews()
    setupGestures()
    imageView.image = displayImage
    loadHighResImage()
  }

  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    backgroundView.frame = view.bounds
    scrollView.frame = view.bounds
    centerImageInScrollView()
  }

  // MARK: - Setup

  private func setupViews() {
    view.addSubview(backgroundView)
    view.addSubview(scrollView)
    scrollView.addSubview(imageView)
    scrollView.delegate = self

    let screenSize = view.bounds.size
    let imageSize = displayImage.size
    guard imageSize.width > 0, imageSize.height > 0 else { return }

    let widthRatio = screenSize.width / imageSize.width
    let heightRatio = screenSize.height / imageSize.height
    let fitRatio = min(widthRatio, heightRatio)
    let fittedSize = CGSize(
      width: imageSize.width * fitRatio,
      height: imageSize.height * fitRatio
    )

    imageView.frame = CGRect(origin: .zero, size: fittedSize)
    scrollView.contentSize = fittedSize
  }

  private func setupGestures() {
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    tap.numberOfTapsRequired = 1
    view.addGestureRecognizer(tap)

    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
    doubleTap.numberOfTapsRequired = 2
    view.addGestureRecognizer(doubleTap)
    tap.require(toFail: doubleTap)

    let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    pan.delegate = self
    view.addGestureRecognizer(pan)
  }

  // MARK: - 手势处理

  @objc private func handleTap() {
    dismissPreview()
  }

  @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
    if scrollView.zoomScale > scrollView.minimumZoomScale {
      scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
    } else {
      let point = gesture.location(in: imageView)
      let zoomRect = CGRect(
        x: point.x - scrollView.bounds.width / 4,
        y: point.y - scrollView.bounds.height / 4,
        width: scrollView.bounds.width / 2,
        height: scrollView.bounds.height / 2
      )
      scrollView.zoom(to: zoomRect, animated: true)
    }
  }

  private var panStartCenter: CGPoint = .zero

  @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    guard scrollView.zoomScale <= scrollView.minimumZoomScale else { return }

    let translation = gesture.translation(in: view)

    switch gesture.state {
    case .began:
      panStartCenter = imageView.center
    case .changed:
      let progress = max(0, translation.y) / view.bounds.height
      imageView.center = CGPoint(
        x: panStartCenter.x + translation.x,
        y: panStartCenter.y + translation.y
      )
      backgroundView.alpha = 1 - progress * 0.5
      let scale = max(0.8, 1 - progress * 0.3)
      imageView.transform = CGAffineTransform(scaleX: scale, y: scale)
    case .ended, .cancelled:
      let velocity = gesture.velocity(in: view)
      if translation.y > 100 || velocity.y > 500 {
        dismissPreview()
      } else {
        UIView.animate(withDuration: 0.25) {
          self.imageView.center = self.panStartCenter
          self.imageView.transform = .identity
          self.backgroundView.alpha = 1
        }
      }
    default:
      break
    }
  }

  // MARK: - 高清图加载

  private func loadHighResImage() {
    guard let loader else { return }

    let metrics = InkDisplayMetrics.resolve(for: view)
    let zoomCap = scrollView.maximumZoomScale
    let maxPixel = min(
      max(metrics.bounds.width, metrics.bounds.height) * metrics.scale * zoomCap,
      previewPolicy.maxPreviewPixel
    )
    let display = DisplayContext(
      maxPixelWidth: maxPixel,
      scale: metrics.scale,
      contentMode: .fit
    )

    let generation = UUID()
    highResGeneration = generation
    highResTask = Task { [weak self, source, loader, display] in
      do {
        let highResImage = try await loader.loadImage(source: source, display: display)
        guard !Task.isCancelled else { return }
        await MainActor.run { [weak self] in
          guard let self, self.highResGeneration == generation else { return }
          self.applyHighResImage(highResImage)
        }
      } catch {
        // 高清图加载失败不影响预览，继续使用降采样图
      }
    }
  }

  @MainActor
  private func applyHighResImage(_ image: UIImage) {
    UIView.transition(
      with: imageView,
      duration: 0.3,
      options: .transitionCrossDissolve
    ) { [weak self] in
      self?.imageView.image = image
    }
  }

  // MARK: - Dismiss

  private func dismissPreview() {
    cancelHighResTask()
    imageView.image = nil

    UIView.animate(withDuration: 0.25, animations: {
      self.backgroundView.alpha = 0
      self.imageView.alpha = 0
      self.imageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }) { _ in
      self.dismiss(animated: false)
    }
  }

  private func cancelHighResTask() {
    highResTask?.cancel()
    highResTask = nil
    highResGeneration = UUID()
  }

  public override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // Covers interactive and host-triggered dismiss paths that bypass dismissPreview().
    cancelHighResTask()
  }

  // MARK: - Image Centering

  private func centerImageInScrollView() {
    let boundsSize = scrollView.bounds.size
    let contentSize = scrollView.contentSize

    let offsetX = max(0, (boundsSize.width - contentSize.width) / 2)
    let offsetY = max(0, (boundsSize.height - contentSize.height) / 2)

    imageView.center = CGPoint(
      x: contentSize.width / 2 + offsetX,
      y: contentSize.height / 2 + offsetY
    )
  }

  deinit {
    highResTask?.cancel()
  }

  // MARK: - 公开 API

  /// 从指定控制器 present 本预览（`overFullScreen` + `crossDissolve`）。
  ///
  /// - Parameter viewController: 发起 present 的宿主控制器。
  public func present(from viewController: UIViewController) {
    viewController.present(self, animated: true)
  }
}

// MARK: - UIScrollViewDelegate

extension InkImagePreviewController: UIScrollViewDelegate {
  public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    imageView
  }

  public func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerImageInScrollView()
  }
}

// MARK: - UIGestureRecognizerDelegate

extension InkImagePreviewController: UIGestureRecognizerDelegate {
  public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
    let velocity = pan.velocity(in: view)
    // 只在向下拖拽时触发
    return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
  }

  public func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    false
  }
}
