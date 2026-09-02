import Foundation
import Testing
import UIKit
import InkMarkdown

// MARK: - 跨通道语义对齐断言
//
// 各呈现通道的 tracer 测试复用这里的断言，保证「同一个 fixture 在所有通道
// 得到同一份语义投影」只用一种比较逻辑表达，避免断言漂移。

/// 共享语义断言（Swift Testing）。
public enum InkCorpusAssertions {

  /// 断言 attributed 产物的链接语义满足 fixture 预期。
  public static func assertLinkSemantics(
    of attributed: NSAttributedString,
    fixture: InkSemanticCorpusFixture,
    channel: String
  ) {
    let projection = InkLinkSemanticProjection(attributed)
    let missing = projection.missingExpectations(fixture.expectedLinks)
    if !missing.isEmpty {
      Issue.record(
        Comment(rawValue: "channel \(channel) fixture \(fixture.id) 缺少预期链接语义：\(missing)；实际投影：\(projection)")
      )
    }
  }

  /// 断言段落几何满足 fixture 预期。
  public static func assertParagraphSemantics(
    of attributed: NSAttributedString,
    fixture: InkSemanticCorpusFixture,
    channel: String
  ) {
    for expectation in fixture.expectedParagraphs {
      guard let paragraph = InkParagraphProjectionExtractor.paragraph(
        containing: expectation.anchor,
        in: attributed
      ) else {
        Issue.record(
          Comment(rawValue: "channel \(channel) fixture \(fixture.id) 找不到锚点「\(expectation.anchor)」")
        )
        continue
      }
      if let expectedHead = expectation.headIndent, paragraph.headIndent != expectedHead {
        Issue.record(
          Comment(rawValue: "channel \(channel) fixture \(fixture.id) 锚点「\(expectation.anchor)」headIndent 期望 \(expectedHead)，实际 \(paragraph.headIndent)")
        )
      }
      if let expectedFirst = expectation.firstLineHeadIndent,
         paragraph.firstLineHeadIndent != expectedFirst {
        Issue.record(
          Comment(rawValue: "channel \(channel) fixture \(fixture.id) 锚点「\(expectation.anchor)」firstLineHeadIndent 期望 \(expectedFirst)，实际 \(paragraph.firstLineHeadIndent)")
        )
      }
      if let expectedLineHeight = expectation.lineHeight {
        // 固定行高契约：minimum == maximum == 期望值。
        if paragraph.minimumLineHeight != expectedLineHeight
          || paragraph.maximumLineHeight != expectedLineHeight {
          Issue.record(
            Comment(rawValue: "channel \(channel) fixture \(fixture.id) 锚点「\(expectation.anchor)」行高期望固定 \(expectedLineHeight)，实际 min \(paragraph.minimumLineHeight) / max \(paragraph.maximumLineHeight)")
          )
        }
      }
    }
  }

  /// 断言 block 通道的块类型序列满足 fixture 预期。
  public static func assertBlockTypes(
    _ actualTypeNames: [String],
    fixture: InkSemanticCorpusFixture
  ) {
    for expectation in fixture.expectedBlockTypes {
      let actualCount = actualTypeNames.filter { $0 == expectation.typeName }.count
      let expectedCount = expectation.count ?? 0
      let satisfied = expectation.count == nil ? actualCount >= 1 : actualCount == expectedCount
      if !satisfied {
        Issue.record(
          Comment(rawValue: "fixture \(fixture.id) 块类型 \(expectation.typeName) 期望 \(expectation.count.map(String.init) ?? "至少一次")，实际 \(actualCount)；序列：\(actualTypeNames)")
        )
      }
    }
  }

  /// 断言两个通道对同一 fixture 产出**相同**的链接语义投影。
  ///
  /// streaming finish 与静态渲染使用同一份全量渲染路径，投影必须逐条相等；
  /// 不比较 NSAttributedString 整体（序列化表示跨版本漂移）。
  public static func assertProjectionsEqual(
    _ lhs: InkLinkSemanticProjection,
    _ rhs: InkLinkSemanticProjection,
    fixture: InkSemanticCorpusFixture,
    channels: (lhs: String, rhs: String)
  ) {
    guard lhs != rhs else { return }
    Issue.record(
      Comment(rawValue: "fixture \(fixture.id) 通道 \(channels.lhs) 与 \(channels.rhs) 语义投影不一致：\n\(channels.lhs) = \(lhs)\n\(channels.rhs) = \(rhs)")
    )
  }
}
