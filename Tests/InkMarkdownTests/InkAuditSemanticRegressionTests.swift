import Foundation
import Testing
import UIKit
@testable import InkMarkdown

@Suite("项目审核 F04-F09 关键路径回归")
@MainActor
struct InkAuditSemanticRegressionTests {

  @Test("表格列宽测量使用真实内容区宽度")
  func tableMeasurement_usesContainerWidth() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    let table = configuration.appearance.table
    let host = UIView(frame: CGRect(x: 0, y: 0, width: 744, height: 200))
    let wideContentWidth = InkTableRenderHelper.contentWidth(for: host, config: table)
    host.frame.size.width = 375
    let narrowContentWidth = InkTableRenderHelper.contentWidth(for: host, config: table)

    let headers = ["名称", "说明"]
    let rows = [["长标题", String(repeating: "一段足够长的内容", count: 8)]]
    let headerCells = headers.map { InkTableCellSource.raw($0).accepted(using: configuration) }
    let rowCells = rows.map { row in row.map { InkTableCellSource.raw($0).accepted(using: configuration) } }
    let wide = InkTableRenderHelper.measureColumnContentWidths(
      headers: headerCells,
      rows: rowCells,
      config: table,
      configuration: configuration,
      containerWidth: wideContentWidth
    )
    let narrow = InkTableRenderHelper.measureColumnContentWidths(
      headers: headerCells,
      rows: rowCells,
      config: table,
      configuration: configuration,
      containerWidth: narrowContentWidth
    )

