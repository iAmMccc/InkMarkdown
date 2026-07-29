import Foundation

/// Markdown 中可识别的 LaTeX 分隔符。
public enum InkLaTeXDelimiter: String, Hashable, Sendable {
  /// `$...$`
  case inlineDollar
  /// `\\(...\\)`
  case inlineParentheses
  /// `$$...$$`
  case blockDollar
}

/// 从 Markdown 源文本识别出的一个 LaTeX 表达式。
public struct InkLaTeXExpression: Sendable {
  /// 已移除 Markdown 分隔符的 LaTeX 内容。
  public let latex: String
  /// 原始 Markdown 使用的分隔符。
  public let delimiter: InkLaTeXDelimiter
  /// 表达式（含分隔符）在输入 UTF-16 序列中的范围。
  public let utf16Range: NSRange

  /// 与分隔符对应的 iosMath 显示模式，供生成图片接入层直接创建渲染请求。
  public var renderMode: InkLaTeXRenderMode {
    delimiter == .blockDollar ? .block : .inline
  }
}

/// LaTeX 输入与渲染的可分类错误。
public enum InkLaTeXError: Error, Equatable, Sendable {
  case emptyExpression
  case contentTooLong(limit: Int)
  case unclosedDelimiter(InkLaTeXDelimiter)
  case unbalancedBraces
  case invalidDisplayContext
  case imageTooLarge
  case renderingFailed(String)
}

extension InkLaTeXError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .emptyExpression:
      return "LaTeX 表达式为空。"
    case .contentTooLong(let limit):
      return "LaTeX 表达式超过 \(limit) 个字符的上限。"
    case .unclosedDelimiter(let delimiter):
      return "LaTeX 分隔符未闭合：\(delimiter.rawValue)。"
    case .unbalancedBraces:
      return "LaTeX 花括号未配对。"
    case .invalidDisplayContext:
      return "LaTeX 显示上下文无效。"
    case .imageTooLarge:
      return "LaTeX 渲染结果超过允许的图片尺寸。"
    case .renderingFailed(let message):
      return "LaTeX 渲染失败：\(message)"
    }
  }
}

/// 仅负责 Markdown LaTeX 分隔符识别；不改动现有 Markdown 解析器。
public enum InkLaTeXSyntax {
  /// 识别 `$...$`、`\\(...\\)` 与 `$$...$$`，并忽略由奇数个反斜杠转义的分隔符。
  public static func parse(_ source: String) -> Result<[InkLaTeXExpression], InkLaTeXError> {
    var expressions: [InkLaTeXExpression] = []
    var index = source.startIndex

    while index < source.endIndex {
      if hasPrefix("$$", in: source, at: index), !isEscaped(source, at: index) {
        guard let close = findClosing("$$", in: source, after: source.index(index, offsetBy: 2)) else {
          return .failure(.unclosedDelimiter(.blockDollar))
        }
        let contentStart = source.index(index, offsetBy: 2)
        let content = String(source[contentStart..<close])
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          return .failure(.emptyExpression)
        }
        let end = source.index(close, offsetBy: 2)
        expressions.append(expression(content, delimiter: .blockDollar, source: source, start: index, end: end))
        index = end
        continue
      }

      if hasPrefix("\\(", in: source, at: index), !isEscaped(source, at: index) {
        guard let close = findClosing("\\)", in: source, after: source.index(index, offsetBy: 2)) else {
          return .failure(.unclosedDelimiter(.inlineParentheses))
        }
        let contentStart = source.index(index, offsetBy: 2)
        let content = String(source[contentStart..<close])
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          return .failure(.emptyExpression)
        }
        let end = source.index(close, offsetBy: 2)
        expressions.append(expression(content, delimiter: .inlineParentheses, source: source, start: index, end: end))
        index = end
        continue
      }

      if source[index] == "$", !isEscaped(source, at: index) {
        let contentStart = source.index(after: index)
        guard let close = findInlineDollarClosing(in: source, after: contentStart) else {
          return .failure(.unclosedDelimiter(.inlineDollar))
        }
        let content = String(source[contentStart..<close])
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !content.contains("\n") else {
          return .failure(.emptyExpression)
        }
        let end = source.index(after: close)
        expressions.append(expression(content, delimiter: .inlineDollar, source: source, start: index, end: end))
        index = end
        continue
      }

      index = source.index(after: index)
    }

    return .success(expressions)
  }

  private static func expression(
    _ latex: String,
    delimiter: InkLaTeXDelimiter,
    source: String,
    start: String.Index,
    end: String.Index
  ) -> InkLaTeXExpression {
    let location = start.utf16Offset(in: source)
    let length = end.utf16Offset(in: source) - location
    return InkLaTeXExpression(latex: latex, delimiter: delimiter, utf16Range: NSRange(location: location, length: length))
  }

  private static func findInlineDollarClosing(in source: String, after start: String.Index) -> String.Index? {
    var index = start
    while index < source.endIndex {
      if source[index] == "$", !isEscaped(source, at: index), !hasPrefix("$$", in: source, at: index) {
        return index
      }
      index = source.index(after: index)
    }
    return nil
  }

  private static func findClosing(_ delimiter: String, in source: String, after start: String.Index) -> String.Index? {
    var index = start
    while index < source.endIndex {
      if hasPrefix(delimiter, in: source, at: index), !isEscaped(source, at: index) {
        return index
      }
      index = source.index(after: index)
    }
    return nil
  }

  private static func hasPrefix(_ prefix: String, in source: String, at index: String.Index) -> Bool {
    source[index...].hasPrefix(prefix)
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
