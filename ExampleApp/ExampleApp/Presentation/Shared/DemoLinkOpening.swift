import UIKit
import InkMarkdown

/// ExampleApp 共享链接打开逻辑，供 UIKit / SwiftUI Demo 统一注入 `InkConfiguration.linkTapHandler`。
enum DemoLinkOpening {

    /// 通过系统浏览器 / 默认 App 打开链接；返回 `true` 表示已消费点击。
    @discardableResult
    @MainActor
    static func open(_ url: URL) -> Bool {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }

    /// 在目标属性的完整类型上下文中安装 handler，避免函数值跨模块转换丢失 Sendable 信息。
    static func configure(_ configuration: inout InkConfiguration) {
        configuration.setLinkTapHandler(
            { url, _ in open(url) },
            semanticIdentity: "ExampleApp.default-link-opening.v1"
        )
    }
}
