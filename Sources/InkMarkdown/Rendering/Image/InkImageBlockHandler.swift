import UIKit
import Markdown

/// 独占图段落 → ``InkImageBlock`` 的块级路由处理器。
///
/// 仅当段落可提升（见 ``isPromotableImageParagraph(_:)``）且
/// ``InkImageRendering/isEnabled`` / ``InkImageRendering/promotesToBlock`` 均为真时产出块。
/// 应在 ``InkBlockRenderer`` 路由链中优先于其他 handler 注册（集成阶段处理）。
public struct InkImageBlockHandler: InkBlockHandler, InkConfigurationSemanticsProviding {

  public init() {}

  public func isSemanticallyEquivalent(to other: any InkConfigurationSemanticsProviding) -> Bool {
    other is InkImageBlockHandler
  }

  public func canHandle(_ markup: Markup) -> Bool {
    isPromotableImageParagraph(markup)
  }

  @MainActor
  public func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
    guard let paragraph = markup as? Paragraph else { return nil }
    let imageNode = paragraph.children.compactMap { $0 as? Markdown.Image }.first
    guard let imageNode, let urlString = imageNode.source else { return nil }

    let rendering = configuration.appearance.imageRendering
    guard rendering.isEnabled, rendering.promotesToBlock else { return nil }

    // 与行内通道一致的统一 source 解析：相对 URL 提供 baseURL 时解析为绝对地址，
    // 未提供时返回明确 no-base-URL 结果（回落富文本占位，不猜测来源）。
    guard case .resolved(let source) = InkImageSourceResolution.resolve(
      from: urlString,
      rendering: rendering
    ) else {
      return nil
    }

    guard rendering.securityPolicy.rejectionReason(
      for: source,
      maxDataURLBytes: rendering.storeConfiguration.maxDataURLBytes
    ) == nil else {
      return nil
    }

    return InkImageBlock(source: source, rendering: rendering)
  }
}

/// 判定段落是否为可提升的独占图段落。
///
/// 仅当 `Paragraph` 在忽略空白 `Text` 与 `SoftBreak` 后恰好包含一个 `Image` 时返回 `true`。
/// 多图、文字混排，以及位于 ListItem / BlockQuote 内的图均不应通过此判定（调用方传入的是文档直接子节点）。
func isPromotableImageParagraph(_ paragraph: Markup) -> Bool {
  guard let p = paragraph as? Paragraph else { return false }
  let children = Array(p.children)
  let nonWhitespace = children.filter { node in
    if node is SoftBreak { return false }
    if let text = node as? Text, text.string.trimmingCharacters(in: .whitespaces).isEmpty {
      return false
    }
    return true
  }
  return nonWhitespace.count == 1 && nonWhitespace.first is Markdown.Image
}
