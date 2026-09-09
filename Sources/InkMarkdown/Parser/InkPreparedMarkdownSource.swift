import Foundation

/// 已完成顶层预处理、可直接交给 Markdown parser 的内部源码值。
///
/// 该类型用于区分原始输入与已执行 `sourceFilter` 的派生片段，避免 Thought、
/// suffix 等内部递归渲染再次触发非幂等预处理。
struct InkPreparedMarkdownSource: Equatable, Sendable {
  let value: String

  init(preparedValue: String) {
    value = preparedValue
  }

  func trimmingCharacters(in characterSet: CharacterSet) -> InkPreparedMarkdownSource {
    InkPreparedMarkdownSource(
      preparedValue: value.trimmingCharacters(in: characterSet)
    )
  }
}
