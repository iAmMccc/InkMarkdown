//
//  InkConfigurationModifierTests.swift
//  InkMarkdownSwiftUITests
//
//  Created by InkMarkdown on 2026/8/18.
//

import Testing
import SwiftUI
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@Suite("InkConfigurationModifier 契约测试")
@MainActor
struct InkConfigurationModifierTests {

  @Test("Environment key 默认值为 nil")
  func environment_defaultValueIsNil() {
    let env = EnvironmentValues()
    #expect(env.inkConfiguration == nil)
  }

  @Test("手动设置 EnvironmentValues.inkConfiguration 可读写")
  func environment_explicitAssignment() {
    var env = EnvironmentValues()
    #expect(env.inkConfiguration == nil)

    var config = InkConfiguration.standard
    config.appearance.text.fontSize = 20

    env.inkConfiguration = config
    #expect(env.inkConfiguration != nil)
    #expect(env.inkConfiguration?.appearance.text.fontSize == 20)
  }

  @Test("View.inkConfiguration 修饰符可正确调用并返回 View")
  func viewModifier_application() {
    var config = InkConfiguration.standard
    config.appearance.text.fontSize = 22
    config.appearance.codeBlock.fontSize = 16

    let baseView = SwiftUI.Text("测试文本")
    let modifiedView = baseView.inkConfiguration(config)

    #expect(String(describing: type(of: modifiedView)).contains("ModifiedContent"))
  }

  @Test("嵌套视图使用 inkConfiguration 修饰符可链式构建")
  func modifier_chainedHierarchy() {
    var config = InkConfiguration.standard
    config.appearance.heading.h1FontSize = 26

    let view = VStack {
      SwiftUI.Text("Child 1")
      SwiftUI.Text("Child 2")
    }
    .inkConfiguration(config)

    _ = view
  }
}
