import Testing
import UIKit
@testable import InkMarkdown

@Suite("InkTablePresentation 单元格来源契约")
@MainActor
struct InkTablePresentationTests {

  @Test("raw 接纳一次后测量与建行不重复 filter")
  func rawCells_filterOnceAcrossMeasureAndMakeRow() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    var filterCallCount = 0
    configuration.setSourceFilter(
      { source in
        filterCallCount += 1
        return source.replacingOccurrences(of: "@@", with: "@")
      },
      semanticIdentity: "table-presentation-raw-once"
    )

    let sources: [InkTableCellSource] = [.raw("@@@a"), .raw("@@@b")]
    let cells = sources.accepted(using: configuration)
    #expect(filterCallCount == 2)

    let widths = InkTableRenderHelper.measureColumnContentWidths(
      headers: cells,
      rows: [cells],
      config: configuration.appearance.table,
      configuration: configuration,
      containerWidth: 744
    )
    #expect(widths.count == 2)
    #expect(filterCallCount == 2)

    let row = UIView()
    InkTableRenderHelper.makeRow(
      cells: cells,
      isHeader: false,
      widthMode: .ratio([0.5, 0.5]),
      alignments: [],
      config: configuration.appearance.table,
      configuration: configuration,
      rowContainer: row
    )
    #expect(filterCallCount == 2)

    let texts = textViews(in: row).map(\.attributedText.string)
    #expect(texts.contains { $0.contains("@@a") })
    #expect(!texts.contains { $0.contains("@@@") })
  }

  @Test("显式新 replace 可重新接纳 raw；不按字符串跨生命周期去重")
  func rawCells_newReplaceReaccepts() {
    var configuration = InkConfiguration.standard
    var filterCallCount = 0
    configuration.setSourceFilter(
      { source in
        filterCallCount += 1
        return source.replacingOccurrences(of: "@@", with: "@")
      },
      semanticIdentity: "table-presentation-raw-replace"
    )

    let first = [InkTableCellSource.raw("@@@same")].accepted(using: configuration)
    #expect(filterCallCount == 1)
    let second = [InkTableCellSource.raw("@@@same")].accepted(using: configuration)
    #expect(filterCallCount == 2)
    #expect(first == second)
  }

  @Test("prepared Markup 派生 cell 接纳计数为零且保留原文 fallback")
  func preparedCells_skipFilterAndKeepOriginalFallback() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    var filterCallCount = 0
    configuration.setSourceFilter(
      { source in
        filterCallCount += 1
        return source.replacingOccurrences(of: "@@", with: "@")
      },
      semanticIdentity: "table-presentation-prepared-skip"
    )

    let prepared = InkPreparedMarkdownSource(preparedValue: "@@user")
    let cell = InkTableCellSource.prepared(original: "@@@user", source: prepared)
      .accepted(using: configuration)
    #expect(filterCallCount == 0)
    #expect(cell.original == "@@@user")
    #expect(cell.prepared.value == "@@user")

    _ = InkTableRenderHelper.measureColumnContentWidths(
      headers: [cell],
      rows: [],
      config: configuration.appearance.table,
      configuration: configuration,
      containerWidth: 320
    )
    let row = UIView()
    InkTableRenderHelper.makeRow(
      cells: [cell],
      isHeader: true,
      widthMode: .fixed([120]),
      alignments: [],
      config: configuration.appearance.table,
      configuration: configuration,
      rowContainer: row
    )
    #expect(filterCallCount == 0)
    #expect(textViews(in: row).contains { $0.attributedText.string.contains("@@user") })
  }

  @Test("顶层 renderer prepared 表格 cell 不增加 filter 计数")
  func topLevelPreparedTable_filterOnceOnly() throws {
    var configuration = InkConfiguration.standard
    var filterCallCount = 0
    configuration.setSourceFilter(
      { source in
        filterCallCount += 1
        return source.replacingOccurrences(of: "@@", with: "@")
      },
      semanticIdentity: "table-presentation-top-level"
    )

    let source = "| User |\n| --- |\n| @@@user |"
    let blocks = InkBlockRenderer.render(source, configuration: configuration)
    let table = try #require(blocks.compactMap { $0 as? InkTableBlock }.first)
    #expect(filterCallCount == 1)

    let view = table.makeView()
    view.frame = CGRect(x: 0, y: 0, width: 744, height: 400)
    view.setNeedsLayout()
    view.layoutIfNeeded()
    #expect(filterCallCount == 1)
    #expect(textViews(in: view).contains { $0.attributedText.string.contains("@@user") })

    #expect(table.updateExistingView(view))
    view.frame.size.width = 375
    view.setNeedsLayout()
    view.layoutIfNeeded()
    #expect(filterCallCount == 1)
  }

  @Test("流式 2+2+2 cell 精确计数 6，重建不增加")
  func streamSixCells_exactFilterCount() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    var filterCallCount = 0
    configuration.setSourceFilter(
      { source in
        filterCallCount += 1
        return source.replacingOccurrences(of: "@@", with: "@")
      },
      semanticIdentity: "table-presentation-stream-six"
    )

    let stream = InkStreamTableView(layoutMode: .wrap, configuration: configuration)
    stream.setHeaders(["H@@@1", "H@@@2"], referenceRows: [["R@@@1", "R@@@2"]])
    stream.appendRow(["B@@@1", "B@@@2"])
    #expect(filterCallCount == 6)

    stream.frame = CGRect(x: 0, y: 0, width: 744, height: 400)
    stream.setNeedsLayout()
    stream.layoutIfNeeded()
    stream.frame.size.width = 375
    stream.setNeedsLayout()
    stream.layoutIfNeeded()
    #expect(filterCallCount == 6)
  }

  @Test("raw static 每 replace 每 cell 一次，resize 不增；显式 apply 可重新接纳")
  func rawStaticTable_filterOncePerReplace_resizeSafe() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    var filterCallCount = 0
    configuration.setSourceFilter(
      { source in
        filterCallCount += 1
        return source.replacingOccurrences(of: "@@", with: "@")
      },
      semanticIdentity: "table-presentation-raw-static"
    )

    let block = InkTableBlock(
      headers: ["H@@@1", "H@@@2"],
      rows: [["B@@@1", "B@@@2"]],
      alignments: [],
      layoutMode: .wrap,
      configuration: configuration
    )
    let view = block.makeView()
    #expect(filterCallCount == 4)
    view.frame = CGRect(x: 0, y: 0, width: 744, height: 400)
    view.setNeedsLayout()
    view.layoutIfNeeded()
    view.frame.size.width = 375
    view.setNeedsLayout()
    view.layoutIfNeeded()
    #expect(filterCallCount == 4)
    #expect(textViews(in: view).contains { $0.attributedText.string.contains("@@1") })

    #expect(block.updateExistingView(view))
    #expect(filterCallCount == 8)
  }

  private func textViews(in root: UIView) -> [UITextView] {
    root.subviews.flatMap { child -> [UITextView] in
      let matches = child is UITextView ? [child as! UITextView] : []
      return matches + textViews(in: child)
    }
  }
}

