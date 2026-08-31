//
//  InkStreamingRemainderBlock.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import UIKit

/// 把 renderer 已绑定的 `UITextView` 表达为 adapter-only presentation candidate。
///
/// 它不构造 core renderer identity；stable identity 由 render session 作为 adapter
/// evidence 提供。文本内容已由 `InkStreamRenderer` 原地更新，本类型只让 continuity
/// 统一管理 attachment、顺序和 measurement revision。
@MainActor
struct InkStreamingRemainderBlock: InkReusableBlock {
  let textView: UITextView
  let contentRevision: UInt64

  func makeView() -> UIView {
    textView
  }

  func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    guard let previous = previous as? InkStreamingRemainderBlock else { return false }
    return previous.textView === textView
      && previous.contentRevision == contentRevision
  }

  func updateExistingView(_ view: UIView) -> Bool {
    view === textView
  }
}
