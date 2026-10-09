//
//  SwiftUILongTextDemoView.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI
import InkMarkdownSwiftUI
import InkMarkdown

/// 展示 SwiftUI 下超长复杂 Markdown 文档的渲染性能与分段切换。
struct SwiftUILongTextDemoView: View {

  @Environment(\.colorScheme) private var colorScheme
  @State private var displayMode: Int = 0
  @State private var markdownSource: String = ""

  private var configuration: InkConfiguration {
    DemoInkConfigurationBuilder.makeStaticConfiguration(
      userInterfaceStyle: colorScheme == .dark ? .dark : .light
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      Picker("显示模式", selection: $displayMode) {
        Text("渲染效果").tag(0)
        Text("Markdown 源码").tag(1)
      }
      .pickerStyle(SegmentedPickerStyle())
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      Divider()

      ScrollView {
        if displayMode == 0 {
          InkMarkdownView(markdown: markdownSource, configuration: configuration)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        } else {
          Text(markdownSource)
            .font(.system(.footnote, design: .monospaced))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
      }
    }
    .navigationBarTitle("综合长文与性能", displayMode: .inline)
    .onAppear {
      loadSource()
    }
  }

  private func loadSource() {
    if let text = MarkdownDetailViewController.loadMarkdown(named: "comprehensive-readme") {
      self.markdownSource = text
    } else {
      self.markdownSource = """
      # InkMarkdown 综合长文演示

      欢迎使用 **InkMarkdown**！本页面加载超长 Markdown 文本，用于验证外部 ScrollView 容器内 `InkMarkdownView` 的测量稳定性与帧率流畅度。
      """
    }
  }
}
