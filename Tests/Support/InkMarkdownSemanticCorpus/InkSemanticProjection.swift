import Foundation
import Testing
import UIKit
import InkMarkdown

// MARK: - 语义投影（Semantic Projection）
//
// 从各呈现通道的渲染产物中抽取「用户可观察语义」，用于跨通道比较。
// 刻意不比较：private cache、内部 map、具体 UIView identity、像素级 frame、
// NSAttributedString 的底层序列化表示（字体内部描述等跨版本漂移字段）。

/// 单个链接 run 的语义投影。
public struct InkLinkProjection: Sendable, Equatable {

  /// 链接展示文本。
  public let text: String

  /// `.link` 属性目标；`nil` 表示该位置没有链接属性。
  public let destination: String?
}

/// 单个 inline run 的语义投影。
public struct InkInlineTraitProjection: Sendable, Equatable {

  /// run 文本。
  public let text: String
  /// 是否携带粗体 trait。
  public let isBold: Bool
  /// 是否携带斜体 trait。
  public let isItalic: Bool
  /// 是否携带等宽 trait。
  public let isMonospace: Bool
  /// 是否携带 InkMarkdown 行内代码背景身份。
  public let hasInlineCodeBackground: Bool
}

/// 从富文本中按锚点抽取 inline run 语义。
public enum InkInlineTraitProjectionExtractor {

  /// 返回锚点起点处的 inline trait 投影；找不到时返回 `nil`。
  public static func run(
    containing text: String,
    in attributed: NSAttributedString
  ) -> InkInlineTraitProjection? {
    let nsString = attributed.string as NSString
    let range = nsString.range(of: text)
    guard range.location != NSNotFound else { return nil }
    let attributes = attributed.attributes(at: range.location, effectiveRange: nil)
    let traits = (attributes[.font] as? UIFont)?.fontDescriptor.symbolicTraits
    let obliqueness = (attributes[.obliqueness] as? NSNumber)?.doubleValue ?? 0
    return InkInlineTraitProjection(
      text: nsString.substring(with: range),
      isBold: traits?.contains(.traitBold) == true,
      isItalic: traits?.contains(.traitItalic) == true || obliqueness != 0,
      isMonospace: traits?.contains(.traitMonoSpace) == true,
      hasInlineCodeBackground: attributes[.inkInlineCodeBackground] != nil
    )
  }
}

/// 段落几何投影。
public struct InkParagraphProjection: Sendable, Equatable {

  /// 段落锚点文本（定位用）。
  public let anchor: String

  /// `NSParagraphStyle.headIndent`。
  public let headIndent: CGFloat

  /// `NSParagraphStyle.firstLineHeadIndent`。
  public let firstLineHeadIndent: CGFloat

  /// `minimumLineHeight`（固定行高契约要求与 maximum 相等）。
  public let minimumLineHeight: CGFloat

  /// `maximumLineHeight`。
  public let maximumLineHeight: CGFloat
}

/// 一段渲染产物的链接语义投影集合。
public struct InkLinkSemanticProjection: Sendable, Equatable {

  /// 渲染产物纯文本。
  public let plainText: String

  /// 按 `.link` 属性连续区间抽取的链接投影。
  public let links: [InkLinkProjection]

  /// 从 NSAttributedString 抽取链接语义投影。
  public init(_ attributed: NSAttributedString) {
    self.plainText = attributed.string
    var links: [InkLinkProjection] = []
    attributed.enumerateAttribute(
      .link,
      in: NSRange(location: 0, length: attributed.length),
      options: []
    ) { value, range, _ in
      let text = (attributed.string as NSString).substring(with: range)
      let destination = (value as? URL)?.absoluteString
      links.append(InkLinkProjection(text: text, destination: destination))
    }
    self.links = links
  }

  /// 断言语义：期望的每一条链接投影都能在渲染产物中找到。
  ///
  /// `expected.destination == nil` 表示要求该文本**不携带** `.link` 属性
  /// （危险 scheme fallback / 不支持边界）。
  public func missingExpectations(_ expected: [InkLinkExpectation]) -> [InkLinkExpectation] {
    expected.filter { !contains($0) }
  }

  /// 查找「文本完全匹配」的投影。
  ///
  /// 正向预期：存在 text+destination 完全一致的 `.link` run。
  /// 负向预期（destination == nil）：文本必须出现在纯文本中，且**不得**存在同名 `.link` run
  ///（没有任何 run 也满足——fallback 为纯文本时根本不产生链接属性）。
  private func contains(_ expected: InkLinkExpectation) -> Bool {
    if let destination = expected.destination {
      return links.contains { $0.text == expected.text && $0.destination == destination }
    }
    guard plainText.contains(expected.text) else { return false }
    return !links.contains { $0.text == expected.text }
  }
}

