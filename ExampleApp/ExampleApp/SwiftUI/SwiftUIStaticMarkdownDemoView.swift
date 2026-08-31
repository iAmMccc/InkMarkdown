import SwiftUI
import InkMarkdownSwiftUI
import InkMarkdown

/// 展示 `InkMarkdownView` 的基础静态渲染用法。
struct SwiftUIStaticMarkdownDemoView: View {

  @Environment(\.colorScheme) private var colorScheme
  @State private var contentRevision = 0
  @State private var hostGeneration = 0
  @State private var includesLeadingThought = true

  private var configuration: InkConfiguration {
    DemoInkConfigurationBuilder.makeStaticConfiguration(
      userInterfaceStyle: colorScheme == .dark ? .dark : .light
    )
  }

  private var markdown: String {
    let thought = contentRevision % 2 == 0
      ? "先确认输入结构，再决定内容如何呈现。"
      : "更新后的 Thought 内容更长，用于观察折叠态与高度是否连续。"
    let adjacentParagraph = contentRevision % 2 == 0
      ? "Thought 后的普通段落与卡片相邻，用来观察首轮布局。"
      : "同一文档更新后的相邻普通段落，继续观察间距与高度。"
    let leadingThought = includesLeadingThought
      ? """
      <think>
      歧义检查 A：先折叠此卡片，再移除它；后面的 Thought 不得继承折叠态。
      </think>

      """
      : ""

    return """
  # SwiftUI 中的 InkMarkdown

  `InkMarkdownView` 是一个非滚动内容视图，宿主可以像组合其他 SwiftUI 内容一样使用它。

  **静态渲染**会把完整 Markdown 交给 UIKit rendering engine，并保留标题、列表、引用、代码块和表格等既有语义。

  > 滚动容器由宿主负责，避免库和宿主同时维护滚动状态。

  \(leadingThought)<think>
  \(thought)
  </think>

  \(adjacentParagraph)

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
  }

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

        VStack(alignment: .leading, spacing: 10) {
          Text("连续性手工验收")
            .font(.headline)
          Text("顺序：折叠第二个 Thought 后更新同一文档，确认状态连续。歧义检查时只折叠首个 Thought，再移除它，确认后一个不继承折叠态；最后新建静态 Host。caller override 在配置页检查。")
            .font(.footnote)
            .foregroundColor(.secondary)
          HStack(spacing: 8) {
            Button("更新同一文档内容") {
              contentRevision += 1
            }
            Button("新建静态 Host") {
              hostGeneration += 1
            }
          }
          Button(includesLeadingThought ? "移除首个 Thought（歧义检查）" : "恢复首个 Thought") {
            includesLeadingThought.toggle()
          }
        }

        Divider()

        InkMarkdownView(markdown: markdown, configuration: configuration)
          .frame(maxWidth: .infinity, alignment: .leading)
          .id(hostGeneration)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)
    }
    .navigationBarTitle("静态 Markdown", displayMode: .inline)
  }
}