@Suite("InkTablePresentation 布局状态契约")
@MainActor
struct InkTablePresentationLayoutTests {

  @Test("wrap 宽窄恢复保留 reference 对首列影响；scroll 自然宽稳定")
  func layout_wrapRestoresReferenceInfluence_scrollKeepsNaturalWidth() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    let long = String(repeating: "REF长样本列内容", count: 20)

    var wrap = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    let wrapSnap = wrap.setHeaders(
      [.raw("名称"), .raw("说明")],
      referenceRows: [[.raw(long), .raw("短")]],
      contentWidth: 744
    )!
    _ = wrap.appendRow([.raw("短"), .raw("短")], contentWidth: 744)
    #expect(wrap.rows.count == 1)
    #expect(!wrap.rows.flatMap { $0.map(\.original) }.contains(where: { $0.contains("REF") }))

    let wrapWide = wrap.layout(contentWidth: 744).columnWidths[0]
    let wrapNarrow = wrap.layout(contentWidth: 375).columnWidths[0]
    let wrapRestored = wrap.layout(contentWidth: 744).columnWidths[0]
    #expect(wrapWide > wrapNarrow)
    #expect(wrapRestored > wrapNarrow)
    #expect(abs(wrapRestored - wrapWide) < 0.5)

    var control = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    _ = control.setHeaders(
      [.raw("名称"), .raw("说明")],
      referenceRows: [[.raw("短"), .raw("短")]],
      contentWidth: 744
    )
    _ = control.appendRow([.raw("短"), .raw("短")], contentWidth: 744)
    let controlWide = control.layout(contentWidth: 744).columnWidths[0]
    #expect(wrapRestored > controlWide)

    var scroll = InkTablePresentation(layoutMode: .scroll, configuration: configuration)
    _ = scroll.setHeaders(
      [.raw("名称"), .raw("说明")],
      referenceRows: [[.raw(long), .raw("短")]],
      contentWidth: 744
    )
    _ = scroll.appendRow([.raw("短"), .raw("短")], contentWidth: 744)
    let scrollWide = scroll.layout(contentWidth: 744).columnWidths
    let scrollNarrow = scroll.layout(contentWidth: 375).columnWidths
    #expect(scrollWide.count == scrollNarrow.count)
    for (wide, narrow) in zip(scrollWide, scrollNarrow) {
      #expect(abs(wide - narrow) < 0.5)
    }
    #expect(wrapSnap.headers.count == 2)
  }

  @Test("同内容静态一次接纳与逐行接纳列宽等价")
  func layout_staticAndStreamProduceEquivalentColumnWidths() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    let headers: [InkTableCellSource] = [.raw("A"), .raw("B")]
    let body: [[InkTableCellSource]] = [
      [.raw(String(repeating: "长内容", count: 6)), .raw("短")],
      [.raw("中"), .raw(String(repeating: "另一列长", count: 4))],
    ]

    var staticPresentation = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    let staticSnap = staticPresentation.replace(
      headers: headers,
      rows: body,
      contentWidth: 640
    )

    var stream = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    _ = stream.setHeaders(headers, referenceRows: body, contentWidth: 640)
    for row in body {
      _ = stream.appendRow(row, contentWidth: 640)
    }
    let streamSnap = stream.layout(contentWidth: 640)

    #expect(staticSnap.columnWidths.count == streamSnap.columnWidths.count)
    for (lhs, rhs) in zip(staticSnap.columnWidths, streamSnap.columnWidths) {
      #expect(abs(lhs - rhs) < 0.5)
    }
  }

  @Test("短行 append 不要求全量重建，更长行按需重建")
  func layout_shortAppendAvoidsRebuild_longAppendRebuilds() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false

    var presentation = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    _ = presentation.setHeaders(
      [.raw("Col"), .raw("Other")],
      referenceRows: [[.raw("基准宽度样本"), .raw("短")]],
      contentWidth: 700
    )

    let short = presentation.appendRow([.raw("短"), .raw("短")], contentWidth: 700)
    #expect(short?.update == .appendRow)
    #expect(presentation.rows.count == 1)

    let long = presentation.appendRow(
      [.raw(String(repeating: "超长追加触发扩列", count: 12)), .raw("短")],
      contentWidth: 700
    )
    #expect(long?.update == .fullRebuild)
    #expect(presentation.rows.count == 2)
  }
}
