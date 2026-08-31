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
    guard let imageNode else { return nil }
    guard let urlString = imageNode.source, let url = URL(string: urlString) else { return nil }

    let rendering = configuration.appearance.imageRendering
    guard rendering.isEnabled, rendering.promotesToBlock else { return nil }

    let policy = rendering.securityPolicy
    let source = ImageSource(
      url: url,
      stripsQuery: policy.stripsQuery,
      stripsFragment: policy.stripsFragment
    )

    guard isSecurityAllowed(source: source, rendering: rendering) else {
      return nil
    }

    return InkImageBlock(source: source, rendering: rendering)
  }
}

/// 与行内通道 ``InkAttributedRenderer`` 一致的安全策略校验。
private func isSecurityAllowed(source: ImageSource, rendering: InkImageRendering) -> Bool {
  let policy = rendering.securityPolicy

  guard policy.allowedSchemes.contains(source.scheme) else {
    return false
  }

  if source.scheme == .http || source.scheme == .https {
    if let host = source.rawURL.host {
      if policy.allowedHosts.isEmpty {
        switch policy.emptyHostPolicy {
        case .rejectAll:
          return false
        case .allowAll:
          break
        }
      } else if !policy.allowedHosts.contains(host) {
        return false
      }
    }
  }

  if source.scheme == .data {
    let dataSize = source.rawURL.absoluteString.count
    if dataSize > rendering.storeConfiguration.maxDataURLBytes {
      return false
    }
  }

  return true
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
