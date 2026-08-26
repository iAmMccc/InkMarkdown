//
//  InkThoughtScanner.swift
//  InkMarkdown
//

import Foundation

/// 思考过程（`<think>` / `<thought>`）语法扫描器（SSOT）。
///
/// 作为核心库思考标签语法的唯一 Owner，提供精确的开闭标签匹配、
/// 尾随正文保全（Suffix Preservation）与流式中途态识别。
public enum InkThoughtScanner {

  /// 扫描提取结果结构体。
  public struct Result: Equatable {
    /// 思考过程正文（已剥离开闭标签与多余首尾空白）。
    public let thoughtBody: String
    /// 闭合标签之后紧随的正文内容（若有）。
    public let suffixContent: String?
    /// 思考过程是否已闭合（若为 false 则为流式中途态）。
    public let isComplete: Bool

    public init(thoughtBody: String, suffixContent: String? = nil, isComplete: Bool) {
      self.thoughtBody = thoughtBody
      self.suffixContent = suffixContent
      self.isComplete = isComplete
    }
  }

  // MARK: - Regular Expressions (Precompiled)

  /// 开标签正则：仅匹配 `<think>`、`<thought>` 以及允许内部空白的变体（如 `<think >`），
  /// 严格排除 `<thinker>`、`<thinking>`、`<think class="x">` 等非法前缀。
  private static let openTagRegex: NSRegularExpression = {
    // 匹配: ^\s*<\s*(think|thought)\s*>
    try! NSRegularExpression(pattern: #"^\s*<\s*(think|thought)\s*>"#, options: [.caseInsensitive])
  }()

  /// 全局任意位置开标签正则（用于剥离所有开标签）。
  private static let anyOpenTagRegex: NSRegularExpression = {
    // 匹配: <\s*(think|thought)\s*>
    try! NSRegularExpression(pattern: #"<\s*(think|thought)\s*>"#, options: [.caseInsensitive])
  }()

  /// 闭标签候选正则：仅匹配 `</think>`、`</thought>` 以及允许内部空白的变体（如 `</think >`）。
  /// 实际扫描时还会校验它与开标签名称相同。
  private static let closeTagRegex: NSRegularExpression = {
    // 匹配: </\s*(think|thought)\s*>
    try! NSRegularExpression(pattern: #"</\s*(think|thought)\s*>"#, options: [.caseInsensitive])
  }()

  /// 全量闭标签正则（用于精确判定独立闭标签）。
  private static let exactCloseTagRegex: NSRegularExpression = {
    // 匹配: ^\s*</\s*(think|thought)\s*>\s*$
    try! NSRegularExpression(pattern: #"^\s*</\s*(think|thought)\s*>\s*$"#, options: [.caseInsensitive])
  }()

  // MARK: - Public Scanning APIs

  /// 判断文本（忽略首尾空白）是否为闭合思考标签（如 `</think>` 或 `</thought>`）。
  public static func isClosingThoughtTag(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let nsString = trimmed as NSString
    let fullRange = NSRange(location: 0, length: nsString.length)
    return exactCloseTagRegex.firstMatch(in: trimmed, options: [], range: fullRange) != nil
  }

  /// 剥离文本中所有思考开闭标签（供行内 Markdown.Text 或 InlineHTML 降级使用）。
  public static func stripThoughtTags(from text: String) -> String {
    let nsString = text as NSString
    let fullRange = NSRange(location: 0, length: nsString.length)
    var result = anyOpenTagRegex.stringByReplacingMatches(in: text, options: [], range: fullRange, withTemplate: "")
    let nsResult = result as NSString
    let resultRange = NSRange(location: 0, length: nsResult.length)
    result = closeTagRegex.stringByReplacingMatches(in: result, options: [], range: resultRange, withTemplate: "")
    return result
  }

  /// 判断文本（忽略前导空白）是否以合法的思考开始标签开头。
  public static func startsWithThoughtTag(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let nsString = trimmed as NSString
    let fullRange = NSRange(location: 0, length: nsString.length)
    return openTagRegex.firstMatch(in: trimmed, options: [], range: fullRange) != nil
  }

  /// 扫描以思考标签开头的单段文本。
  /// - Parameter text: 包含思考标签的原始 Markdown / HTML 字符串。
  /// - Returns: 若以合法思考标签开头，返回解析出的思考正文、后续后缀及闭合状态；否则返回 nil。
  public static func scan(from text: String) -> Result? {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

    let nsString = text as NSString
    let fullRange = NSRange(location: 0, length: nsString.length)

    // 1. 查找开标签
    guard let openMatch = openTagRegex.firstMatch(in: text, options: [], range: fullRange) else {
      return nil
    }

    let openTagName = nsString.substring(with: openMatch.range(at: 1))
    let afterOpenLocation = openMatch.range.location + openMatch.range.length
    let remainingRange = NSRange(location: afterOpenLocation, length: nsString.length - afterOpenLocation)

    // 2. 查找对应的闭标签
    let closeMatches = closeTagRegex.matches(in: text, options: [], range: remainingRange)
    if let closeMatch = closeMatches.first(where: {
      nsString.substring(with: $0.range(at: 1)).caseInsensitiveCompare(openTagName) == .orderedSame
    }) {
      // 提取开闭标签之间的思考正文
      let bodyRange = NSRange(
        location: afterOpenLocation,
        length: closeMatch.range.location - afterOpenLocation
      )
      let rawBody = nsString.substring(with: bodyRange)
      let thoughtBody = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)

      // 提取闭标签之后的尾随正文（Suffix Preservation）
      let suffixLocation = closeMatch.range.location + closeMatch.range.length
      let suffixRange = NSRange(
        location: suffixLocation,
        length: nsString.length - suffixLocation
      )
      let rawSuffix = nsString.substring(with: suffixRange)
      let suffixContent = rawSuffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : rawSuffix

      return Result(thoughtBody: thoughtBody, suffixContent: suffixContent, isComplete: true)
    } else {
      // 未找到闭标签：流式中途态，开标签后的所有内容均属于未完结的思考过程
      let rawBody = nsString.substring(with: remainingRange)
      let thoughtBody = rawBody.trimmingCharacters(in: .whitespacesAndNewlines)
      return Result(thoughtBody: thoughtBody, suffixContent: nil, isComplete: false)
    }
  }

  /// 扫描跨多个 AST 节点拼接的文本序列。
  /// - Parameter texts: 各 AST 节点文本数组。
  /// - Returns: 解析结果（若首个文本不包含合法开标签则返回 nil）。
  public static func scan(from texts: [String]) -> Result? {
    guard !texts.isEmpty else { return nil }
    guard startsWithThoughtTag(texts[0]) else { return nil }
    let joined = texts.joined(separator: "\n\n")
    return scan(from: joined)
  }

  /// 流式会话 PREFIX 切分结果：思考前缀与下游 remainder。
  public struct StreamingSplit: Equatable {
    /// PREFIX 思考标签解析结果；非 PREFIX 时为 nil。
    public let thought: Result?
    /// 进入 `InkStreamRenderer` 的正文 remainder（未闭合时为 `""`；非 PREFIX 时为完整 source）。
    public let remainder: String

    public init(thought: Result?, remainder: String) {
      self.thought = thought
      self.remainder = remainder
    }
  }

  /// 按流式 PREFIX 语义切分完整 source，供 session 与 coordinator 共享。
  ///
  /// - 非 PREFIX 思考标签：`thought == nil`，`remainder == source`。
  /// - 未闭合 PREFIX：`thought.isComplete == false`，`remainder == ""`。
  /// - 已闭合 PREFIX：`remainder` 为闭标签后的 suffix（可能为空）。
  public static func splitStreamingSource(_ source: String) -> StreamingSplit {
    guard startsWithThoughtTag(source) else {
      return StreamingSplit(thought: nil, remainder: source)
    }
    guard let scanned = scan(from: source) else {
      return StreamingSplit(thought: nil, remainder: source)
    }
    if scanned.isComplete {
      return StreamingSplit(thought: scanned, remainder: scanned.suffixContent ?? "")
    }
    return StreamingSplit(thought: scanned, remainder: "")
  }
}
