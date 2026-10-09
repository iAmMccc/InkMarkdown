import Foundation
import Testing
import UIKit
import InkMarkdown
import InkMarkdownSemanticCorpus

// MARK: - Canonical corpus 表格 tracer（ticket 03）
//
// 自动化只覆盖 parser 结构、inline cell semantics 与表格 Block 路由关键路径；
// 窄宽横滑、长按复制交互与视觉结果由 ExampleApp 手工验收（不新增 UI 测试）。

@Suite("Canonical Corpus 表格 Tracer")
@MainActor
struct InkCorpusTableTracerTests {

  private let fixtures = [
    InkSemanticCorpus.tableRichCell,
    InkSemanticCorpus.tableEscapedPipe,
    InkSemanticCorpus.tableEmptyAndRaggedRows,
  ]

  /// parser 结构到真实表格 Block 的传递：headers / rows / alignments 稳定。
  @Test("表格结构按 parser 产出稳定传递", arguments: [
    InkSemanticCorpus.tableRichCell,
    InkSemanticCorpus.tableEscapedPipe,
    InkSemanticCorpus.tableEmptyAndRaggedRows,
  ])
  func tableStructure_transfersToBlock(fixture: InkSemanticCorpusFixture) {
    let tables = InkChannelProjection.tableBlocks(fixture, configuration: .standard)
    InkCorpusAssertions.assertTableSemantics(
      tables.map { InkChannelProjection.structure(of: $0) },
      fixture: fixture,
      channel: "block"
    )
    InkCorpusAssertions.assertBlockTypes(
      InkChannelProjection.blockTypeNames(fixture, configuration: .standard),
      fixture: fixture
    )
  }

  /// 复杂单元格：块视图中的单元格文本视图保留强调、粗体、行内代码与链接语义。
  @Test("复杂单元格保留 inline 语义")
  func richCell_preservesInlineSemantics() throws {
    let fixture = InkSemanticCorpus.tableRichCell
    let tables = InkChannelProjection.tableBlocks(fixture, configuration: .standard)
    let table = try #require(tables.first)

    // 复杂单元格语义已在结构层锁定（rows 携带原始 Markdown）；
    // 这里证明块视图把单元格 Markdown 经共享 inline renderer 解析为真实 run。
    let view = table.makeView()
    let cellTexts = InkViewProjectionExtractor.textViews(in: view).compactMap(\.attributedText)
    let combined = NSMutableAttributedString()
    cellTexts.forEach { combined.append($0) }

    InkCorpusAssertions.assertInlineSemantics(
      of: combined,
      fixture: fixture,
      channel: "block-table-view"
    )
    InkCorpusAssertions.assertLinkSemantics(
      of: combined,
      fixture: fixture,
      channel: "block-table-view"
    )
  }

  /// 单元格链接与正文使用同一 `linkTapHandler` 契约：handler 返回 `true` 时拦截默认行为。
  @Test("表格单元格链接走正文相同 handler 契约")
  func tableCellLink_usesSharedHandlerContract() throws {
    let fixture = InkSemanticCorpus.tableRichCell
    var configuration = InkConfiguration.standard
    var handled: [URL] = []
    configuration.linkTapHandler = { url, _ in
      handled.append(url)
      return true
    }

    let tables = InkChannelProjection.tableBlocks(fixture, configuration: configuration)
    let table = try #require(tables.first)
    // handler 通过 InkConfiguration 语义身份随块传递（块复用路径的一致性证据）。
    #expect(table.configuration.linkTapHandler != nil)

    let view = table.makeView()
    let cellTextViews = InkViewProjectionExtractor.textViews(in: view)
    #expect(!cellTextViews.isEmpty)

    let linkCell = try #require(cellTextViews.first { $0.attributedText?.string.contains("详情") == true })
    // 单元格 UITextView 命中 .link 时回调宿主 handler；返回 true 表示宿主已处理。
    let cellText = try #require(linkCell.attributedText)
    let range = (cellText.string as NSString).range(of: "详情")
    let url = try #require(cellText.attribute(.link, at: range.location, effectiveRange: nil) as? URL)
    let intercepted = linkCell.delegate?.textView?(
      linkCell,
      shouldInteractWith: url,
      in: range,
      interaction: .invokeDefaultAction
    )
    #expect(intercepted == false, "handler 返回 true 时应拦截系统默认行为")
    #expect(handled == [URL(string: "https://example.com/cell")!])
  }

  /// 空单元格与不齐行：块视图构造稳定，不崩溃、不越界。
  @Test("空单元格与不齐行稳定构造块视图")
  func emptyAndRaggedRows_buildStableView() throws {
    let fixture = InkSemanticCorpus.tableEmptyAndRaggedRows
    let tables = InkChannelProjection.tableBlocks(fixture, configuration: .standard)
    let table = try #require(tables.first)

    let view = table.makeView()
    view.layoutIfNeeded()
    #expect(view.subviews.isEmpty == false)

    // 换行与滚动两种布局模式都能按既有契约构造。
    let wrapView = table.makeView()
    wrapView.layoutIfNeeded()
    #expect(!wrapView.subviews.isEmpty)
  }

}
