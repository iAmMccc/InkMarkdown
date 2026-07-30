import UIKit
import InkMarkdown

/// 块级图片片段：包装 ``InkImageBlock``，使其参与 SSE 逐字吐字进度。
///
/// 图片以「一步显示」参与吐字（`typewriterLength == 1`），进度轮到该片段时整块出现并触发加载。
final class SSEImageSegmentView: UIView, SSETypewriterSegment {

  private let imageBlock: InkImageBlock
  private var lastReportedHeight: CGFloat = 0

  /// 网络图加载/布局变化时回调（D2）。
  var onHeightChange: (() -> Void)?

  init(imageBlock: InkImageBlock) {
    self.imageBlock = imageBlock
    super.init(frame: .zero)
    imageBlock.translatesAutoresizingMaskIntoConstraints = false
    addSubview(imageBlock)
    NSLayoutConstraint.activate([
      imageBlock.topAnchor.constraint(equalTo: topAnchor),
      imageBlock.bottomAnchor.constraint(equalTo: bottomAnchor),
      imageBlock.leadingAnchor.constraint(equalTo: leadingAnchor),
      imageBlock.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
    isHidden = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  // MARK: - SSETypewriterSegment

  var typewriterLength: Int { 1 }

  func setVisibleLength(_ length: Int) {
    isHidden = length < 1
    if length >= 1 {
      setNeedsLayout()
      layoutIfNeeded()
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let height = systemLayoutSizeFitting(
      CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
    guard abs(height - lastReportedHeight) > 0.5 else { return }
    lastReportedHeight = height
    invalidateIntrinsicContentSize()
    onHeightChange?()
  }

  override var intrinsicContentSize: CGSize {
    imageBlock.intrinsicContentSize
  }
}
