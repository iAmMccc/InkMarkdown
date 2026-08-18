import SwiftUI
import InkMarkdownSwiftUI
import InkMarkdown

/// 展示 `InkMarkdownView` 的基础静态渲染用法。
struct SwiftUIStaticMarkdownDemoView: View {

  @Environment(\.colorScheme) private var colorScheme

  private var configuration: InkConfiguration {
    DemoInkConfigurationBuilder.makeStaticConfiguration(
      userInterfaceStyle: colorScheme == .dark ? .dark : .light
    )
  }

  private let markdown = """
  # SwiftUI 中的 InkMarkdown

  `InkMarkdownView` 是一个非滚动内容视图，宿主可以像组合其他 SwiftUI 内容一样使用它。

  **静态渲染**会把完整 Markdown 交给 UIKit rendering engine，并保留标题、列表、引用、代码块和表格等既有语义。

  > 滚动容器由宿主负责，避免库和宿主同时维护滚动状态。

  ## 适合展示的内容

  - 普通段落与 **强调**
  - [链接](https://github.com/iAmMccc/InkMarkdown)
  - 行内代码：`InkMarkdownView`

  ```swift
  ScrollView {
      InkMarkdownView(markdown)
  }
  ```

  | API | 作用 |
  | --- | --- |
  | `InkMarkdownView` | 静态 Markdown |
  | `InkStreamMarkdownView` | 流式 Markdown |
  | `.inkConfiguration(...)` | 环境配置注入 |
  """

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("InkMarkdownView")
            .font(.title2)
            .fontWeight(.semibold)
          Text("宿主提供 ScrollView，adapter 只负责 Markdown 内容的测量与渲染。")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }

        Divider()

        InkMarkdownView(markdown: markdown, configuration: configuration)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)
    }
    .navigationBarTitle("静态 Markdown", displayMode: .inline)
  }
}
