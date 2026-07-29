import UIKit
import InkMarkdown

/// 块级图片片段：包装 ``InkImageBlock``，使其参与 SSE 逐字吐字进度。
///
/// 图片以「一步显示」参与吐字（`typewriterLength == 1`），进度轮到该片段时整块出现并触发加载。
final class SSEImageSegmentView: UIView, SSETypewriterSegment {

  private let imageBlock: InkImageBlock

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
}
