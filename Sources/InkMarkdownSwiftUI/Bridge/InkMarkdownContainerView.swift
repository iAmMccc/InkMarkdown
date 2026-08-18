//
//  InkMarkdownContainerView.swift
//  InkMarkdownSwiftUI
//

import UIKit
import InkMarkdown

/// 承载 Markdown 块级视图的 UIKit 容器视图。
///
/// 采用 frame 布局，并通过 `sizeThatFits` 与 `intrinsicContentSize` 向 SwiftUI
/// 提供 iOS 14–15 所需的尺寸协商依据。
final class InkMarkdownContainerView: UIView {

  private var blockViews: [UIView] = []
  private var currentConfiguration: InkConfiguration?
  private var lastLayoutWidth: CGFloat = 0

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = .clear
  }

  /// 当前容器中是否存在已创建的块级视图。
  var hasBlocks: Bool {
    !blockViews.isEmpty
  }

  /// 更新待渲染的块列表及配置。
  /// - Parameters:
  ///   - blocks: 块级渲染单元数组。
  ///   - configuration: 当前生效的 Markdown 渲染配置。
  func updateBlocks(_ blocks: [InkRenderableBlock], configuration: InkConfiguration) {
    blockViews.forEach { $0.removeFromSuperview() }
    blockViews.removeAll()
    currentConfiguration = configuration

    for block in blocks {
      let view = block.makeView()
      addSubview(view)
      blockViews.append(view)
    }

    setNeedsLayout()
    invalidateIntrinsicContentSize()
  }

  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: calculateHeight(for: resolvedWidth))
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let width = size.width > 0 ? size.width : resolvedWidth
    return CGSize(width: width, height: calculateHeight(for: width))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    let width = bounds.width
    guard width > 0 else { return }

    lastLayoutWidth = width
    layoutBlocks(for: width)
  }

  // MARK: - Private Helpers

  private var resolvedWidth: CGFloat {
    if bounds.width > 0 {
      return bounds.width
    }
    if let superviewWidth = superview?.bounds.width, superviewWidth > 0 {
      return superviewWidth
    }
    // 首次测量尚无父容器宽度时的临时值；后续 layout 会按实际宽度重新失效尺寸。
    return 320
  }

  private func calculateHeight(for width: CGFloat) -> CGFloat {
    guard !blockViews.isEmpty else {
      return subviews.map {
        $0.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
      }.max() ?? 0
    }

    let measurements = measuredBlocks(for: width)
    return measurements.reduce(CGFloat.zero) { $0 + $1.size.height }
  }

  private func layoutBlocks(for width: CGFloat) {
    guard !blockViews.isEmpty else {
      for subview in subviews {
        let size = subview.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        subview.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
      }
      return
    }

    var y: CGFloat = 0
    let measurements = measuredBlocks(for: width)
    for measurement in measurements {
      measurement.view.frame = CGRect(x: 0, y: y, width: width, height: measurement.size.height)
      y += measurement.size.height
    }
  }

  private func measuredBlocks(for width: CGFloat) -> [(view: UIView, size: CGSize)] {
    blockViews.map { view in
      (view, view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)))
    }
  }
}

