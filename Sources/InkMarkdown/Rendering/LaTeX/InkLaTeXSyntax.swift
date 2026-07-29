import Foundation

/// Markdown 中可识别的 LaTeX 分隔符。
public enum InkLaTeXDelimiter: String, Hashable, Sendable {
  /// `$...$`
  case inlineDollar
  /// `\\(...\\)`
  case inlineParentheses
  /// `$$...$$`
  case blockDollar
  /// `\\[...\\]`
  case blockBrackets
}

/// 控制 ``InkLaTeXSyntax/parse(_:options:)`` 识别哪些分隔符。
public struct InkLaTeXParseOptions: Sendable {
  /// 是否识别 `$...$` 行内分隔符。默认 `false`；即使 LaTeX 总开关开启，也需显式 opt-in。
  public var allowsInlineDollarDelimiter: Bool
  /// 是否识别经 ``InkLaTeXSourcePreservation`` 注入的占位符定界符。
  /// Markup 渲染路径应设为 `true`，并关闭 ``recognizesBackslashBracketDelimiters``。
  public var recognizesPreservedBracketDelimiters: Bool
  /// 是否识别字面量 `\(...\)` / `\[...\]`。原始源文本扫描保持 `true`；Markup 路径应设为 `false`。
  public var recognizesBackslashBracketDelimiters: Bool

  public init(
    allowsInlineDollarDelimiter: Bool = false,
    recognizesPreservedBracketDelimiters: Bool = false,
    recognizesBackslashBracketDelimiters: Bool = true
  ) {
    self.allowsInlineDollarDelimiter = allowsInlineDollarDelimiter
    self.recognizesPreservedBracketDelimiters = recognizesPreservedBracketDelimiters
    self.recognizesBackslashBracketDelimiters = recognizesBackslashBracketDelimiters
  }
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
    switch delimiter {
    case .blockDollar, .blockBrackets:
      return .block
    case .inlineDollar, .inlineParentheses:
      return .inline
    }
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
  /// 识别 `\\(...\\)`、`$$...$$`、`\\[...\\]`，以及 opt-in 的 `$...$`；
  /// 忽略由奇数个反斜杠转义的分隔符。
  public static func parse(
    _ source: String,
    options: InkLaTeXParseOptions = .init()
  ) -> Result<[InkLaTeXExpression], InkLaTeXError> {
    var expressions: [InkLaTeXExpression] = []
    var index = source.startIndex

    while index < source.endIndex {
      if options.recognizesPreservedBracketDelimiters,
         hasPrefix(InkLaTeXSourcePreservation.blockOpen, in: source, at: index) {
        guard let close = findClosing(
          InkLaTeXSourcePreservation.blockClose,
          in: source,
          after: source.index(index, offsetBy: 1)
        ) else {
          return .failure(.unclosedDelimiter(.blockBrackets))
        }
        let contentStart = source.index(after: index)
        let content = String(source[contentStart..<close])
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          return .failure(.emptyExpression)
        }
        let end = source.index(after: close)
        expressions.append(expression(content, delimiter: .blockBrackets, source: source, start: index, end: end))
        index = end
        continue
      }

      if options.recognizesPreservedBracketDelimiters,
         hasPrefix(InkLaTeXSourcePreservation.inlineOpen, in: source, at: index) {
        guard let close = findClosing(
          InkLaTeXSourcePreservation.inlineClose,
          in: source,
          after: source.index(index, offsetBy: 1)
        ) else {
          return .failure(.unclosedDelimiter(.inlineParentheses))
        }
        let contentStart = source.index(after: index)
        let content = String(source[contentStart..<close])
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          return .failure(.emptyExpression)
        }
        let end = source.index(after: close)
        expressions.append(expression(content, delimiter: .inlineParentheses, source: source, start: index, end: end))
        index = end
        continue
      }

      if options.recognizesBackslashBracketDelimiters,
         hasPrefix("\\[", in: source, at: index), !isEscaped(source, at: index) {
        guard let close = findClosing("\\]", in: source, after: source.index(index, offsetBy: 2)) else {
          return .failure(.unclosedDelimiter(.blockBrackets))
        }
        let contentStart = source.index(index, offsetBy: 2)
        let content = String(source[contentStart..<close])
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          return .failure(.emptyExpression)
        }
        let end = source.index(close, offsetBy: 2)
        expressions.append(expression(content, delimiter: .blockBrackets, source: source, start: index, end: end))
        index = end
        continue
      }

      if options.recognizesBackslashBracketDelimiters,
         hasPrefix("\\(", in: source, at: index), !isEscaped(source, at: index) {
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

      if options.allowsInlineDollarDelimiter,
         source[index] == "$", !isEscaped(source, at: index) {
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
