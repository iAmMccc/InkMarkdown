import Foundation

/// 流式场景下的行类型分类结果。
public enum InkLineKind: Equatable {
  /// 普通文本行
  case text
  /// 表格行（以 | 开头）
  case tableLine
  /// 代码块开始标记（```language）
  case codeFenceOpen(language: String?)
  /// 代码块结束标记（```）
  case codeFenceClose
  /// 分割线（---、------、***、___）
  case thematicBreak
}

/// 无状态的行分类器：根据单行内容判断其 Markdown 块类型。
///
/// 设计为纯函数，不持有状态。调用方（流式状态机）自行维护上下文。
/// 例如代码块内部的 `|` 行不应被当作表格——这由调用方在 `collectingCode`
/// 阶段跳过分类来保证，分类器本身不参与状态决策。
public enum InkLineClassifier {

  /// 对已 trim 过的行内容进行分类。
  /// - Parameter trimmedLine: 去除首尾空白后的行内容（不含换行符）。
  /// - Parameter isInsideCodeBlock: 当前是否在代码块内部。
  ///   为 true 时只识别 codeFenceClose，其他一律返回 .text。
  public static func classify(_ trimmedLine: String, isInsideCodeBlock: Bool = false) -> InkLineKind {
    if trimmedLine.hasPrefix("```") {
      if isInsideCodeBlock {
        return .codeFenceClose
      } else {
        let lang = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return .codeFenceOpen(language: lang.isEmpty ? nil : lang)
      }
    }

    if !isInsideCodeBlock && trimmedLine.hasPrefix("|") {
      return .tableLine
    }

    if !isInsideCodeBlock && isThematicBreak(trimmedLine) {
      return .thematicBreak
    }

    return .text
  }

  /// 判断是否为分割线：至少 3 个相同字符（-、*、_），可含空格，不含其他字符。
  private static func isThematicBreak(_ trimmedLine: String) -> Bool {
    guard trimmedLine.count >= 3 else { return false }
    let chars = trimmedLine.filter { $0 != " " }
    guard chars.count >= 3 else { return false }
    guard let first = chars.first, first == "-" || first == "*" || first == "_" else { return false }
    return chars.allSatisfy { $0 == first }
  }

  /// 判断一行是否为 GFM 表格分隔行（`|---|---|` 或 `|:---:|---:|`）。
  ///
  /// 供流式状态机在收到 `.tableLine` 后对下一行做二次确认：
  /// 只有紧跟分隔行的表头才是真正的表格，否则应回退为普通文本。
  ///
  /// 规则：以 `|` 分割后，每个非空 cell 去掉首尾空白满足 `:?-{3,}:?`，且至少有 1 个有效 cell。
  public static func isDelimiterRow(_ trimmedLine: String) -> Bool {
    guard trimmedLine.hasPrefix("|") else { return false }

    let cells = trimmedLine.split(separator: "|", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }

    guard !cells.isEmpty else { return false }

    for cell in cells {
      var s = cell[...]
      if s.first == ":" { s = s.dropFirst() }
      guard !s.isEmpty && s.first == "-" else { return false }
      while !s.isEmpty && s.first == "-" { s = s.dropFirst() }
      if !s.isEmpty && s.first == ":" { s = s.dropFirst() }
      guard s.isEmpty else { return false }
    }
    return true
  }
}
