//
//  SwiftUIComponentsDemoView.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI
import InkMarkdownSwiftUI
import InkMarkdown

/// 展示 SwiftUI 下自定义组件与富媒体扩展（表格、图片、LaTeX 公式、Mermaid 图表）。
struct SwiftUIComponentsDemoView: View {

  @Environment(\.colorScheme) private var colorScheme
  @State private var enableLaTeX = true
  @State private var enableMermaid = true
  @State private var enableImage = true

  private var configuration: InkConfiguration {
    DemoInkConfigurationBuilder.makeComponentsConfiguration(
      enableLaTeX: enableLaTeX,
      enableMermaid: enableMermaid,
      enableImage: enableImage,
      userInterfaceStyle: colorScheme == .dark ? .dark : .light
    )
  }

  private let sampleMarkdown = """
  # SwiftUI 自定义组件与富媒体

  本页面展示在 `InkMarkdownView` 中启用的各类扩展组件：

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

  ![自然风光](https://picsum.photos/seed/ink-comp-1/800/450)

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
      D --> G[SwiftUI 容器]
      E --> G
      F --> G
  ```
  """

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        // 控制开关卡片
        VStack(alignment: .leading, spacing: 10) {
          Text("扩展组件开关")
            .font(.headline)
          Toggle("启用 LaTeX 数学公式", isOn: $enableLaTeX)
          Toggle("启用 Mermaid 流程图", isOn: $enableMermaid)
          Toggle("启用网络图片加载", isOn: $enableImage)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)

        Divider()

        InkMarkdownView(markdown: sampleMarkdown, configuration: configuration)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
    }
    .navigationBarTitle("组件与富媒体", displayMode: .inline)
  }
}
