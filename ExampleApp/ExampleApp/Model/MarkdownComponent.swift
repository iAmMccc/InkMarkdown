import Foundation
import InkMarkdown

/// 按组件维度组织的 Markdown 演示条目（Section 1 / 2 的每一行）。
enum MarkdownComponent: String, CaseIterable {
  // Section 1: 结构类
  case headingH1
  case headingH2
  case headingH3
  case paragraph
  case blockquote
  case unorderedList
  case orderedList
  case codeBlock
  case mermaid
  case table
  case thematicBreak

  // Section 2: 内容元素
  case strong
  case emphasis
  case inlineCode
  case link
  case strikethrough
  case image
  case latex
  case escapeAndEntity

  /// 主列表 row 标题。
  var displayName: String {
    switch self {
    case .headingH1: return "一级标题 H1"
    case .headingH2: return "二级标题 H2"
    case .headingH3: return "三级标题 H3"
    case .paragraph: return "段落"
    case .blockquote: return "引用块"
    case .unorderedList: return "无序列表"
    case .orderedList: return "有序列表"
    case .codeBlock: return "代码块"
    case .mermaid: return "Mermaid 图表"
    case .table: return "表格"
    case .thematicBreak: return "分隔线"
    case .strong: return "粗体"
    case .emphasis: return "斜体"
    case .inlineCode: return "行内代码"
    case .link: return "链接"
    case .image: return "图片"
    case .latex: return "LaTeX 公式"
    case .strikethrough: return "删除线"
    case .escapeAndEntity: return "转义与实体"
    }
  }

  /// 主列表 row 副标题。
  var subtitle: String {
    switch self {
    case .headingH1: return "Markdown 最高级标题"
    case .headingH2: return "章节级标题"
    case .headingH3: return "小节级标题"
    case .paragraph: return "正文段落与换行"
    case .blockquote: return "块级引用"
    case .unorderedList: return "项目符号列表"
    case .orderedList: return "数字序号列表"
    case .codeBlock: return "围栏 / 缩进代码"
    case .mermaid: return "26 种图表类型矩阵（Mermaid 11.16）"
    case .table: return "GFM 表格"
    case .thematicBreak: return "水平分隔线"
    case .strong: return "加粗强调"
    case .emphasis: return "斜体强调"
    case .inlineCode: return "行内代码片段"
    case .link: return "行内 / 引用 / 自动链接"
    case .strikethrough: return "删除线"
    case .image: return "图片与 alt 文本"
    case .latex: return "行内 \\(...\\) 与块级 $$ / \\[...\\]"
    case .escapeAndEntity: return "反斜杠转义与 HTML 实体"
    }
  }

  /// ❓ 气泡中的详细说明。
  var helpDescription: String {
    switch self {
    case .headingH1:
      return """
      Markdown 最高级标题，表示文档主题，每篇文档通常只用一次，对应 HTML 的 <h1>。
      InkMarkdown 默认渲染为较大字号加粗文字；自定义样式可叠加左侧色条或卡片背景。
      """
    case .headingH2:
      return "二级标题用于主要章节划分，对应 <h2>。Setext 语法用 --- 下划线也可表示 H2。"
    case .headingH3:
      return "三级标题用于小节划分，对应 <h3>。ATX 语法以 ### 开头。"
    case .paragraph:
      return "由一个或多个连续非空行组成。段内软换行默认可渲染为空格；行末两空格或反斜杠可强制硬换行。"
    case .blockquote:
      return "以 > 开头的块级引用，可嵌套。常用于引用他人观点或补充说明。"
    case .unorderedList:
      return "以 - / + / * 作为标记的无序列表，支持多层嵌套与紧凑 / 松散两种形态。"
    case .orderedList:
      return "以数字 + . 或 ) 开头的有序列表。序号不必递增，渲染时按首项起始编号连续显示。"
    case .codeBlock:
      return "围栏代码块用 ``` 或 ~~~ 包裹，可选语言标签；缩进代码块需每行至少 4 空格。"
    case .mermaid:
      return """
      语言标记为 `mermaid` 的围栏代码块可本地渲染为位图。默认关闭；开启 `InkMermaidRendering.isEnabled` 后由块路由接管，失败时回退为源码展示。当前打包 Mermaid 11.16.0，组件样例覆盖 26 种图表类型。
      """
    case .table:
      return "GFM 扩展语法的表格，由管道符 | 分隔列，支持左对齐、居中、右对齐。InkMarkdown 通过 Block 路由渲染为原生 UIView 表格。"
    case .thematicBreak:
      return "由三个及以上相同字符（- / _ / *）组成的水平分隔线，用于视觉分段。"
    case .strong:
      return "用 ** 或 __ 包裹的加粗文本，对应 <strong>。"
    case .emphasis:
      return "用 * 或 _ 包裹的斜体文本，对应 <em>。下划线在词内通常不生效。"
    case .inlineCode:
      return "用反引号包裹的行内代码，内容不解析 Markdown 语法。"
    case .link:
      return "支持行内式 [text](url)、引用式 [text][ref] 与尖括号自动链接 <url>。"
    case .strikethrough:
      return "GFM 删除线 ~~这是一段删除线文本~~"
    case .image:
      return "语法与链接类似，前缀加 !。alt 文本用于无障碍与加载失败时的占位。"
    case .latex:
      return """
      数学公式 opt-in 渲染。默认识别 `\\(...\\)` 行内与 `$$...$$` / `\\[...\\]` 块级；`$...$` 需额外开启 `allowsInlineDollarDelimiter`，避免与货币符号冲突。
      """
    case .escapeAndEntity:
      return "反斜杠可转义 ASCII 标点；&copy;、&#169; 等 HTML 实体会解析为对应 Unicode 字符。"
    }
  }