    #expect(wideContentWidth > narrowContentWidth)
    #expect(wide != narrow)
  }

  @Test("表格宽度契约区分 wrap 收缩与 scroll viewport")
  func tableViews_rebuildAfterHostWidthChange() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    let headers = ["名称", "说明"]
    // 长内容放在首列，scroll 模式可以用它验证自然内容宽度；末列由 trailing
    // 约束决定，读取末列会混入 row 的 intrinsic 宽度。
    let rows = [[String(repeating: "一段足够长的内容", count: 12), "短"]]

    for layoutMode in [InkTableLayoutMode.wrap, .scroll] {
      let staticBlock = InkTableBlock(
        headers: headers,
        rows: rows,
        alignments: [],
        layoutMode: layoutMode,
        configuration: configuration
      )
      let staticView = staticBlock.makeView()

      let streamView = InkStreamTableView(layoutMode: layoutMode, configuration: configuration)
      streamView.setHeaders(headers, referenceRows: rows)
      streamView.appendRow(rows[0])

      switch layoutMode {
      case .wrap:
        let staticWidths = widthsAfterHostResize(staticView)
        #expect(staticWidths.wide > 0)
        #expect(staticWidths.narrow < staticWidths.wide)
        #expect(staticWidths.restored > staticWidths.narrow)

        let streamWidths = widthsAfterHostResize(streamView)
        #expect(streamWidths.wide > 0)
        #expect(streamWidths.narrow < streamWidths.wide)
        #expect(streamWidths.restored > streamWidths.narrow)

      case .scroll:
        let staticViewport = scrollViewportAfterHostResize(staticView)
        #expect(staticViewport.wide > 0)
        #expect(staticViewport.narrow < staticViewport.wide)
        #expect(staticViewport.restored > staticViewport.narrow)
        #expect(staticViewport.wideContent > staticViewport.wide)
        #expect(abs(staticViewport.narrowContent - staticViewport.wideContent) < 0.5)

        let streamViewport = scrollViewportAfterHostResize(streamView)
        #expect(streamViewport.wide > 0)
        #expect(streamViewport.narrow < streamViewport.wide)
        #expect(streamViewport.restored > streamViewport.narrow)
        #expect(streamViewport.wideContent > streamViewport.wide)
        #expect(abs(streamViewport.narrowContent - streamViewport.wideContent) < 0.5)
      }
    }
  }

  @Test("表格 cell 沿用顶层 prepared source，非幂等 filter 只执行一次")
  func tableCells_preservePreparedSourceBoundary() throws {
    var configuration = InkConfiguration.standard
    var filterCallCount = 0
    configuration.setSourceFilter(
      { source in
        filterCallCount += 1
        return source.replacingOccurrences(of: "@@", with: "@")
      },
      semanticIdentity: "audit-non-idempotent-filter"
    )

    let source = "| User |\n| --- |\n| @@@user |"
    let blocks = InkBlockRenderer.render(source, configuration: configuration)
    let table = try #require(blocks.compactMap { $0 as? InkTableBlock }.first)
    let view = table.makeView()
    view.frame = CGRect(x: 0, y: 0, width: 744, height: 400)
    view.setNeedsLayout()
    view.layoutIfNeeded()

    #expect(filterCallCount == 1)
    #expect(textViews(in: view).contains { $0.attributedText.string.contains("@@user") })
    #expect(!textViews(in: view).contains { $0.attributedText.string == "@user" })

    #expect(table.updateExistingView(view))
    #expect(filterCallCount == 1)
    #expect(textViews(in: view).contains { $0.attributedText.string.contains("@@user") })

    // 尺寸重建仍消费顶层 prepared source，不能再次跑非幂等 filter。
    _ = widthsAfterHostResize(view)
    #expect(filterCallCount == 1)
    #expect(textViews(in: view).contains { $0.attributedText.string.contains("@@user") })
    #expect(!textViews(in: view).contains { $0.attributedText.string == "@user" })
  }

  @Test("流式表格 raw cell 按 6 输入精确过滤且重建不重跑")
  func streamTableCells_keepRawInlineFilterSemantics() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    var filterCallCount = 0
    configuration.setSourceFilter(
      { source in
        filterCallCount += 1
        return source.replacingOccurrences(of: "@@", with: "@")
      },
      semanticIdentity: "audit-stream-raw-filter"
    )

    // headers=2 + reference=2 + append=2 → 接纳恰好 6 次。
    let stream = InkStreamTableView(layoutMode: .wrap, configuration: configuration)
    stream.setHeaders(["H@@@1", "H@@@2"], referenceRows: [["R@@@1", "R@@@2"]])
    stream.appendRow(["B@@@1", "B@@@2"])
    stream.frame = CGRect(x: 0, y: 0, width: 744, height: 400)
    stream.setNeedsLayout()
    stream.layoutIfNeeded()

    #expect(filterCallCount == 6)
    #expect(stream.rowCount == 1)
    #expect(textViews(in: stream).contains { $0.attributedText.string.contains("@@1") })
    #expect(!textViews(in: stream).contains { $0.attributedText.string.contains("@@@") })
    // reference 参与测量但不进入可见行文本。
    #expect(!textViews(in: stream).contains { $0.attributedText.string.contains("R@@") })

    let countAfterAccept = filterCallCount
    _ = widthsAfterHostResize(stream)
    #expect(filterCallCount == countAfterAccept)

    // 第二次 setHeaders 被既有 hasRenderedHeader 守卫拒绝，不得再次过滤。
    stream.setHeaders(["X@@@1", "X@@@2"], referenceRows: [["Y@@@1", "Y@@@2"]])
    #expect(filterCallCount == countAfterAccept)
    #expect(stream.rowCount == 1)
  }

  @Test("未显示 referenceRows 仍在宽窄恢复后影响首列宽")
  func streamTable_referenceRowsAffectColumnWidthWithoutDisplay() {
    var configuration = InkConfiguration.standard
    configuration.appearance.supportsDynamicType = false
    let longMarker = String(repeating: "REF长样本列内容", count: 20)
    let shortBody = ["短", "短"]

    let withReference = InkStreamTableView(layoutMode: .wrap, configuration: configuration)
    withReference.setHeaders(["名称", "说明"], referenceRows: [[longMarker, "短"]])
    withReference.appendRow(shortBody)

    let withoutReference = InkStreamTableView(layoutMode: .wrap, configuration: configuration)
    withoutReference.setHeaders(["名称", "说明"], referenceRows: [["短", "短"]])
    withoutReference.appendRow(shortBody)

    #expect(withReference.rowCount == 1)
    #expect(withoutReference.rowCount == 1)
    #expect(!textViews(in: withReference).contains { $0.attributedText.string.contains("REF长样本") })

    let referenced = firstColumnWidthsAfterHostResize(withReference)
    let control = firstColumnWidthsAfterHostResize(withoutReference)

    #expect(referenced.wide > control.wide)
    #expect(referenced.narrow < referenced.wide)
    #expect(referenced.restored > referenced.narrow)
    // 恢复后仍保留 reference 对首列的影响，不能退化成仅 body 短行宽度。
    #expect(referenced.restored > control.restored)
  }

  @Test("Thought 富文本 fallback 为多个子块补充分隔符")
  func thoughtFallback_separatesInnerBlocks() {
    let result = InkAttributedRenderer.render("<think>\n正文段落\n\n## 子标题\n</think>")

    #expect(result.string.contains("正文段落\n子标题"))
  }

  @Test("列表 marker 继承引用 context 的字体与颜色")
  func listMarker_inheritsContainerContext() {
    var appearance = InkAppearance()
    appearance.supportsDynamicType = false
    appearance.blockquote.fontSize = 23
    appearance.blockquote.color = .systemPurple
    let configuration = InkConfiguration(appearance: appearance)
    let result = InkAttributedRenderer.render("> - 引用列表", configuration: configuration)
    let markerRange = (result.string as NSString).range(of: "•")
    let bodyRange = (result.string as NSString).range(of: "引用列表")

    guard markerRange.location != NSNotFound, bodyRange.location != NSNotFound else {
      Issue.record("引用列表未产生预期 marker 或正文")
      return
    }
    let markerFont = result.attribute(.font, at: markerRange.location, effectiveRange: nil) as? UIFont
    let bodyFont = result.attribute(.font, at: bodyRange.location, effectiveRange: nil) as? UIFont
    let markerColor = result.attribute(.foregroundColor, at: markerRange.location, effectiveRange: nil) as? UIColor
    let bodyColor = result.attribute(.foregroundColor, at: bodyRange.location, effectiveRange: nil) as? UIColor

    #expect(markerFont?.pointSize == bodyFont?.pointSize)
    #expect(markerColor == bodyColor)
    #expect(markerColor == appearance.blockquote.color)
  }

  @Test("列表项中的首个非 Paragraph 子块不改写后续源顺序")
  func listItem_preservesCodeBeforeParagraphOrder() {
    let source = "- ```\n  code before paragraph\n  ```\n\n  trailing paragraph"
    let result = InkAttributedRenderer.render(source)
    let codeIndex = result.string.range(of: "code before paragraph")?.lowerBound
    let paragraphIndex = result.string.range(of: "trailing paragraph")?.lowerBound

    #expect(codeIndex != nil)
    #expect(paragraphIndex != nil)
    if let codeIndex, let paragraphIndex {
      #expect(codeIndex < paragraphIndex)
    }
  }

  @Test("图片占位与附件都保留外层链接 context")
  func linkedImage_preservesLinkAcrossFallbackStates() {
    let source = "[![alt](https://image.example/p.png)](https://outer.example)"
    let expectedURL = URL(string: "https://outer.example")!

    let disabled = InkAttributedRenderer.render(source)
    expectLink(expectedURL, inPlaceholder: disabled)

    var rejectedAppearance = InkAppearance()
    rejectedAppearance.imageRendering.isEnabled = true
    let rejected = InkAttributedRenderer.render(
      "[![alt](relative.png)](https://outer.example)",
      configuration: InkConfiguration(appearance: rejectedAppearance)
    )
    expectLink(expectedURL, inPlaceholder: rejected)

    var policyAppearance = rejectedAppearance
    policyAppearance.imageRendering.securityPolicy.allowedHosts = ["allowed.example"]
    let policyRejected = InkAttributedRenderer.render(
      source,
      configuration: InkConfiguration(appearance: policyAppearance)
    )
    expectLink(expectedURL, inPlaceholder: policyRejected)

    let loaded = InkAttributedRenderer.render(
      source,
      configuration: InkConfiguration(appearance: rejectedAppearance)
    )
    var attachmentLocation: Int?
    if loaded.length > 0 {
      loaded.enumerateAttribute(.attachment, in: NSRange(location: 0, length: loaded.length)) { value, range, stop in
        if value is InkImageAttachment {
          attachmentLocation = range.location
          stop.pointee = true
        }
      }
    }
    #expect(attachmentLocation != nil)
    if let attachmentLocation {
      #expect(loaded.attribute(.link, at: attachmentLocation, effectiveRange: nil) as? URL == expectedURL)
    }
  }

  private func textViews(in root: UIView) -> [UITextView] {
    root.subviews.flatMap { child -> [UITextView] in
      let matches = child is UITextView ? [child as! UITextView] : []
      return matches + textViews(in: child)
    }
  }

  private func widthsAfterHostResize(_ view: UIView) -> (wide: CGFloat, narrow: CGFloat, restored: CGFloat) {
    view.frame = CGRect(x: 0, y: 0, width: 744, height: 1_000)
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let wide = textViews(in: view).map(\.bounds.width).max() ?? 0

    view.frame.size.width = 375
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let narrow = textViews(in: view).map(\.bounds.width).max() ?? 0

    view.frame.size.width = 744
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let restored = textViews(in: view).map(\.bounds.width).max() ?? 0
    return (wide, narrow, restored)
  }

  private func firstColumnWidthsAfterHostResize(
    _ view: UIView
  ) -> (wide: CGFloat, narrow: CGFloat, restored: CGFloat) {
    view.frame = CGRect(x: 0, y: 0, width: 744, height: 1_000)
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let wide = firstColumnTextWidth(in: view)

    view.frame.size.width = 375
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let narrow = firstColumnTextWidth(in: view)

    view.frame.size.width = 744
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let restored = firstColumnTextWidth(in: view)
    return (wide, narrow, restored)
  }

  /// 取宿主坐标系中最靠左的单元格文本宽度，作为首列几何观察点。
  private func firstColumnTextWidth(in root: UIView) -> CGFloat {
    let frames = textViews(in: root).map { textView -> (CGFloat, CGFloat) in
      let frame = textView.convert(textView.bounds, to: root)
      return (frame.minX, frame.width)
    }
    guard let leftmost = frames.min(by: { $0.0 < $1.0 }) else { return 0 }
    return leftmost.1
  }

  private func scrollViewportAfterHostResize(_ view: UIView) -> (
    wide: CGFloat,
    narrow: CGFloat,
    restored: CGFloat,
    wideContent: CGFloat,
    narrowContent: CGFloat
  ) {
    view.frame = CGRect(x: 0, y: 0, width: 744, height: 1_000)
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let wideScroll = tableScrollViews(in: view).first
    let wide = wideScroll?.bounds.width ?? 0
    let wideContent = wideScroll?.contentSize.width ?? 0

    view.frame.size.width = 375
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let narrowScroll = tableScrollViews(in: view).first
    let narrow = narrowScroll?.bounds.width ?? 0
    let narrowContent = narrowScroll?.contentSize.width ?? 0

    view.frame.size.width = 744
    view.setNeedsLayout()
    view.layoutIfNeeded()
    let restored = tableScrollViews(in: view).first?.bounds.width ?? 0
    return (wide, narrow, restored, wideContent, narrowContent)
  }

  private func tableScrollViews(in root: UIView) -> [UIScrollView] {
    root.subviews.flatMap { child -> [UIScrollView] in
      let matches: [UIScrollView] = if let scrollView = child as? UIScrollView,
                                       !(child is UITextView) {
        [scrollView]
      } else {
        []
      }
      return matches + tableScrollViews(in: child)
    }
  }

  private func expectLink(_ expectedURL: URL, inPlaceholder result: NSAttributedString) {
    let range = (result.string as NSString).range(of: "[🖼 alt]")
    guard range.location != NSNotFound else {
      Issue.record("图片占位未产生")
      return
    }
    #expect(result.attribute(.link, at: range.location, effectiveRange: nil) as? URL == expectedURL)
  }
}
