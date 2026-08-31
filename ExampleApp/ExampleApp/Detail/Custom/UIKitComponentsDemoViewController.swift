//
//  UIKitComponentsDemoViewController.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import UIKit
import InkMarkdown

/// UIKit 自定义组件与富媒体测试控制器（表格、图片、LaTeX 公式、Mermaid 图表，与 SwiftUI Components Demo 1:1 对齐）。
final class UIKitComponentsDemoViewController: UIViewController {

    private var enableLaTeX = true
    private var enableMermaid = true
    private var enableImage = true

    private let sampleMarkdown = """
    # UIKit 自定义组件与富媒体

    本页面展示 UIKit 渲染引擎中启用的扩展组件与块级路由：

    ## 1. 表格（可滑动、带边框与长按复制）

    | 组件类型 | 渲染方式 | 交互支持 |
    |---|---|---|
    | Table | `InkTableBlockView` | 水平滚动、长按复制纯文本 |
    | Image | `InkImageBlock` | 异步加载、点击全屏放大 |
    | LaTeX | `iosMath` 本地渲染 | 块级公式居中展示 |
    | Mermaid | `WebKit` 本地渲染 | 流程图/时序图位图生成 |

    ## 2. 块级与行内图片

    正文内嵌行内图标 ![图标](https://placehold.co/20x20/2563eb/ffffff/png?text=i) 混排展示。

    下面是独占一行的块级图（支持点击全屏查看）：

    ![自然风光](https://picsum.photos/seed/ink-comp-uikit/800/450)

    ## 3. LaTeX 数学公式

    行内公式：勾股定理 \\(a^2 + b^2 = c^2\\) 与欧拉恒等式 \\(e^{i\\pi} + 1 = 0\\)。

    块级积分公式：

    $$
    \\int_{-\\infty}^{+\\infty} e^{-x^2} dx = \\sqrt{\\pi}
    $$

    ## 4. Mermaid 流程图

    ```mermaid
    flowchart LR
        A[Markdown 源码] --> B[swift-markdown 解析]
        B --> C{节点分发}
        C -->|Table| D[InkTableBlock]
        C -->|LaTeX/Mermaid| E[本地生图]
        C -->|Text| F[NSAttributedString]
        D --> G[UIKit 容器]
        E --> G
        F --> G
    ```
    """

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var blockViews: [UIView] = []

    private let controlContainer = UIView()
    private let latexSwitch = UISwitch()
    private let mermaidSwitch = UISwitch()
    private let imageSwitch = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIKit 组件与富媒体"
        view.backgroundColor = .systemBackground
        setupUI()
        renderContent()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Controls
        controlContainer.backgroundColor = .secondarySystemBackground
        controlContainer.layer.cornerRadius = 10
        controlContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controlContainer)

        let latexRow = makeToggleRow(title: "启用 LaTeX 数学公式", toggle: latexSwitch, isOn: enableLaTeX, action: #selector(toggleLaTeX))
        let mermaidRow = makeToggleRow(title: "启用 Mermaid 流程图", toggle: mermaidSwitch, isOn: enableMermaid, action: #selector(toggleMermaid))
        let imageRow = makeToggleRow(title: "启用网络图片加载", toggle: imageSwitch, isOn: enableImage, action: #selector(toggleImage))

        let stack = UIStackView(arrangedSubviews: [latexRow, mermaidRow, imageRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        controlContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            controlContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            controlContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            controlContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: controlContainer.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: controlContainer.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: controlContainer.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: controlContainer.bottomAnchor, constant: -12),
        ])
    }

    private func makeToggleRow(title: String, toggle: UISwitch, isOn: Bool, action: Selector) -> UIView {
        let row = UIView()
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label

        toggle.isOn = isOn
        toggle.addTarget(self, action: action, for: .valueChanged)

        label.translatesAutoresizingMaskIntoConstraints = false
        toggle.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)
        row.addSubview(toggle)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            toggle.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            toggle.topAnchor.constraint(equalTo: row.topAnchor),
            toggle.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        return row
    }

    @objc private func toggleLaTeX() {
        enableLaTeX = latexSwitch.isOn
        renderContent()
    }

    @objc private func toggleMermaid() {
        enableMermaid = mermaidSwitch.isOn
        renderContent()
    }

    @objc private func toggleImage() {
        enableImage = imageSwitch.isOn
        renderContent()
    }

    private func renderContent() {
        for v in blockViews { v.removeFromSuperview() }
        blockViews.removeAll()

        var config = DemoInkConfigurationBuilder.makeComponentsConfiguration(
            enableLaTeX: enableLaTeX,
            enableMermaid: enableMermaid,
            enableImage: enableImage,
            userInterfaceStyle: traitCollection.userInterfaceStyle
        )
        if enableImage {
            config.appearance.enableDemoBlockImageTap { [weak self] in self }
        }

        let blocks = InkBlockRenderer.render(sampleMarkdown, configuration: config)
        var previousView: UIView = controlContainer

        for block in blocks {
            let view = block.makeView()
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
            blockViews.append(view)

            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                view.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 12),
            ])
            previousView = view
        }

        previousView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20).isActive = true
    }
}