  /// 该组件的最小样例 Markdown（详情页各 tab 共用同一份源码）。
  var standardSample: String {
    switch self {
    case .headingH1:
      return """
      # 值类型与引用类型

      Swift 用 struct/enum 表达值语义，用 class 表达引用语义。

      # 可选类型

      Optional 用类型系统显式表达"可能没有值"，从源头消除空指针。

      # 协议与泛型

      协议定义能力约定，泛型让同一份逻辑适配多种类型。

      # 并发模型

      async/await 与 actor 让异步代码顺序书写、数据竞争编译期可查。
      """
    case .headingH2:
      return """
      ## 这是二级标题

      用于划分主要章节。
      """
    case .headingH3:
      return """
      ### 这是三级标题

      用于小节划分。
      """
    case .paragraph:
      return """
      这是第一段正文。段内软换行
      在下一行继续。

      硬换行（行末两空格）：  
      下一行仍在同一段。

      硬换行（反斜杠）\\
      同样在同一段内。
      """
    case .blockquote:
      return """
      这是引用块上方的正文段落，用于对比正文与引用的视觉区分。

      > 这是一段引用文字，文字字号 15pt，行高 24pt。左侧有灰色竖线作为视觉标记。
      >
      > 引用块可以包含多个段落，常用于标注出处或补充说明。段与段之间保持一致的行高节奏。

      这是引用块下方的正文段落。引用块距下方元素间距为 12pt。
      """
    case .unorderedList:
      return """
      - 第一项
      - 第二项
        - 嵌套 2.1
        - 嵌套 2.2
      - 第三项

      ## 松散列表（续段归属）

      - 首段落在列表项内

        续段仍属于同一列表项，保持列表缩进与悬挂对齐。

      ## 有序 / 无序混合嵌套

      - 无序外层
        1. 有序内层
           - 无序深层

      ## 列表内引用

      - 列表项开头

        > 引用仍在列表项内，不提升为根级内容。

      ## 任务列表

      - [ ] 待办事项
      - [x] 已完成事项
      """
    case .orderedList:
      return """
      1. 第一步
      1. 第二步（序号可重复）
      1. 第三步
      """
    case .codeBlock:
      return """
      ```swift
      func greet(name: String) {
          print("Hello, \\(name)")
      }
      ```
      """
    case .mermaid:
      return DemoMermaidSamples.typeMatrixMarkdown
    case .table:
      return """
      | 序号 | 类型 | 语义 | 典型代表 | 分配方式 |
      |------|------|------|----------|----------|
      | 1 | struct | 值类型，赋值即拷贝 | CGPoint、Array、String | 栈优先 |
      | 2 | class | 引用类型，共享同一实例 | UIView、UIViewController | 堆分配 |
      | 3 | enum | 值类型，有限枚举/关联值 | Optional、Result | 栈优先 |
      | 4 | protocol | 抽象接口，定义能力约定 | Equatable、Codable | 不适用 |
      | 5 | actor | 引用类型，隔离可变状态 | 自定义并发安全类型 | 堆分配 |
      | 6 | closure | 引用类型，可捕获上下文 | 排序/回调闭包 | 堆分配 |
      | 7 | tuple | 值类型，轻量组合 | (Int, String) 返回值 | 栈优先 |
      | 8 | Array | 值类型集合，写时复制 | [Int]、[String] | 缓冲区 |
      | 9 | Dictionary | 值类型键值映射，写时复制 | [String: Int] | 缓冲区 |
      | 10 | Set | 值类型唯一集合，写时复制 | Set<Int> | 缓冲区 |

      ## 复杂单元格与链接

      | 名称 | 状态 | 备注 |
      | :--- | :---: | ---: |
      | **加粗** | `行内代码` | [打开苹果官网](https://www.apple.com) |
      | *斜体* | ***粗斜*** | [CommonMark 规范](https://spec.commonmark.org/0.31.2/) |

      ## 转义竖线与不齐行

      | 表达式 | 含义 |
      | --- | --- |
      | a \\| b | 或运算（转义竖线应留在单元格内） |
      | 空单元格见右 |  |
      | 两列 | 多余列被忽略 | 补充 |
      """
    case .thematicBreak:
      return """
      上文内容。

      ---

      下文内容。
      """
    case .strong:
      return "这是 **粗体文字** 的示例。"
    case .emphasis:
      return "这是 *斜体文字* 的示例。"
    case .inlineCode:
      return "调用 `InkAttributedRenderer.render(_:)` 即可渲染。"
    case .link:
      return """
      行内式：访问 [CommonMark 规范](https://spec.commonmark.org/0.31.2/) 了解更多。

      引用式：参见 [Swift 文档][swift-docs] 与 [Human Interface 指南][hig]。

      自动链接：<https://www.apple.com>

      相对链接（按既有策略由宿主处理）：[项目内文档](docs/guide.md)

      [swift-docs]: https://www.swift.org/documentation/
      [hig]: https://developer.apple.com/design/human-interface-guidelines/
      """
    case .strikethrough:
      return """
      普通文字与 ~~删除线~~ 混排。
      
      嵌套组合：
      
      - ~~纯删除线~~
      - **~~粗体 + 删除线~~**
      - ~~*斜体 + 删除线*~~
      - ~~`行内代码 + 删除线`~~
      """
    case .image:
      return """
      ## 图片渲染演示

      ### 网络图片
      ![网络图片](https://picsum.photos/seed/ink-medium/400/300)

      ### 行内图文混排
      这是一段文字 ![小图标](https://picsum.photos/seed/ink-icon/24/24) 中间嵌入了图片。

      ### 独占段图片（块通道）
      ![大图展示](https://picsum.photos/seed/ink-block/1200/800)

      ### 多图混排
      ![图1](https://picsum.photos/seed/ink-medium/400/300) 和 ![图2](https://picsum.photos/seed/ink-portrait/600/900)

      ### 链接图片
      [![点击跳转](https://picsum.photos/seed/ink-medium/400/300)](https://github.com)
      """
    case .latex:
      return """
      ## 行内公式

      勾股定理 \\(a^2 + b^2 = c^2\\) 是经典关系。

      二次方程求根：\\(x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}\\)

      ## 块级公式

      $$
      \\int_{0}^{1} x^2 \\, dx = \\frac{1}{3}
      $$

      \\[
      \\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}
      \\]
      """
    case .escapeAndEntity:
      return "转义：\\*星号\\*  实体：&copy; &#169;（©）"
    }
  }

