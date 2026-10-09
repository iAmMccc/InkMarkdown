import Foundation
import Testing
import UIKit
@testable import InkMarkdown

@Suite("块级测量宽度契约（禁止猜 320）")
@MainActor
struct InkBlockMeasurementWidthContractTests {

  @Test("resolvedMeasurementWidth：proposal → bounds → 0")
  func resolvedMeasurementWidth_order() {
    #expect(InkDisplayMetrics.resolvedMeasurementWidth(proposal: 375, bounds: 200) == 375)
    #expect(InkDisplayMetrics.resolvedMeasurementWidth(proposal: 0, bounds: 200) == 200)
    #expect(InkDisplayMetrics.resolvedMeasurementWidth(proposal: -1, bounds: 0) == 0)
    #expect(InkDisplayMetrics.resolvedMeasurementWidth(proposal: 0, bounds: 0) == 0)
  }

  @Test("Code / Table / Thematic / Attributed 零宽 sizeThatFits 返回 noIntrinsicMetric")
  func blocks_zeroWidth_returnNoIntrinsicMetric() {
    let configuration = InkConfiguration.standard
    let proposal = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

    let code = InkCodeBlockViewImpl(
      code: "let x = 1",
      language: "swift",
      config: configuration.appearance.codeBlock,
      appearance: configuration.appearance
    )
    let codeSize = code.sizeThatFits(proposal)
    #expect(codeSize.width == UIView.noIntrinsicMetric)
    #expect(codeSize.height == UIView.noIntrinsicMetric)

    let table = InkTableBlockView(
      headerSources: [.raw("A"), .raw("B")],
      rowSources: [[.raw("1"), .raw("2")]],
      alignments: [nil, nil],
      layoutMode: .wrap,
      config: configuration.appearance.table,
      configuration: configuration
    )
    let tableSize = table.sizeThatFits(proposal)
    #expect(tableSize.width == UIView.noIntrinsicMetric)
    #expect(tableSize.height == UIView.noIntrinsicMetric)

    let thematic = InkThematicBreakView(config: configuration.appearance.thematicBreak)
    let thematicSize = thematic.sizeThatFits(proposal)
    #expect(thematicSize.width == UIView.noIntrinsicMetric)
    #expect(thematicSize.height == UIView.noIntrinsicMetric)

    let attributed = InkAttributedBlockTextView(frame: .zero)
    attributed.attributedText = NSAttributedString(string: "hello measurement")
    let attributedSize = attributed.sizeThatFits(proposal)
    #expect(attributedSize.width == UIView.noIntrinsicMetric)
    #expect(attributedSize.height == UIView.noIntrinsicMetric)
  }

  @Test("正宽度 proposal 仍产生有效高度，不依赖硬编码 320")
  func blocks_positiveProposal_measuresHeight() {
    let configuration = InkConfiguration.standard
    let proposal = CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude)

    let code = InkCodeBlockViewImpl(
      code: "print(42)",
      language: nil,
      config: configuration.appearance.codeBlock,
      appearance: configuration.appearance
    )
    let codeSize = code.sizeThatFits(proposal)
    #expect(codeSize.width == 280)
    #expect(codeSize.height > 0)

    let thematic = InkThematicBreakView(config: configuration.appearance.thematicBreak)
    let thematicSize = thematic.sizeThatFits(proposal)
    #expect(thematicSize.width == 280)
    #expect(thematicSize.height > 0)

    let table = InkTableBlockView(
      headerSources: [.raw("A"), .raw("B")],
      rowSources: [[.raw("1"), .raw("2")]],
      alignments: [nil, nil],
      layoutMode: .wrap,
      config: configuration.appearance.table,
      configuration: configuration
    )
    let tableSize = table.sizeThatFits(proposal)
    #expect(tableSize.width == 280)
    #expect(tableSize.height > 0)
  }
}
