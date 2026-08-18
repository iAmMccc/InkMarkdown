import SwiftUI
import InkMarkdownSwiftUI

/// 展示显式配置和 `.inkConfiguration(...)` 环境注入两种用法。
struct SwiftUIConfigurationDemoView: View {

  @State private var usesLargeText = false
  @State private var usesCompactSpacing = false

  private let markdown = """
  # 配置驱动的 Markdown

  当前配置会同时影响显式传入配置的视图和通过 Environment 获取配置的视图。

  ## 配置项

  - 正文字号与行高
  - 标题字号
  - 段落间距
  - 链接颜色
  """

  private var configuration: InkConfiguration {
    var config = InkConfiguration.standard
    config.appearance.text.fontSize = usesLargeText ? 20 : 17
    config.appearance.text.lineHeight = usesLargeText ? 32 : 28
    config.appearance.text.paragraphSpacing = usesCompactSpacing ? 6 : 12
    config.appearance.heading.h1FontSize = usesLargeText ? 28 : 21
    config.appearance.heading.h1LineHeight = usesLargeText ? 36 : 30
    config.appearance.link.color = .systemBlue
    return config
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("InkConfiguration")
            .font(.title2)
            .fontWeight(.semibold)
          Text("控件改变的是同一份配置值；视图会按 SwiftUI 更新重新渲染。")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 10) {
          Toggle("放大正文与标题", isOn: $usesLargeText)
          Toggle("收紧段落间距", isOn: $usesCompactSpacing)
        }

        Divider()

        Text("显式传入 configuration")
          .font(.headline)
        InkMarkdownView(markdown, configuration: configuration)
          .frame(maxWidth: .infinity, alignment: .leading)

        Divider()

        Text("通过 Environment 注入")
          .font(.headline)
        InkMarkdownView(markdown)
          .inkConfiguration(configuration)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)
    }
    .navigationBarTitle("配置与 Environment", displayMode: .inline)
  }
}
