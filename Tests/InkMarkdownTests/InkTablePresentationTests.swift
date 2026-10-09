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

  @Test("追加列数多于表头的 ragged row 时，若已知列未超出列宽，update 保持为 appendRow")
  func layout_raggedRowWithMoreColumnsThanHeaders_retainsAppendRowIfKnownColumnsFit() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false

    var presentation = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    _ = presentation.setHeaders(
      [.raw("Col1"), .raw("Col2")],
      referenceRows: [[.raw("基准宽度样本很长"), .raw("第二列基准样本")]],
      contentWidth: 700
    )

    // 追加一行有 4 列的 ragged row，但前两列内容较短，未超出已知列宽；第 3、4 列为超出列
    let raggedRow: [InkTableCellSource] = [
      .raw("短1"),
      .raw("短2"),
      .raw("超出的第三列超长内容也不会影响"),
      .raw("超出的第四列")
    ]
    let snapshot = presentation.appendRow(raggedRow, contentWidth: 700)
    #expect(snapshot?.update == .appendRow)
    #expect(presentation.rows.count == 1)

    // 若已知列（如第 1 列）超出列宽，则仍应触发 fullRebuild
    let expandingRaggedRow: [InkTableCellSource] = [
      .raw(String(repeating: "已知第一列超长追加触发扩列", count: 12)),
      .raw("短2"),
      .raw("超出行")
    ]
    let rebuildSnapshot = presentation.appendRow(expandingRaggedRow, contentWidth: 700)
    #expect(rebuildSnapshot?.update == .fullRebuild)
    #expect(presentation.rows.count == 2)
  }

  @Test("自定义 Table config 生效且以传入 config 为准")
  func layout_customTableConfigAppliesToMeasurement() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    let standardConfig = configuration.appearance.table

    var customConfig = standardConfig
    customConfig.horizontalPadding = 48
    customConfig.headerFontSize = 28
    customConfig.lineHeight = 36

    let headers: [InkTableCellSource] = [.raw("标题A"), .raw("标题B")]
    let rows: [[InkTableCellSource]] = [[.raw("内容1"), .raw("内容2")]]

    var defaultPresentation = InkTablePresentation(
      layoutMode: .scroll,
      configuration: configuration
    )
    let defaultSnap = defaultPresentation.replace(
      headers: headers,
      rows: rows,
      contentWidth: 600
    )

    var customPresentation = InkTablePresentation(
      layoutMode: .scroll,
      config: customConfig,
      configuration: configuration
    )
    let customSnap = customPresentation.replace(
      headers: headers,
      rows: rows,
      contentWidth: 600
    )

    #expect(customSnap.columnWidths.count == defaultSnap.columnWidths.count)
    for (customW, defaultW) in zip(customSnap.columnWidths, defaultSnap.columnWidths) {
      // 增大 horizontalPadding 和 headerFontSize 后测量列宽应显著大于默认配置
      #expect(customW > defaultW)
    }

    // 同时验证 InkTableBlockView 初始化与 apply 均以自定义 config 初始化 presentation
    let blockView = InkTableBlockView(
      headerSources: headers,
      rowSources: rows,
      alignments: [],
      layoutMode: .scroll,
      config: customConfig,
      configuration: configuration
    )
    let size = blockView.sizeThatFits(CGSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
    #expect(size.width == 600)
    #expect(size.height > customConfig.verticalInset)

    let defaultBlockView = InkTableBlockView(
      headerSources: headers,
      rowSources: rows,
      alignments: [],
      layoutMode: .scroll,
      config: standardConfig,
      configuration: configuration
    )
    let defaultSize = defaultBlockView.sizeThatFits(CGSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
    #expect(size.height > defaultSize.height)
  }

  @Test("scroll 模式超宽表格调用 sizeThatFits 正常计算且列宽不被强行截断")
  func tableBlockView_scrollModeSizeThatFitsAvoidsConstraintConflictAndWidthClipping() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    let config = configuration.appearance.table

    // 构造包含多个宽列的超宽表格
    let headers: [InkTableCellSource] = (1...6).map { .raw("极长表格列标题 \($0)") }
    let rows: [[InkTableCellSource]] = [
      (1...6).map { .raw("超宽数据单元格内容描述 \($0)") }
    ]

    let blockView = InkTableBlockView(
      headerSources: headers,
      rowSources: rows,
      alignments: [],
      layoutMode: .scroll,
      config: config,
      configuration: configuration
    )

    // 提供较小 targetWidth（200pt），而实际各列固定宽度和远超 200pt
    let narrowTargetWidth: CGFloat = 200
    let size = blockView.sizeThatFits(CGSize(width: narrowTargetWidth, height: CGFloat.greatestFiniteMagnitude))

    // 宿主获得有效高度，且计算无异常/无崩溃
    #expect(size.width == narrowTargetWidth)
    #expect(size.height > config.verticalInset)

    // 对比 wrap 模式：确保 wrap 模式正常计算
    let wrapView = InkTableBlockView(
      headerSources: headers,
      rowSources: rows,
      alignments: [],
      layoutMode: .wrap,
      config: config,
      configuration: configuration
    )
    let wrapSize = wrapView.sizeThatFits(CGSize(width: narrowTargetWidth, height: CGFloat.greatestFiniteMagnitude))
    #expect(wrapSize.width == narrowTargetWidth)
    #expect(wrapSize.height > 0)
    #expect(wrapSize.height > size.height)
  }

  @Test("表格追加分隔行自动忽略且不触发 sourceFilter")
  func tablePresentation_separatorRowDoesNotTriggerSourceFilter() {
    var configuration = InkConfiguration.standard
    var filterCallCount = 0
    configuration.setSourceFilter(
      { source in
        filterCallCount += 1
        return source
      },
      semanticIdentity: "table-separator-check"
    )

    var presentation = InkTablePresentation(
      layoutMode: .wrap,
      config: configuration.appearance.table,
      configuration: configuration
    )

    let headerSources: [InkTableCellSource] = [.raw("Col A"), .raw("Col B")]
    _ = presentation.setHeaders(headerSources, contentWidth: 320)
    let initialCount = filterCallCount
    #expect(initialCount == 2)

    // 追加分隔行
    let separatorRow: [InkTableCellSource] = [.raw("---"), .raw(":---:")]
    let snapshot = presentation.appendRow(separatorRow, contentWidth: 320)

    #expect(snapshot == nil)
    #expect(filterCallCount == initialCount)
    #expect(presentation.rows.count == 0)
  }

  @Test("零宽接纳只保存内容且保持单次 setHeaders；正宽恢复后与直接该宽初始化列宽一致")
  func layout_zeroWidthAccept_recoversConsistentWithDirectInit() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    let headers: [InkTableCellSource] = [.raw("名称"), .raw("说明")]
    let reference: [[InkTableCellSource]] = [[.raw(String(repeating: "参考列长样本", count: 8)), .raw("短")]]
    let body: [InkTableCellSource] = [.raw("短"), .raw("行内容")]
    let recoveredWidth: CGFloat = 640

    var deferred = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    let pendingHeaders = deferred.setHeaders(
      headers,
      referenceRows: reference,
      contentWidth: 0
    )
    #expect(pendingHeaders != nil)
    #expect(pendingHeaders?.hasColumnLayout == false)
    #expect(pendingHeaders?.columnWidths.isEmpty == true)
    #expect(pendingHeaders?.contentWidth == 0)
    #expect(pendingHeaders?.originalHeaders == ["名称", "说明"])
    #expect(deferred.setHeaders(headers, referenceRows: reference, contentWidth: recoveredWidth) == nil)

    let pendingRow = deferred.appendRow(body, contentWidth: 0)
    #expect(pendingRow?.hasColumnLayout == false)
    #expect(pendingRow?.columnWidths.isEmpty == true)
    #expect(deferred.rows.count == 1)
    #expect(deferred.rows[0].map(\.original) == ["短", "行内容"])

    let recovered = deferred.layout(contentWidth: recoveredWidth)
    #expect(recovered.hasColumnLayout)
    #expect(recovered.update == .fullRebuild)
    #expect(recovered.contentWidth == recoveredWidth)

    var direct = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    _ = direct.setHeaders(headers, referenceRows: reference, contentWidth: recoveredWidth)
    _ = direct.appendRow(body, contentWidth: recoveredWidth)
    let directSnap = direct.layout(contentWidth: recoveredWidth)

    #expect(recovered.columnWidths.count == directSnap.columnWidths.count)
    for (lhs, rhs) in zip(recovered.columnWidths, directSnap.columnWidths) {
      #expect(abs(lhs - rhs) < 0.5)
    }
    #expect(InkTableRenderHelper.widthsToRatios(recovered.columnWidths) != [])
    #expect(recovered.originalHeaders == directSnap.originalHeaders)
    #expect(recovered.originalRows == directSnap.originalRows)

    var deferredStatic = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    let pendingStatic = deferredStatic.replace(
      headers: headers,
      rows: [body],
      contentWidth: 0
    )
    #expect(pendingStatic.hasColumnLayout == false)
    let recoveredStatic = deferredStatic.layout(contentWidth: recoveredWidth)
    var directStatic = InkTablePresentation(layoutMode: .wrap, configuration: configuration)
    let directStaticSnap = directStatic.replace(
      headers: headers,
      rows: [body],
      contentWidth: recoveredWidth
    )
    #expect(recoveredStatic.columnWidths.count == directStaticSnap.columnWidths.count)
    for (lhs, rhs) in zip(recoveredStatic.columnWidths, directStaticSnap.columnWidths) {
      #expect(abs(lhs - rhs) < 0.5)
    }
  }

  @Test("未知宽接纳与追加不触发 onHeightChange，恢复后高度与直接该宽初始化一致")
  func streamTable_unknownWidthDoesNotNotifyHeight() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    let recoveredWidth: CGFloat = 640

    let deferred = InkStreamTableView(layoutMode: .wrap, configuration: configuration)
    var deferredHeightNotifications = 0
    deferred.onHeightChange = { deferredHeightNotifications += 1 }
    deferred.setHeaders(
      ["名称", "说明"],
      referenceRows: [[String(repeating: "参考列长样本", count: 8), "短"]],
      contentWidth: 0
    )
    deferred.appendRow(["短", "行内容"], contentWidth: 0)
    #expect(deferredHeightNotifications == 0)
    #expect(deferred.hasColumnLayout == false)
    #expect(deferred.layoutSnapshot?.columnWidths.isEmpty == true)
    #expect(deferred.rowCount == 1)
    #expect(textViews(in: deferred).isEmpty)

    deferred.frame = CGRect(x: 0, y: 0, width: recoveredWidth, height: 10)
    deferred.setNeedsLayout()
    deferred.layoutIfNeeded()
    #expect(deferredHeightNotifications == 0)
    #expect(deferred.hasColumnLayout)
    #expect(deferred.layoutSnapshot?.contentWidth ?? 0 > 0)

    let direct = InkStreamTableView(layoutMode: .wrap, configuration: configuration)
    var directHeightNotifications = 0
    direct.onHeightChange = { directHeightNotifications += 1 }
    direct.frame = CGRect(x: 0, y: 0, width: recoveredWidth, height: 10)
    direct.setNeedsLayout()
    direct.layoutIfNeeded()
    direct.setHeaders(
      ["名称", "说明"],
      referenceRows: [[String(repeating: "参考列长样本", count: 8), "短"]],
      contentWidth: InkTableRenderHelper.contentWidth(for: direct, config: configuration.appearance.table)
    )
    direct.appendRow(
      ["短", "行内容"],
      contentWidth: InkTableRenderHelper.contentWidth(for: direct, config: configuration.appearance.table)
    )
    #expect(directHeightNotifications == 2)
    #expect(direct.hasColumnLayout)

    let recoveredWidths = deferred.layoutSnapshot?.columnWidths ?? []
    let directWidths = direct.layoutSnapshot?.columnWidths ?? []
    #expect(recoveredWidths.count == directWidths.count)
    for (lhs, rhs) in zip(recoveredWidths, directWidths) {
      #expect(abs(lhs - rhs) < 0.5)
    }

    let recoveredHeight = deferred.systemLayoutSizeFitting(
      CGSize(width: recoveredWidth, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
    let directHeight = direct.systemLayoutSizeFitting(
      CGSize(width: recoveredWidth, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
    #expect(abs(recoveredHeight - directHeight) < 1)
  }

  private func textViews(in root: UIView) -> [UITextView] {
    root.subviews.flatMap { child -> [UITextView] in
      let matches = child is UITextView ? [child as! UITextView] : []
      return matches + textViews(in: child)
    }
  }
}
