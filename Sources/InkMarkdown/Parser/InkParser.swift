import Markdown

/// 对 swift-markdown 解析入口的极简包装。
/// // 为什么 刻意只包一行、不传解析选项：
/// // 将第三方 AST 隔离在这个薄壳中，避免全项目到处引用 `Document(parsing:)`。
/// // 目前不支持暴露底层解析选项，旨在收敛外部依赖，若将来需要开启特定扩展（如 Strikethrough），
/// // 统一在这里修改即可，无需修改使用侧代码。
public enum InkParser {
  public static func parse(_ source: String) -> Document {
    Document(parsing: source)
  }
}
