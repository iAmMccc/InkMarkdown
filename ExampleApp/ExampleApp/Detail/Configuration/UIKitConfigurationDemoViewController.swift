//
//  UIKitConfigurationDemoViewController.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import UIKit
import InkMarkdown

/// UIKit 样式配置与动态主题演示控制器（与 SwiftUI Configuration Demo 1:1 对齐）。
final class UIKitConfigurationDemoViewController: UIViewController {

  private var usesLargeText = false
  private var usesCompactSpacing = false

  private let markdown = """
    # 配置驱动的 Markdown (UIKit)

    当前配置直接驱动 UIKit rendering engine。修改配置项后，无需销毁全局实例，传入新 `InkConfiguration` 即可重新排版。

    ## 配置项

    - 正文字号与行高
    - 标题字号
    - 段落间距
    - 链接颜色
    """

  private let scrollView = UIScrollView()
  private let contentView = UIView()
  private var blockViews: [UIView] = []

  private let controlContainer = UIView()
  private let largeTextSwitch = UISwitch()
  private let compactSpacingSwitch = UISwitch()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "UIKit 样式配置"
    view.backgroundColor = .systemBackground
    setupUI()
    renderContent()
  }

  private func setupUI() {
    view.addSubview(scrollView)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(contentView)
    contentView.translatesAutoresizingMaskIntoConstraints = false

    controlContainer.backgroundColor = .secondarySystemBackground
    controlContainer.layer.cornerRadius = 10
    controlContainer.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(controlContainer)

    let largeTextRow = makeToggleRow(title: "放大正文与标题", toggle: largeTextSwitch, isOn: usesLargeText, action: #selector(toggleLargeText))
    let compactRow = makeToggleRow(title: "收紧段落间距", toggle: compactSpacingSwitch, isOn: usesCompactSpacing, action: #selector(toggleCompactSpacing))

    let stack = UIStackView(arrangedSubviews: [largeTextRow, compactRow])
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

  @objc private func toggleLargeText() {
    usesLargeText = largeTextSwitch.isOn
    renderContent()
  }

  @objc private func toggleCompactSpacing() {
    usesCompactSpacing = compactSpacingSwitch.isOn
    renderContent()
  }

  private func renderContent() {
    for v in blockViews { v.removeFromSuperview() }
    blockViews.removeAll()

    var config = InkConfiguration.standard
    config.appearance.text.fontSize = usesLargeText ? 20 : 17
    config.appearance.text.lineHeight = usesLargeText ? 32 : 28
    config.appearance.text.paragraphSpacing = usesCompactSpacing ? 6 : 12
    config.appearance.heading.h1FontSize = usesLargeText ? 28 : 21
    config.appearance.heading.h1LineHeight = usesLargeText ? 36 : 30
    config.appearance.link.color = .systemBlue

    let blocks = InkBlockRenderer.render(markdown, configuration: config)
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