  /// 该组件支持的自定义样式；为空时详情页仅 [源码][标准] 两个 tab。
  ///
  /// 重构后核心库不再内置预设配方，这里只保留能用**扩展点**演示的几种：
  /// 自定义主题（`InkAppearance`）、行内语法插件（`InkInlineSyntax`）、Block 路由。
  /// 组件详情页首位渲染样式；图片组件默认走真图 opt-in，其余保持标准占位契约。
  var primaryRenderStyle: DemoStyle {
    switch self {
    case .image:
      return .imageEnabled
    case .latex:
      return .latexEnabled
    case .mermaid:
      return .mermaidEnabled
    default:
      return .standard
    }
  }

  var customStyles: [DemoStyle] {
    switch self {
    case .headingH1:
      return [.brandedTheme, .h1ActionCard]
    case .table:
      return [.tableCard]
    case .link:
      return [.brandedTheme]
    case .image:
      // 对照 ADR-004 默认占位：真图 tab 之外保留「标准」关闭态。
      return [.standard]
    case .latex, .mermaid:
      // 开启态由 primaryRenderStyle 占首位；「标准」作为关闭态对照。
      return [.standard]
    default:
      return []
    }
  }

  /// 结构类组件列表。
  static let structuralComponents: [MarkdownComponent] = [
    .headingH1,
    .headingH2,
    .headingH3,
    .paragraph,
    .blockquote,
    .unorderedList,
    .orderedList,
    .codeBlock,
    .mermaid,
    .thematicBreak,
  ]

  /// Section 2 行内组件列表。
  static let inlineComponents: [MarkdownComponent] = [
    .strong,
    .emphasis,
    .inlineCode,
    .link,
    .strikethrough,
    .image,
    .latex,
    .escapeAndEntity,
  ]
}
