import UIKit
import InkMarkdown

/// ExampleApp 共享链接打开逻辑，供 UIKit / SwiftUI Demo 统一注入 `InkConfiguration.linkTapHandler`。
enum DemoLinkOpening {

    /// 通过系统浏览器 / 默认 App 打开链接；返回 `true` 表示已消费点击。
    @discardableResult
    static func open(_ url: URL) -> Bool {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }

    /// 供 `InkConfiguration.linkTapHandler` 使用的闭包，与 SwiftUI adapter 默认行为一致。
    static var inkHandler: (URL, UIView) -> Bool {
        { url, _ in open(url) }
    }
}
