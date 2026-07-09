import Foundation
import UIKit
import Testing
@testable import InkMarkdown

// MARK: - 快照测试基建（T1.1）
//
// 设计取舍：用「属性断言」而非整串序列化或像素快照。
//
// 为什么不用整串/像素快照？
//   NSAttributedString 的字段（UIFont 的内部描述、UIColor 的色域表示）跨 iOS
//   版本会漂移，导致 CI 误报（roadmap 风险 R1）。像素快照更甚——字体渲染引擎
//   升级即红。这类快照维护成本高、信号噪。
//
// 本基建做什么？
//   1. `RenderSnapshot`：把一段 Markdown 渲染后，抽成「人类可读、跨版本稳定」的指纹——
//      不含 font 的内部描述，只含我们关心的语义属性（字号/字重/等宽/颜色等价性/段落度量）。
//   2. 一组 `Assert*` 助手：在指定 range 或全文上断言「这一段是等宽」「这一段带链接」
//      「整段行高锁定」「这一段是链接色而非环境色」等语义不变量。
//
// 这些断言锁定的是「渲染契约」，而非「渲染字节」。契约稳定，就允许实现细节演化。

// MARK: - Snapshot 指纹

/// 一段已渲染 Markdown 的语义指纹。
///
/// 仅包含渲染契约关心的语义信息，刻意剔除跨版本不稳的底层描述（如 font 的
/// PostScript name、color 的浮点分量），以保证快照在 iOS 升级时不误报。
public struct RenderSnapshot: Equatable, CustomStringConvertible {

  /// 纯文本（去除所有属性后的字符序列）。
  public let plainText: String

  /// 按 run 切分的属性摘要。相邻字符若语义属性相同，归为同一 run。
  public let runs: [Run]

  public var description: String {
    var s = "text: \(plainText)\n"
    for (i, run) in runs.enumerated() {
      s += "  run[\(i)] \(run.range) → \(run.attrs.summary)\n"
    }
    return s
  }

  /// 单个 run 的语义摘要。
  public struct Run: Equatable {
    public let range: ClosedRange<Int>
    public let attrs: Attrs
  }

  /// 从 run 上抽出的语义属性集合。
  public struct Attrs: Equatable {
    public let fontSize: CGFloat
    public let isBold: Bool
    public let isItalic: Bool
    public let isMonospace: Bool
    /// 颜色仅按「是否等于某个已知 appearance 色」记录等价关系，
    /// 而非记录浮点分量——避免动态颜色/色域差异导致的漂移。
    public let colorKey: ColorKey?
    public let hasLink: Bool
    public let lineHeight: CGFloat
    public let hasStrikethrough: Bool
    public let hasInlineCodeBackground: Bool

    public var summary: String {
      var parts = ["\(fontSize)pt"]
      if isBold { parts.append("bold") }
      if isItalic { parts.append("italic") }
      if isMonospace { parts.append("mono") }
      if let c = colorKey { parts.append("color:\(c)") }
      if hasLink { parts.append("link") }
      if hasStrikethrough { parts.append("strike") }
      if hasInlineCodeBackground { parts.append("codeBg") }
      parts.append("lh:\(lineHeight)")
      return parts.joined(separator: ",")
    }
  }

  /// 颜色的语义标识——记录「等于哪个 appearance 色」，而非浮点值。
  public enum ColorKey: String, Equatable {
    case text
    case heading
    case blockquote
    case link
    case secondary
  }
}

// MARK: - 快照抽取

public enum RenderSnapshotting {

  /// 把 Markdown 渲染后抽成语义快照。
  public static func snapshot(
    _ source: String,
    configuration: InkConfiguration = .standard,
    appearance: InkAppearance = InkAppearance()
  ) -> RenderSnapshot {
    let attr = InkAttributedRenderer.render(source, configuration: configuration)
    return snapshot(of: attr, appearance: appearance)
  }

  /// 把已渲染的 `NSAttributedString` 抽成语义快照。
  public static func snapshot(
    of attr: NSAttributedString,
    appearance: InkAppearance = InkAppearance()
  ) -> RenderSnapshot {
    let plainText = attr.string
    var runs: [RenderSnapshot.Run] = []
    attr.enumerateAttributes(in: NSRange(location: 0, length: attr.length), options: []) { dict, range, _ in
      let attrs = extractAttrs(dict, appearance: appearance)
      let lo = range.location
      let hi = range.location + range.length - 1
      guard range.length > 0 else { return }
      let r = RenderSnapshot.Run(range: lo...hi, attrs: attrs)
      // 合并相邻同语义 run，压缩输出
      if let last = runs.last, last.attrs == attrs, last.range.upperBound + 1 == lo {
        runs[runs.count - 1] = RenderSnapshot.Run(range: last.range.lowerBound...hi, attrs: attrs)
      } else {
        runs.append(r)
      }
    }
    return RenderSnapshot(plainText: plainText, runs: runs)
  }