/// 从 NSAttributedString 抽取段落几何（按锚点文本定位）。
public enum InkParagraphProjectionExtractor {

  /// 返回锚点文本所在段落的几何投影；找不到时返回 `nil`。
  public static func paragraph(
    containing anchor: String,
    in attributed: NSAttributedString
  ) -> InkParagraphProjection? {
    let nsString = attributed.string as NSString
    let range = nsString.range(of: anchor)
    guard range.location != NSNotFound else {
      return nil
    }
    var matched: NSParagraphStyle?
    attributed.enumerateAttribute(
      .paragraphStyle,
      in: NSRange(location: 0, length: attributed.length),
      options: []
    ) { value, attributeRange, stop in
      guard let style = value as? NSParagraphStyle else { return }
      guard NSIntersectionRange(attributeRange, range).length > 0 else { return }
      matched = style
      stop.pointee = true
    }
    guard let style = matched else { return nil }
    return InkParagraphProjection(
      anchor: anchor,
      headIndent: style.headIndent,
      firstLineHeadIndent: style.firstLineHeadIndent,
      minimumLineHeight: style.minimumLineHeight,
      maximumLineHeight: style.maximumLineHeight
    )
  }
}

/// 从 UIKit 呈现树抽取用户可观察富文本的共享入口。
public enum InkViewProjectionExtractor {

  /// 深度优先返回视图树中指定类型的全部实例。
  @MainActor
  public static func views<View: UIView>(
    of type: View.Type,
    in view: UIView
  ) -> [View] {
    var result: [View] = []
    if let match = view as? View {
      result.append(match)
    }
    for subview in view.subviews {
      result.append(contentsOf: views(of: type, in: subview))
    }
    return result
  }

  /// 深度优先返回视图树中的全部 `UITextView`。
  @MainActor
  public static func textViews(in view: UIView) -> [UITextView] {
    views(of: UITextView.self, in: view)
  }

  /// 按视图顺序拼接单棵呈现树中的富文本内容。
  @MainActor
  public static func attributedContent(in view: UIView) -> NSAttributedString {
    attributedContent(in: [view])
  }

  /// 按视图顺序拼接一组呈现树中的富文本内容。
  @MainActor
  public static func attributedContent(in views: [UIView]) -> NSAttributedString {
    let result = NSMutableAttributedString()
    for view in views {
      for textView in textViews(in: view) {
        result.append(textView.attributedText)
      }
    }
    return result
  }
}

/// 表格 UIView 真正呈现出的行、列与对齐投影。
public struct InkPresentedTableProjection: Sendable, Equatable {

  /// UIKit 文本对齐的稳定、本地表示。
  public enum Alignment: String, Sendable, Equatable {
    case left
    case center
    case right
    case justified
    case natural
  }

  /// 第一行（表头）的显示文本。
  public let headers: [String]
  /// 后续数据行的显示文本。
  public let rows: [[String]]
  /// 各列在呈现控件上的实际对齐。
  public let alignments: [Alignment]
}

/// 从 UIKit 表格呈现树抽取结构语义，不读取 block model 或私有缓存。
public enum InkTablePresentationProjectionExtractor {

  /// 识别表格的纵向 row stack，并返回用户实际可观察的单元格结构。
  @MainActor
  public static func projection(in view: UIView) -> InkPresentedTableProjection? {
    for stack in InkViewProjectionExtractor.views(of: UIStackView.self, in: view)
      where stack.axis == .vertical {
      let rowTextViews = stack.arrangedSubviews
        .map(InkViewProjectionExtractor.textViews(in:))
        .filter { !$0.isEmpty }
      guard let header = rowTextViews.first,
            !header.isEmpty,
            rowTextViews.count >= 2,
            rowTextViews.allSatisfy({ $0.count == header.count }) else {
        continue
      }
      return InkPresentedTableProjection(
        headers: header.map { $0.attributedText.string },
        rows: rowTextViews.dropFirst().map { row in
          row.map { $0.attributedText.string }
        },
        alignments: header.map { alignment($0.textAlignment) }
      )
    }
    return nil
  }

  private static func alignment(
    _ alignment: NSTextAlignment
  ) -> InkPresentedTableProjection.Alignment {
    switch alignment {
    case .left: return .left
    case .center: return .center
    case .right: return .right
    case .justified: return .justified
    case .natural: return .natural
    @unknown default: return .natural
    }
  }
}

// MARK: - 通道投影抽取

/// 各呈现通道 → 语义投影的统一抽取入口。
///
/// 所有抽取只依赖 InkMarkdown 公开 API；SwiftUI 通道由测试 target 把 UIKit 视图
/// 归约到 `NSAttributedString` 后复用同一套投影类型，避免第二套比较语义。
public enum InkChannelProjection {

