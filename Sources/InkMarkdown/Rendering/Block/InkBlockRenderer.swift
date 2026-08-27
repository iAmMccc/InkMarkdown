import UIKit
import Markdown

/// Block 路由渲染器：把 Markup 树拆成若干 `InkRenderableBlock`。
///
/// 按 `InkConfiguration.blockHandlers` 注册顺序匹配 Markup 节点类型：
/// 命中则交由 handler 渲染为自定义 UIView，未命中则累积到富文本通道。
///
/// 核心库默认注册代码块和表格（`InkCodeBlockHandler` / `InkTableBlockHandler`）。
/// 业务方可覆盖或追加自定义 handler，实现 Open-Closed 扩展。
public enum InkBlockRenderer {

  @MainActor
  public static func render(_ source: String) -> [InkRenderableBlock] {
    render(source, configuration: .standard)
  }

  public static func render(
    _ source: String,
    configuration: InkConfiguration
  ) -> [InkRenderableBlock] {
    let filtered = configuration.sourcePreparedForParsing(source)
    let document = InkParser.parse(filtered)
    var blocks: [InkRenderableBlock] = []
    var pendingMarkup: [Markup] = []

    func flushPendingAsAttributed() {
      guard !pendingMarkup.isEmpty else { return }
      let attributed = InkAttributedRenderer.render(markups: pendingMarkup, configuration: configuration)
      pendingMarkup.removeAll()
      if attributed.length > 0 {
        blocks.append(InkAttributedTextBlock(
          attributedText: attributed,
          insets: configuration.appearance.text.blockInsets,
          linkTapHandler: configuration.linkTapHandler
        ))
      }
    }

    var handlers = configuration.blockHandlers
    if configuration.appearance.imageRendering.isEnabled
      && configuration.appearance.imageRendering.promotesToBlock {
      handlers.insert(InkImageBlockHandler(), at: 0)
    }
    if configuration.appearance.mermaidRendering.isEnabled {
      handlers.insert(InkMermaidBlockHandler(), at: 0)
    }
    if configuration.appearance.latexRendering.isEnabled {
      handlers.insert(InkLaTeXBlockHandler(), at: 0)
    }

    let children = Array(document.children)
    var index = 0
    while index < children.count {
      if let consumed = handlers.lazy.compactMap({
        $0.consumeBlocks(from: children, startingAt: index, configuration: configuration)
      }).first {
        flushPendingAsAttributed()
        blocks.append(contentsOf: consumed.blocks)
        index += consumed.consumedCount
      } else {
        pendingMarkup.append(children[index])
        index += 1
      }
    }
    flushPendingAsAttributed()
    return InkBlockIdentityStamper.stamp(blocks, documentEpoch: InkDocumentEpoch.hash(filtered))
  }
}
