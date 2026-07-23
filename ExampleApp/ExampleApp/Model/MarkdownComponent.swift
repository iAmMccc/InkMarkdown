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
  case table
  case thematicBreak

  // Section 2: 内容元素
  case strong
  case emphasis
  case inlineCode
  case link
  case strikethrough
  case image
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
    case .table: return "表格"
    case .thematicBreak: return "分隔线"
    case .strong: return "粗体"
    case .emphasis: return "斜体"
    case .inlineCode: return "行内代码"
    case .link: return "链接"
    case .image: return "图片"
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
    case .table: return "GFM 表格"
    case .thematicBreak: return "水平分隔线"
    case .strong: return "加粗强调"
    case .emphasis: return "斜体强调"
    case .inlineCode: return "行内代码片段"
    case .link: return "行内 / 引用 / 自动链接"
    case .strikethrough: return "删除线"
    case .image: return "图片与 alt 文本"
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
      访问 [CommonMark 规范](https://spec.commonmark.org/0.31.2/) 了解更多。

      自动链接：<https://www.apple.com>
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
      return "![InkMarkdown 示意图](https://via.placeholder.com/160x48.png?text=InkMarkdown \"示例 title\")"
    case .escapeAndEntity:
      return "转义：\\*星号\\*  实体：&copy; &#169;（©）"
    }
  }

  /// 该组件支持的自定义样式；为空时详情页仅 [源码][标准] 两个 tab。
  ///
  /// 重构后核心库不再内置预设配方，这里只保留能用**扩展点**演示的几种：
  /// 自定义主题（`InkAppearance`）、行内语法插件（`InkInlineSyntax`）、Block 路由。
  var customStyles: [DemoStyle] {
    switch self {
    case .headingH1:
      return [.brandedTheme, .h1ActionCard]
    case .table:
      return [.tableCard]
    case .link:
      return [.brandedTheme]
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
    .escapeAndEntity,
  ]
}
