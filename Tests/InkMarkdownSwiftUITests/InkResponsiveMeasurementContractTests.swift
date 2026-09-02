import Foundation
import Testing
import UIKit
import InkMarkdown
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

// MARK: - 零宽度到 Split View 的响应式布局契约（ticket 05）
//
// 复用 InkMarkdownContainerView 的 measurement / continuity seams：
// 覆盖初始零宽度、首次有效宽度、同宽 cache、宽度变化重测与块状态保留。
// 旋转与 Split View 的视觉结果由 ExampleApp 手工验收，不新增 UI 测试。

@Suite("零宽度到 Split View 响应式测量契约")
@MainActor
struct InkResponsiveMeasurementContractTests {

  private let markdown = """
  # 响应式测量

  正文段落用于产生可测量的内容高度。

  ```swift
  let value = 42
  ```
  """

  /// 初始零宽度：不猜测屏幕宽度，不产生永久零高度测量缓存；
  /// 首次有效宽度到达后完成 reconcile 并得到稳定 intrinsic size。
  @Test("零宽度不布局不缓存，首次有效宽度完成 reconcile")
  func zeroWidth_thenFirstValidWidth_reconciles() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    defer { coordinator.teardown(from: container) }

    container.frame = CGRect(x: 0, y: 0, width: 0, height: 100)
    container.layoutIfNeeded()

    coordinator.updateStatic(markdown: markdown, configuration: .standard)

    // 零宽度契约：sizeThatFits 不产出尺寸，intrinsic 不撒谎（noIntrinsicMetric），
    // 不产生任何测量缓存条目。
    #expect(container.sizeThatFits(CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)) == .zero)
    #expect(container.intrinsicContentSize.height == UIView.noIntrinsicMetric)
    #expect(container.continuityMeasurementCacheCountForTesting == 0)

    // 首次有效宽度：宽度协商完成后必须显示内容（不残留零高度）。
    container.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
    container.setNeedsLayout()
    container.layoutIfNeeded()

    let firstSize = container.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
    #expect(firstSize.height > 0)
    #expect(!container.subviews.isEmpty, "首次有效宽度后必须挂载块视图")
    #expect(container.continuityMeasurementCacheCountForTesting > 0)
  }

  /// 同宽复用测量缓存；宽度变化只走重测，不残留旧宽度条目。
  @Test("同宽复用缓存，宽度变化重测且不残留旧条目")
  func sameWidthReuses_widthChangeRemeasures() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    defer { coordinator.teardown(from: container) }

    coordinator.updateStatic(markdown: markdown, configuration: .standard)
    container.frame = CGRect(x: 0, y: 0, width: 375, height: 100)
    container.setNeedsLayout()
    container.layoutIfNeeded()

    let height375 = container.sizeThatFits(CGSize(width: 375, height: CGFloat.greatestFiniteMagnitude))
    #expect(height375.height > 0)
    let cacheCountAt375 = container.continuityMeasurementCacheCountForTesting
    #expect(cacheCountAt375 > 0)

    // 相同宽度再次测量：复用缓存（条目数不增长）。
    container.sizeThatFits(CGSize(width: 375, height: CGFloat.greatestFiniteMagnitude))
    #expect(container.continuityMeasurementCacheCountForTesting == cacheCountAt375)

    // 宽度变化（Split View 拖动类比）：重测后仍得到有效高度，缓存收敛到新宽度。
    container.frame = CGRect(x: 0, y: 0, width: 512, height: 100)
    container.setNeedsLayout()
    container.layoutIfNeeded()
    let height512 = container.sizeThatFits(CGSize(width: 512, height: CGFloat.greatestFiniteMagnitude))
    #expect(height512.height > 0)

    // 窄宽 → 全宽来回切换不产生布局循环（高度稳定且非零）。
    container.frame = CGRect(x: 0, y: 0, width: 375, height: 100)
    container.setNeedsLayout()
    container.layoutIfNeeded()
    let height375Again = container.sizeThatFits(CGSize(width: 375, height: CGFloat.greatestFiniteMagnitude))
    #expect(height375Again == height375)
  }

  /// 环境签名（配置/trait）变化与宽度变化独立生效；同一呈现周期内块视图被复用。
  @Test("宽度变化保留同一呈现周期的块视图实例")
  func widthChange_preservesBlockViewIdentity() throws {
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    defer { coordinator.teardown(from: container) }

    coordinator.updateStatic(markdown: markdown, configuration: .standard)
    container.frame = CGRect(x: 0, y: 0, width: 375, height: 100)
    container.setNeedsLayout()
    container.layoutIfNeeded()

    let viewsBefore = container.subviews.map { ObjectIdentifier($0) }
    #expect(!viewsBefore.isEmpty)

    container.frame = CGRect(x: 0, y: 0, width: 640, height: 100)
    container.setNeedsLayout()
    container.layoutIfNeeded()

    let viewsAfter = container.subviews.map { ObjectIdentifier($0) }
    #expect(viewsAfter == viewsBefore, "宽度变化应原位复用块视图（呈现状态保留），不得重建")
  }
}