  private static func extractAttrs(
    _ dict: [NSAttributedString.Key: Any],
    appearance: InkAppearance
  ) -> RenderSnapshot.Attrs {
    let font = (dict[.font] as? UIFont) ?? UIFont.systemFont(ofSize: appearance.text.fontSize)
    let traits = font.fontDescriptor.symbolicTraits
    let para = (dict[.paragraphStyle] as? NSParagraphStyle) ?? .default

    let colorKey: RenderSnapshot.ColorKey? = {
      guard let color = dict[.foregroundColor] as? UIColor else { return nil }
      if color.isEqual(appearance.text.color) { return .text }
      if color.isEqual(appearance.heading.color) { return .heading }
      if color.isEqual(appearance.blockquote.color) { return .blockquote }
      if color.isEqual(appearance.link.color) { return .link }
      if color.isEqual(appearance.text.secondaryColor) { return .secondary }
      return nil
    }()

    let hasCodeBg = dict[.inkInlineCodeBackground] as? InkInlineCodeBackgroundInfo != nil

    return RenderSnapshot.Attrs(
      fontSize: font.pointSize,
      isBold: traits.contains(.traitBold),
      isItalic: traits.contains(.traitItalic),
      isMonospace: traits.contains(.traitMonoSpace),
      colorKey: colorKey,
      hasLink: dict[.link] != nil,
      lineHeight: para.minimumLineHeight,
      hasStrikethrough: (dict[.strikethroughStyle] as? Int ?? 0) != 0,
      hasInlineCodeBackground: hasCodeBg
    )
  }
}

// MARK: - 契约断言助手（语义不变量）

/// 在语义断言失败时，把完整快照附进失败信息，便于定位。
///
/// 用 `#sourceLocation` 把报错位置回指到调用点，使失败信息定位到调用断言助手的
/// 那一行，而非本文件内部——这是 Swift Testing 的惯用做法。
public enum RenderContractAssertions {

  /// 断言「整段渲染产物的每个 run 行高都锁定为指定值」。
  public static func allRunsLockLineHeight(
    _ snapshot: RenderSnapshot,
    expected: CGFloat,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
  ) {
    let unlocked = snapshot.runs.filter { $0.attrs.lineHeight != expected }
    if !unlocked.isEmpty {
      let msg: Comment = "存在未锁定行高 \(expected) 的 run：\(unlocked.map { "\($0.range)→\($0.attrs.lineHeight)" })\n\(snapshot)"
      Issue.record(msg, sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column))
    }
  }

  /// 断言「全文至少有一个 run 命中给定谓词」（如「存在等宽」「存在链接」）。
  public static func someRun(
    _ snapshot: RenderSnapshot,
    where predicate: (RenderSnapshot.Attrs) -> Bool,
    description: String,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
  ) {
    if !snapshot.runs.contains(where: { predicate($0.attrs) }) {
      let msg: Comment = "期望存在满足「\(description)」的 run，但未找到\n\(snapshot)"
      Issue.record(msg, sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column))
    }
  }

  /// 断言「全文没有任何 run 命中给定谓词」（如「不存在加粗里的等宽」）。
  public static func noRun(
    _ snapshot: RenderSnapshot,
    where predicate: (RenderSnapshot.Attrs) -> Bool,
    description: String,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
  ) {
    let hit = snapshot.runs.filter { predicate($0.attrs) }
    if !hit.isEmpty {
      let msg: Comment = "期望不存在满足「\(description)」的 run，但命中：\(hit.map { $0.range })\n\(snapshot)"
      Issue.record(msg, sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column))
    }
  }

  /// 断言两个快照的纯文本与 run 结构完全一致。
  ///
  /// 用于「同一份源码在不同 configuration 下，结构骨架应一致」这类跨配置不变量。
  public static func snapshotsEqual(
    _ a: RenderSnapshot,
    _ b: RenderSnapshot,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
  ) {
    if a != b {
      let msg: Comment = "快照不一致：\n--- expected ---\n\(a)\n--- actual ---\n\(b)"
      Issue.record(msg, sourceLocation: SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column))
    }
  }
}
