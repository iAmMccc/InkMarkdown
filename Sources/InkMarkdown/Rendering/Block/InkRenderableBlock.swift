import UIKit

/// Block 路由下的最小渲染单元——每一块自行决定如何变成 UIView。
///
/// 公开扩展点只要求创建视图。块级 identity、内容比较与原地更新属于 adapter 的
/// 内部复用策略，不要求普通消费者通过 SPI 实现隐藏 witness。
@preconcurrency @MainActor
public protocol InkRenderableBlock {
  @preconcurrency @MainActor func makeView() -> UIView
}

/// 可安全参与 adapter 局部视图复用的块。
///
/// 未实现本协议的公开自定义块会在文档变化时保守重建，保证内容正确；内置块可在
/// 完整语义等价时复用视图，并在内容变化时明确表示能否原地更新。
@MainActor
public protocol InkReusableBlock: InkRenderableBlock {
  /// 判断当前块与上一次块是否拥有完全相同的可见与交互语义。
  func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool

  /// 用当前块语义更新已有视图。返回 `false` 时 adapter 必须重建视图。
  func updateExistingView(_ view: UIView) -> Bool
}
