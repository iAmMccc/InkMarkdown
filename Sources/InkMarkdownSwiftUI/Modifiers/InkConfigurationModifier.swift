//
//  InkConfigurationModifier.swift
//  InkMarkdownSwiftUI
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI
import InkMarkdown

private struct InkConfigurationKey: EnvironmentKey {
  static let defaultValue: InkConfiguration? = nil
}

public extension EnvironmentValues {
  /// InkMarkdown 渲染配置环境值。
  var inkConfiguration: InkConfiguration? {
    get { self[InkConfigurationKey.self] }
    set { self[InkConfigurationKey.self] = newValue }
  }
}

public extension View {
  /// 为当前视图层级注入统一的 InkMarkdown 渲染配置。
  ///
  /// 子层级中的 ``InkMarkdownView`` 若未显式传入配置，将自动读取此环境配置。
  ///
  /// ```swift
  /// var config = InkConfiguration.standard
  /// config.appearance.text.fontSize = 18
  ///
  /// ContentView()
  ///   .inkConfiguration(config)
  /// ```
  ///
  /// - Parameter configuration: 自定义渲染配置，包含样式外观、链接点击回调、自定义块处理器等。
  /// - Returns: 注入了指定渲染配置的视图。
  func inkConfiguration(_ configuration: InkConfiguration) -> some View {
    environment(\.inkConfiguration, configuration)
  }
}
