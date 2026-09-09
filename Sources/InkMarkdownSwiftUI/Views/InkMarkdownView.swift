//
//  InkMarkdownView.swift
//  InkMarkdownSwiftUI
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI
import InkMarkdown

/// 静态 Markdown 渲染视图。
///
/// 封装 UIKit 高性能排版引擎，将 Markdown 字符串渲染为由原生组件与富文本组成的视图层级。
/// 支持标题、代码块、表格、引用块、公式等全套 Markdown 元素。
///
/// ### 使用示例
/// ```swift
/// // 基础用法（使用标准样式）
/// InkMarkdownView("# Hello World\nThis is **InkMarkdown**.")
///
/// // 显式注入自定义配置
/// var customConfig = InkConfiguration.standard
/// customConfig.appearance.text.fontSize = 18
/// InkMarkdownView(markdown: markdownText, configuration: customConfig)
///
/// // 通过环境修饰符统一注入配置
/// VStack {
///   InkMarkdownView("### Section 1")
///   InkMarkdownView("### Section 2")
/// }
/// .inkConfiguration(customConfig)
///
/// // chat bubble：首轮 layout 前传入终态内容宽
/// InkMarkdownView(markdownText)
///   .preferredMeasurementWidth(bubbleContentWidth)
/// ```
public struct InkMarkdownView: View {

  private let markdown: String
  private let configuration: InkConfiguration?
  private let preferredMeasurementWidth: CGFloat

  @Environment(\.inkConfiguration) private var environmentConfiguration
  @Environment(\.inkPreferredMeasurementWidth) private var environmentPreferredMeasurementWidth

  /// 创建一个 Markdown 渲染视图。
  ///
  /// - Parameters:
  ///   - markdown: 需要渲染的 Markdown 源文本。
  ///   - configuration: 显式指定的渲染配置；若为 `nil`，将优先读取环境注入的 ``inkConfiguration(_:)``，回退至 `InkConfiguration.standard`。
  ///   - preferredMeasurementWidth: 宿主在首轮 layout 前提供的内容宽度（pt）；`<= 0` 时读取 ``preferredMeasurementWidth(_:)`` 环境值。
  public init(
    markdown: String,
    configuration: InkConfiguration? = nil,
    preferredMeasurementWidth: CGFloat = 0
  ) {
    self.markdown = markdown
    self.configuration = configuration
    self.preferredMeasurementWidth = preferredMeasurementWidth
  }

  /// 创建一个 Markdown 渲染视图（省略参数名）。
  ///
  /// - Parameters:
  ///   - markdown: 需要渲染的 Markdown 源文本。
  ///   - configuration: 显式指定的渲染配置；若为 `nil`，将优先读取环境注入的 ``inkConfiguration(_:)``，回退至 `InkConfiguration.standard`。
  ///   - preferredMeasurementWidth: 宿主在首轮 layout 前提供的内容宽度（pt）；`<= 0` 时读取 ``preferredMeasurementWidth(_:)`` 环境值。
  public init(
    _ markdown: String,
    configuration: InkConfiguration? = nil,
    preferredMeasurementWidth: CGFloat = 0
  ) {
    self.markdown = markdown
    self.configuration = configuration
    self.preferredMeasurementWidth = preferredMeasurementWidth
  }

  /// 解析当前生效的渲染配置。
  /// 优先级：显式传入配置 > 环境注入配置 > 默认标准配置。
  private var resolvedConfiguration: InkConfiguration {
    configuration ?? environmentConfiguration ?? .standard
  }

  private var resolvedPreferredMeasurementWidth: CGFloat {
    preferredMeasurementWidth > 0 ? preferredMeasurementWidth : environmentPreferredMeasurementWidth
  }

  public var body: some View {
    InkMarkdownRepresentable(
      markdown: markdown,
      configuration: resolvedConfiguration,
      preferredMeasurementWidth: resolvedPreferredMeasurementWidth
    )
  }
}
