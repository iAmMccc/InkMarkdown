import Foundation
import Testing
import UIKit
import InkMarkdown
import InkMarkdownSemanticCorpus

// MARK: - Canonical corpus 列表 tracer（ticket 02）
//
// 断言 paragraph style、累计 indent、文本与结构归属；不做 UI 测试与视觉 frame 断言。
// 「续段与首段内容列对齐」「层级递增」等关系型语义无法用绝对值写入 corpus，
// 在此用共享投影抽取器表达；绝对值契约（固定行高等）由 corpus fixture 声明。

@Suite("Canonical Corpus 列表 Tracer")
@MainActor
struct InkCorpusListTracerTests {

  /// 固定样式环境：关闭 Dynamic Type，保证行高/字号确定性（corpus 绝对预期的前提）。
  private func deterministicConfiguration() -> InkConfiguration {
    var appearance = InkAppearance()
    appearance.supportsDynamicType = false
    return InkConfiguration(appearance: appearance)
  }

  private func paragraph(containing anchor: String, in attributed: NSAttributedString) -> NSParagraphStyle? {
    let nsRange = (attributed.string as NSString).range(of: anchor)
    guard nsRange.location != NSNotFound else {
      return nil
    }
    var matched: NSParagraphStyle?
    attributed.enumerateAttribute(
      .paragraphStyle,
      in: NSRange(location: 0, length: attributed.length),
      options: []
    ) { value, attributeRange, stop in
      guard let style = value as? NSParagraphStyle else { return }
      guard NSIntersectionRange(attributeRange, nsRange).length > 0 else { return }
      matched = style
      stop.pointee = true
    }
    return matched
  }

  // MARK: - loose list 续段

  @Test("loose list 续段继承累计缩进、内容列对齐与固定行高")
  func looseListContinuation_inheritsListGeometry() throws {
    let fixture = InkSemanticCorpus.looseListContinuation
    let attributed = InkChannelProjection.attributedSource(fixture, configuration: deterministicConfiguration())

    let firstLine = try #require(paragraph(containing: "首段落在列表项内", in: attributed))
    let continuation = try #require(paragraph(containing: "续段仍属于同一列表项", in: attributed))

    // 续段属于列表项：缩进非零且与首段内容列对齐（悬挂缩进语义）。
    #expect(continuation.headIndent == firstLine.headIndent)
    #expect(continuation.headIndent > 0)
    #expect(continuation.firstLineHeadIndent == continuation.headIndent)
    // 固定行高契约在续段上同样成立。
    #expect(continuation.minimumLineHeight == 28)
    #expect(continuation.maximumLineHeight == 28)
  }

  // MARK: - 混合嵌套

  @Test("有序/无序混合嵌套按层级累计缩进且归属正确")
  func mixedNesting_accumulatesIndent() throws {
    let fixture = InkSemanticCorpus.mixedListNesting
    let attributed = InkChannelProjection.attributedSource(fixture, configuration: deterministicConfiguration())

    let outer = try #require(paragraph(containing: "无序外层", in: attributed))
    let inner = try #require(paragraph(containing: "有序内层", in: attributed))
    let deep = try #require(paragraph(containing: "无序深层", in: attributed))

    // 外层首行从列表起点排版（无前置缩进），悬挂列含 marker 宽度；
    // 更深层子列表的内容起点必须逐级累计。
    #expect(outer.firstLineHeadIndent == 0)
    #expect(outer.headIndent > outer.firstLineHeadIndent)
    #expect(inner.headIndent > outer.headIndent)
    #expect(deep.headIndent > inner.headIndent)
  }

  // MARK: - 列表内引用

  @Test("列表项内引用缩进叠加列表内容起点且保留竖线标记")
  func blockquoteInsideListItem_staysWithinItem() throws {
    let fixture = InkSemanticCorpus.blockquoteInsideListItem
    let attributed = InkChannelProjection.attributedSource(fixture, configuration: deterministicConfiguration())

    let quote = try #require(paragraph(containing: "引用仍在列表项内", in: attributed))
    // 列表 marker 内容列 + 引用 bar/padding：引用必须落在列表项内部，而不是根级 x≈15。
    #expect(quote.headIndent > 15)
    // 竖线标记覆盖引用区间（引用前有列表项首段，属性不覆盖全文起点）。
    var hasBar = false
    attributed.enumerateAttribute(
      .inkBlockquoteBar,
      in: NSRange(location: 0, length: attributed.length),
      options: []
    ) { value, _, stop in
      if value != nil {
        hasBar = true
        stop.pointee = true
      }
    }
    #expect(hasBar)
  }

  // MARK: - 既有任务列表契约

  @Test("任务列表 marker 与嵌套行为保持既有契约")
  func taskListMarkers_remainStable() {
    let fixture = InkSemanticCorpus.taskListMarkers
    let attributed = InkChannelProjection.attributedSource(fixture, configuration: deterministicConfiguration())

    #expect(attributed.string.contains("\u{2610} 待办事项"))
    #expect(attributed.string.contains("\u{2611} 已完成事项"))
  }

  // MARK: - corpus 驱动的跨通道段落几何

  /// 声明了段落预期的 fixture 在 attributed / block / streaming finish 三通道几何一致。
  @Test("列表 fixture 段落几何跨通道一致", arguments: [
    InkSemanticCorpus.looseListContinuation,
    InkSemanticCorpus.mixedListNesting,
    InkSemanticCorpus.blockquoteInsideListItem,
    InkSemanticCorpus.taskListMarkers,
  ])
  func listFixtureParagraphGeometry_alignsAcrossChannels(fixture: InkSemanticCorpusFixture) async {
    let configuration = deterministicConfiguration()

    let staticAttributed = InkChannelProjection.attributedSource(fixture, configuration: configuration)
    let blockAttributed = InkChannelProjection.blockAttributedSource(fixture, configuration: configuration)
    let streamingAttributed = await InkChannelProjection.streamingFinishSource(fixture, configuration: configuration)

    for channel in ["block", "streaming-finish"] {
      let target = channel == "block" ? blockAttributed : streamingAttributed
      for expectation in fixture.expectedParagraphs {
        let staticParagraph = InkParagraphProjectionExtractor.paragraph(containing: expectation.anchor, in: staticAttributed)
        let channelParagraph = InkParagraphProjectionExtractor.paragraph(containing: expectation.anchor, in: target)
        if staticParagraph != channelParagraph {
          Issue.record(
            Comment(rawValue: "fixture \(fixture.id) 锚点「\(expectation.anchor)」在 \(channel) 与静态投影不一致：静态 \(String(describing: staticParagraph)) / \(channel) \(String(describing: channelParagraph))")
          )
        }
      }
    }
  }
}
