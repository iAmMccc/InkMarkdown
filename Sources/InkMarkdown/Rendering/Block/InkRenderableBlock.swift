import UIKit

/// Block 路由下的最小渲染单元——每一块自行决定如何变成 UIView。
public protocol InkRenderableBlock {
  func makeView() -> UIView
}
