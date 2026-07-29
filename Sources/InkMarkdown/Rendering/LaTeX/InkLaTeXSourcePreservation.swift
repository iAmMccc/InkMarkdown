import Foundation

/// 在 swift-markdown 解析前保护 `\(...\)` / `\[...\]` 定界符。
///
/// cmark 会把 `\(` 当作转义并剥离反斜杠，且无法与 `\\(` 的 plainText 输出区分。
/// 未转义的 bracket 定界符替换为私有区占位符，随 AST 原样进入 `Text.string` / `plainText`。
enum InkLaTeXSourcePreservation {
  static let inlineOpen = "\u{F000}"
  static let inlineClose = "\u{F001}"
  static let blockOpen = "\u{F002}"
  static let blockClose = "\u{F003}"

  private struct FenceMarker {
    let character: Character
    let count: Int
  }

  /// 将占位符还原为 `\(` `\)` `\[` `\]`，供 LaTeX 未命中时的文本降级路径使用。
  static func restoreBracketDelimiters(in source: String) -> String {
    source
      .replacingOccurrences(of: String(inlineOpen), with: "\\(")
      .replacingOccurrences(of: String(inlineClose), with: "\\)")
      .replacingOccurrences(of: String(blockOpen), with: "\\[")
      .replacingOccurrences(of: String(blockClose), with: "\\]")
  }

  /// 将未转义且不在代码区域内的 `\(` `\)` `\[` `\]` 替换为占位符。
  static func preserveBracketDelimiters(in source: String) -> String {
    var result = ""
    result.reserveCapacity(source.count)
    var fencedCode: FenceMarker?

    let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
    for (lineIndex, lineSub) in lines.enumerated() {
      if lineIndex > 0 { result.append("\n") }
      let line = String(lineSub)
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if fencedCode != nil {
        result.append(line)
        if let closing = closingFence(in: trimmed),
           closing.character == fencedCode?.character,
           closing.count >= fencedCode!.count {
          fencedCode = nil
        }
        continue
      }

      if let opening = openingFence(in: trimmed) {
        fencedCode = opening
        result.append(line)
        continue
      }

      result.append(preserveLine(line))
    }
    return result
  }

  private static func preserveLine(_ line: String) -> String {
    var result = ""
    result.reserveCapacity(line.count + 4)
    var inlineCodeTicks: Int?
    var index = line.startIndex

    while index < line.endIndex {
      if line[index] == "`" {
        let tickCount = line[index...].prefix(while: { $0 == "`" }).count
        if let open = inlineCodeTicks {
          if open == tickCount { inlineCodeTicks = nil }
        } else {
          inlineCodeTicks = tickCount
        }
        result.append(String(line[index..<line.index(index, offsetBy: tickCount)]))
        index = line.index(index, offsetBy: tickCount)
        continue
      }

      if inlineCodeTicks != nil {
        result.append(line[index])
        index = line.index(after: index)
        continue
      }

      if line[index...].hasPrefix("\\("), !isEscaped(line, at: index) {
        result.append(inlineOpen)
        index = line.index(index, offsetBy: 2)
        continue
      }
      if line[index...].hasPrefix("\\)"), !isEscaped(line, at: index) {
        result.append(inlineClose)
        index = line.index(index, offsetBy: 2)
        continue
      }
      if line[index...].hasPrefix("\\["), !isEscaped(line, at: index) {
        result.append(blockOpen)
        index = line.index(index, offsetBy: 2)
        continue
      }
      if line[index...].hasPrefix("\\]"), !isEscaped(line, at: index) {
        result.append(blockClose)
        index = line.index(index, offsetBy: 2)
        continue
      }

      result.append(line[index])
      index = line.index(after: index)
    }
    return result
  }

  private static func openingFence(in trimmedLine: String) -> FenceMarker? {
    guard let first = trimmedLine.first, first == "`" || first == "~" else { return nil }
    let count = trimmedLine.prefix(while: { $0 == first }).count
    guard count >= 3 else { return nil }
    return FenceMarker(character: first, count: count)
  }

  private static func closingFence(in trimmedLine: String) -> FenceMarker? {
    guard let first = trimmedLine.first, first == "`" || first == "~" else { return nil }
    let count = trimmedLine.prefix(while: { $0 == first }).count
    guard count >= 3 else { return nil }
    return FenceMarker(character: first, count: count)
  }

  private static func isEscaped(_ source: String, at index: String.Index) -> Bool {
    var slashCount = 0
    var cursor = index
    while cursor > source.startIndex {
      let previous = source.index(before: cursor)
      guard source[previous] == "\\" else { break }
      slashCount += 1
      cursor = previous
    }
    return slashCount.isMultiple(of: 2) == false
  }
}

extension InkConfiguration {
  /// 应用 ``sourceFilter``，并在 LaTeX 开启时保护 bracket 定界符后再交给解析器。
  func sourcePreparedForParsing(_ source: String) -> String {
    var text = sourceFilter?(source) ?? source
    if appearance.latexRendering.isEnabled {
      text = InkLaTeXSourcePreservation.preserveBracketDelimiters(in: text)
    }
    return text
  }
}
