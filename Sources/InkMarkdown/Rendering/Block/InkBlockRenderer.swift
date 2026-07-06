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

  public static func render(
    _ source: String,
    configuration: InkConfiguration = .standard
  ) -> [InkRenderableBlock] {
    let filtered = configuration.sourceFilter?(source) ?? source
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
          insets: configuration.appearance.text.blockInsets
        ))
      }
    }

    for child in document.children {
      let handled = configuration.blockHandlers
        .first { $0.canHandle(child) }?
        .makeBlock(from: child, configuration: configuration)

      if let block = handled {
        flushPendingAsAttributed()
        blocks.append(block)
      } else {
        pendingMarkup.append(child)
      }
    }
    flushPendingAsAttributed()
    return blocks
  }
}
