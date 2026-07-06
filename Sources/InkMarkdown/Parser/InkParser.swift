import Markdown

/// 对 swift-markdown 解析入口的极简包装。
public enum InkParser {
  public static func parse(_ source: String) -> Document {
    Document(parsing: source)
  }
}
