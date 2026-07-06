import UIKit
import JXSegmentedView

/// Pager 子页的公共协议：提供 tab 标题。
protocol PagerListController: UIViewController {
  var tabTitle: String { get }
}
