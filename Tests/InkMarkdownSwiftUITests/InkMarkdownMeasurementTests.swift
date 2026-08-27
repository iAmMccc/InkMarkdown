//
//  InkMarkdownMeasurementTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("InkMarkdownContainerView 单次测量契约")
@MainActor
struct InkMarkdownMeasurementTests {

  @Test("同一宽度连续 sizeThatFits 子视图测量次数不超过块数")
  func consecutiveMeasureReusesCache() {
    let width: CGFloat = 360
    let blocks: [InkRenderableBlock] = [
      InkCodeBlock(code: "let x = 1", language: "swift"),
      InkThematicBreakBlock(),
      InkTableBlock(
        headers: ["A", "B"],
        rows: [["1", "2"]],
        alignments: [.left, .left]
      ),
    ]

    let container = InkMarkdownContainerView()
    container.updateBlocks(blocks, configuration: .standard)

    let blockCount = blocks.count
    _ = container.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    let firstPassCount = container.blockMeasurementInvocationCount

    _ = container.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    let secondPassCount = container.blockMeasurementInvocationCount

    #expect(firstPassCount == blockCount)
    #expect(secondPassCount == 0, "第二次同宽测量应复用缓存，不再调用子视图 sizeThatFits")
  }

  @Test("layoutSubviews 内不触发 invalidateIntrinsicContentSize")
  func layoutSubviewsDoesNotInvalidateICS() {
    let width: CGFloat = 360
    let container = InkMarkdownContainerView(frame: CGRect(x: 0, y: 0, width: width, height: 0))
    container.updateBlocks(
      [InkCodeBlock(code: "hello", language: nil)],
      configuration: .standard
    )

    _ = container.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    container.resetLayoutSubviewsICSInvalidateCountForTesting()

    container.frame = CGRect(x: 0, y: 0, width: width, height: 200)
    container.setNeedsLayout()
    container.layoutIfNeeded()

    #expect(container.layoutSubviewsICSInvalidateCount == 0)
  }

  @Test("宽度变化时在 measure 入口重测且 layout 复用高度数组")
  func widthChangeRemeasuresOnceAtMeasureEntry() {
    let container = InkMarkdownContainerView()
    container.updateBlocks(
      [InkCodeBlock(code: "multi\nline\ncode", language: "swift")],
      configuration: .standard
    )

    _ = container.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
    let height320 = container.cachedTotalHeightForTesting

    _ = container.sizeThatFits(CGSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
    let height400 = container.cachedTotalHeightForTesting

    #expect(height320 > 0)
    #expect(height400 > 0)

    container.frame = CGRect(x: 0, y: 0, width: 400, height: height400)
    let measureCountBeforeLayout = container.blockMeasurementInvocationCount
    container.setNeedsLayout()
    container.layoutIfNeeded()
    let measureCountAfterLayout = container.blockMeasurementInvocationCount

    #expect(
      measureCountAfterLayout == measureCountBeforeLayout,
      "layoutSubviews 应复用已缓存的测量结果，不重复 sizeThatFits"
    )
  }
}
