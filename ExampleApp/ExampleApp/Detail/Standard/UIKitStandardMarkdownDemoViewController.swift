//
//  UIKitStandardMarkdownDemoViewController.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import UIKit
import InkMarkdown

/// UIKit 基础标准 Markdown 渲染演示控制器（与 SwiftUI Static Demo 1:1 对齐）。
final class UIKitStandardMarkdownDemoViewController: UIViewController {

    private let markdown = """
    # UIKit 中的 InkMarkdown

    `InkMarkdown` 是一个 UIKit-first 的 Markdown 渲染库，将 Markup 树解析渲染为 `NSAttributedString` 与块级 `UIView`。

    **静态渲染**保留所有核心语法与样式：

    > 引用块支持多行文本与嵌套样式。

    ## 适合展示的内容

    - 普通段落与 **加粗强调** 与 *斜体* 与 ~~删除线~~
    - [链接跳转测试](https://github.com/iAmMccc/InkMarkdown)
    - 行内代码：`InkAttributedRenderer`
    - 有序列表：
      1. 第一步：准备 Markdown
      2. 第二步：调用渲染引擎
      3. 第三步：赋值给视图展示

    ```swift
    import InkMarkdown

    let attributed = InkAttributedRenderer.render(markdown)
    textView.attributedText = attributed
    ```

    | API | 作用 |
    | --- | --- |
    | `InkAttributedRenderer` | 富文本渲染 |
    | `InkBlockRenderer` | 块级组件路由 |
    | `InkStreamRenderer` | 流式增量渲染 |
    """

    private let blockStackView = DemoBlockStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit 基础静态渲染"
        view.backgroundColor = .systemBackground
        setupUI()
        renderContent()
    }

    private func setupUI() {
        blockStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blockStackView)

        NSLayoutConstraint.activate([
            blockStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            blockStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blockStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blockStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func renderContent() {
        let config = DemoInkConfigurationBuilder.makeStaticConfiguration(
            userInterfaceStyle: traitCollection.userInterfaceStyle
        )
        blockStackView.render(markdown: markdown, configuration: config)
    }
}