  /// attributed 通道：直接渲染结果。
  @MainActor
  public static func attributedSource(
    _ fixture: InkSemanticCorpusFixture,
    configuration: InkConfiguration
  ) -> NSAttributedString {
    InkAttributedRenderer.render(fixture.markdown, configuration: configuration)
  }

  /// block 通道：把富文本 fallback 块的产物按顺序拼接后抽取。
  ///
  /// 块间分隔符（`\n` + 尾部哨兵段落）不携带 `.link` 属性，拼接不会伪造或丢失链接语义。
  @MainActor
  public static func blockAttributedSource(
    _ fixture: InkSemanticCorpusFixture,
    configuration: InkConfiguration
  ) -> NSAttributedString {
    let blocks = InkBlockRenderer.render(fixture.markdown, configuration: configuration)
    return InkViewProjectionExtractor.attributedContent(in: blocks.map { $0.makeView() })
  }

  /// block 通道的块类型序列（公开类型名）。
  @MainActor
  public static func blockTypeNames(
    _ fixture: InkSemanticCorpusFixture,
    configuration: InkConfiguration
  ) -> [String] {
    InkBlockRenderer.render(fixture.markdown, configuration: configuration)
      .map { String(describing: type(of: $0)) }
  }

  /// 已有 Block 列表的公开类型名序列。
  @MainActor
  public static func blockTypeNames(of blocks: [any InkRenderableBlock]) -> [String] {
    blocks.map { String(describing: type(of: $0)) }
  }

  /// block 通道的真实表格 Block 列表（结构语义载体：headers / rows / alignments）。
  @MainActor
  public static func tableBlocks(
    _ fixture: InkSemanticCorpusFixture,
    configuration: InkConfiguration
  ) -> [InkTableBlock] {
    InkBlockRenderer.render(fixture.markdown, configuration: configuration)
      .compactMap { $0 as? InkTableBlock }
  }

  /// 已有 Block 列表中的表格结构投影。
  @MainActor
  public static func tableStructures(
    of blocks: [any InkRenderableBlock]
  ) -> [InkTableExpectation] {
    blocks.compactMap { $0 as? InkTableBlock }.map { structure(of: $0) }
  }

  /// 把真实表格 Block 渲染为 UIView，再抽取用户可观察的表格结构。
  @MainActor
  public static func tablePresentationStructures(
    of blocks: [any InkRenderableBlock]
  ) -> [InkPresentedTableProjection] {
    blocks
      .compactMap { $0 as? InkTableBlock }
      .compactMap { InkTablePresentationProjectionExtractor.projection(in: $0.makeView()) }
  }

  /// 把真实表格 Block 的结构归约为 corpus 预期形态（对齐转为本地枚举）。
  @MainActor
  public static func structure(of table: InkTableBlock) -> InkTableExpectation {
    InkTableExpectation(
      headers: table.headers,
      rows: table.rows,
      alignments: table.alignments.map { alignment in
        switch alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case nil: return nil
        }
      }
    )
  }

  /// 流式通道：把 fixture 按 token 边界拆分喂入 `InkStreamRenderer`，
  /// `finish()` 完成最终全量解析后返回终态 attributed 产物。
  ///
  /// 等待点是 `onFinishParse`（最终解析完成、终态内容可读）；
  /// 不等待逐字显示追赶，因为比较对象是**终态语义投影**而非打字机过程。
  @MainActor
  public static func streamingFinishSource(
    _ fixture: InkSemanticCorpusFixture,
    configuration: InkConfiguration,
    timeoutSeconds: UInt64 = 5_000_000_000
  ) async -> NSAttributedString {
    let renderer = InkStreamRenderer(configuration: configuration)
    let mailbox = FinishParseMailbox()
    renderer.onFinishParse = { mailbox.signal() }

    for chunk in fixture.streamingChunks() {
      renderer.append(chunk)
    }
    renderer.finish()

    let completed = await mailbox.waitOrTimeout(timeoutNanoseconds: timeoutSeconds)
    if !completed {
      Issue.record("streaming finish 未能在超时前完成：fixture \(fixture.id)")
    }
    return renderer.currentAttributedString()
  }

  /// 跨 suspend 等待 onFinishParse 的一次性信箱；轮询期间抽干 main queue，
  /// 保证后台解析完成后的 `DispatchQueue.main.async` 回调能被消费。
  private final class FinishParseMailbox: @unchecked Sendable {

    private let lock = NSLock()
    private var isSignalled = false

    func signal() {
      lock.lock()
      isSignalled = true
      lock.unlock()
    }

    @MainActor
    func waitOrTimeout(timeoutNanoseconds: UInt64) async -> Bool {
      await InkAsyncTestProbe.wait(timeoutNanoseconds: timeoutNanoseconds) {
        isSignalledFlag
      }
    }

    private var isSignalledFlag: Bool {
      lock.lock()
      defer { lock.unlock() }
      return isSignalled
    }
  }
}
