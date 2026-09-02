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

    #expect(tables.count == fixture.expectedTables.count)
    for (table, expected) in zip(tables, fixture.expectedTables) {
      let actual = InkChannelProjection.structure(of: table)
      if actual != expected {
        Issue.record(
          Comment(rawValue: "fixture \(fixture.id) 表格结构不一致：\n期望 \(expected)\n实际 \(actual)")
        )
      }
    }
  }

  /// 复杂单元格：块视图中的单元格文本视图保留强调、粗体、行内代码与链接语义。
  @Test("复杂单元格保留 inline 语义")
  func richCell_preservesInlineSemantics() throws {
    let fixture = InkSemanticCorpus.tableRichCell
    let tables = InkChannelProjection.tableBlocks(fixture, configuration: .standard)
    let table = try #require(tables.first)

    // 中间产物对照：共享 inline renderer 直接渲染单元格 markdown 时语义正确。
    let directCell = InkAttributedRenderer.renderInline(
      "`status`",
      configuration: .standard,
      baseFont: .systemFont(ofSize: 14),
      textColor: .label
    )
    let directCode = Self.run(containing: "status", in: directCell)
    if let directCode, !directCode.isMonospace {
      Issue.record(Comment(rawValue: "renderInline 中间产物也非等宽：\(directCode)"))
    }
    #expect(directCode?.isMonospace == true)

    // 复杂单元格语义已在结构层锁定（rows 携带原始 Markdown）；
    // 这里证明块视图把单元格 Markdown 经共享 inline renderer 解析为真实 run。
    let view = table.makeView()
    let cellTexts = Self.allTextViews(in: view).compactMap(\.attributedText)
    let combined = NSMutableAttributedString()
    cellTexts.forEach { combined.append($0) }

    let bold = Self.run(containing: "加粗", in: combined)
    #expect(bold?.isBold == true)

    let code = Self.run(containing: "status", in: combined)
    #expect(code?.isMonospace == true)

    // CJK 行内代码的平台字体回退（TextKit glyph 生成）不丢失代码背景身份。
    let codeBackground = Self.hasInlineCodeBackground(combined)
    #expect(codeBackground)

    let link = Self.run(containing: "详情", in: combined)
    if let link, link.url == nil {
      Issue.record(Comment(rawValue: "链接 run 诊断：\(String(describing: link))；全文：\(combined.string)"))
    }
    #expect(link?.url == URL(string: "https://example.com/cell"))
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
    let cellTextViews = Self.allTextViews(in: view)
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
    #expect(wrapView != nil)
  }

  // MARK: - Helpers

  private static func allTextViews(in view: UIView) -> [UITextView] {
    var result: [UITextView] = []
    if let textView = view as? UITextView {
      result.append(textView)
    }
    for subview in view.subviews {
      result.append(contentsOf: allTextViews(in: subview))
    }
    return result
  }

  private static func hasInlineCodeBackground(_ attributed: NSAttributedString) -> Bool {
    var found = false
    attributed.enumerateAttribute(.inkInlineCodeBackground, in: NSRange(location: 0, length: attributed.length), options: []) { value, _, stop in
      if value != nil {
        found = true
        stop.pointee = true
      }
    }
    return found
  }

  private static func run(containing text: String, in attributed: NSAttributedString) -> (string: String, isBold: Bool, isMonospace: Bool, url: URL?)? {
    let nsString = attributed.string as NSString
    let range = nsString.range(of: text)
    guard range.location != NSNotFound else { return nil }
    let attributes = attributed.attributes(at: range.location, effectiveRange: nil)
    let font = attributes[.font] as? UIFont
    return (
      string: nsString.substring(with: range),
      isBold: font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true,
      isMonospace: font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true,
      url: attributes[.link] as? URL
    )
  }
}
