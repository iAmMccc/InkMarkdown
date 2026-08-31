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

  private struct BacktickRun {
    let location: Int
    let length: Int
    let lineNumber: Int
    let isEscapedOutsideCodeSpan: Bool
  }

  private struct BacktickAnalysis {
    let pairs: [(opening: Int, closing: Int)]
    let unmatchedOpeners: [Int]
  }

  /// 返回文本中未转义的 backtick runs。
  ///
  /// 反斜杠奇偶性决定 run 是否被转义。扫描只消费 UTF-16 code unit，因而返回位置
  /// 可直接与 NSRegularExpression 的 NSRange 对齐。
  private static func backtickRuns(in text: String, startingAt startLocation: Int) -> [BacktickRun] {
    let utf16 = Array(text.utf16)
    var runs: [BacktickRun] = []
    var location = startLocation
    var lineNumber = 0
    var precedingBackslashCount = 0

    while location < utf16.count {
      let codeUnit = utf16[location]
      if codeUnit == 0x0A || codeUnit == 0x0D {
        lineNumber += 1
        precedingBackslashCount = 0
        location += 1
        continue
      }

      guard codeUnit == 0x60 else {
        if codeUnit == 0x5C {
          precedingBackslashCount += 1
        } else {
          precedingBackslashCount = 0
        }
        location += 1
        continue
      }

      let runStart = location
      while location < utf16.count, utf16[location] == 0x60 {
        location += 1
      }
      let runLength = location - runStart

      runs.append(
        BacktickRun(
          location: runStart,
          length: runLength,
          lineNumber: lineNumber,
          isEscapedOutsideCodeSpan: precedingBackslashCount % 2 != 0
        )
      )
      precedingBackslashCount = 0
    }

    return runs
  }

  /// 线性生成非重叠、相同长度的 backtick spans。
  ///
  /// 先预计算每个 run 的 next same-length run，再以 closer + 1 继续扫描；因此
  /// span 内其它长度的 run 被忽略，交叉 span 不会产生。没有 closer 的 run 作为字面量
  /// 继续前进，不阻塞后续长度的 span。
  private static func pairedBacktickRunIndices(in runs: [BacktickRun]) -> BacktickAnalysis {
    var nextSameLength = Array<Int?>(repeating: nil, count: runs.count)
    var nextRunByLength: [Int: Int] = [:]

    for index in runs.indices.reversed() {
      nextSameLength[index] = nextRunByLength[runs[index].length]
      nextRunByLength[runs[index].length] = index
    }

    var pairs: [(opening: Int, closing: Int)] = []
    var unmatchedOpeners: [Int] = []
    var index = 0

    while index < runs.count {
      // CommonMark 的反斜杠转义只阻止 code span 在普通 Markdown 中开启；一旦已经
      // 进入 code span，内容按字面处理，前置反斜杠不阻止等长 backtick run 闭合。
      if runs[index].isEscapedOutsideCodeSpan {
        index += 1
        continue
      }
      if let closingIndex = nextSameLength[index] {
        pairs.append((opening: index, closing: closingIndex))
        index = closingIndex + 1
      } else {
        unmatchedOpeners.append(index)
        index += 1
      }
    }

    return BacktickAnalysis(pairs: pairs, unmatchedOpeners: unmatchedOpeners)
  }

  /// 按标签名称查找第一个真正的 closing tag。
  ///
  /// Thought closing tag 是流式协议 delimiter。已经闭合的 Markdown code span（包括
  /// 跨行 span）可以遮蔽候选；流式扫描还必须把未配对 run 视为不稳定前缀，避免未来
  /// 分片补齐 code span 后撤回已经发布的正文 remainder。
  private static func firstClosingThoughtTag(
    in text: String,
    closeMatches: [NSTextCheckingResult],
    matching openTagName: String,
    startingAt startLocation: Int,
    requiresPrefixStability: Bool
  ) -> NSTextCheckingResult? {
    let nsString = text as NSString
    let candidates = closeMatches.filter { match in
      nsString.substring(with: match.range(at: 1)).caseInsensitiveCompare(openTagName) == .orderedSame
    }
    guard !candidates.isEmpty else { return nil }

    let runs = backtickRuns(in: text, startingAt: startLocation)
    guard !runs.isEmpty else { return candidates.first }

    let analysis = pairedBacktickRunIndices(in: runs)
    var spanIndex = 0

    for candidate in candidates {
      let candidateLocation = candidate.range.location

      while spanIndex < analysis.pairs.count {
        let pair = analysis.pairs[spanIndex]
        let spanEnd = runs[pair.closing].location + runs[pair.closing].length
        if spanEnd <= candidateLocation {
          spanIndex += 1
        } else {
          break
        }
      }

      if spanIndex < analysis.pairs.count {
        let pair = analysis.pairs[spanIndex]
        let spanStart = runs[pair.opening].location + runs[pair.opening].length
        let spanEnd = runs[pair.closing].location + runs[pair.closing].length
        if spanStart <= candidateLocation, candidateLocation < spanEnd {
          continue
        }
      }

      if requiresPrefixStability,
         let unmatchedOpener = analysis.unmatchedOpeners.first,
         runs[unmatchedOpener].location < candidateLocation {
        // 未来分片可能跨行闭合这个 opener，并把当前标签重新解释成 code span 内容。
        // 终态扫描不要求前缀稳定，仍会把最终未配对的 backtick 当作普通字面量。
        return nil
      }

      return candidate
    }

    return nil
  }

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
    scan(from: text, requiresPrefixStability: false)
  }

  private static func scan(
    from text: String,
    requiresPrefixStability: Bool
  ) -> Result? {
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
    if let closeMatch = firstClosingThoughtTag(
      in: text,
      closeMatches: closeMatches,
      matching: openTagName,
      startingAt: afterOpenLocation,
      requiresPrefixStability: requiresPrefixStability
    ) {
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
    guard let scanned = scan(from: source, requiresPrefixStability: true) else {
      return StreamingSplit(thought: nil, remainder: source)
    }
    if scanned.isComplete {
      return StreamingSplit(thought: scanned, remainder: scanned.suffixContent ?? "")
    }
    return StreamingSplit(thought: scanned, remainder: "")
  }
}
