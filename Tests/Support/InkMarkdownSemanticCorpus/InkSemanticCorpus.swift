import Foundation

// MARK: - v0.0.2 Canonical Semantic Corpus（单一语义对齐矩阵）
//
// 本文件是 attributed / block / streaming finish / SwiftUI integration 四个呈现通道
// 共同消费的**唯一** fixture 来源。每个 fixture 声明：
//   1. Markdown 输入；
//   2. 预期语义投影（用户可观察结果：文本、inline traits、链接 destination、
//      段落样式、Block 类型、表格结构）；
//   3. 适用呈现通道；
//   4. 明确的不支持边界（spec：固定版 swift-markdown 不产生相应 AST 时记录为不支持，
//      不用字符串正则伪造语法）。
//
// 约束：此处**不得**复制四套 fixture，也**不得**引入 public production abstraction——
// 本 target 只被测试 target 依赖，不进入任何对外 product。

/// 一个 canonical fixture 对链接语义的最小预期。
public struct InkLinkExpectation: Sendable, Equatable {

  /// 链接展示文本（渲染结果中应出现的字面文本）。
  public var text: String

  /// 链接目标；`nil` 表示该文本**不应**携带 `.link` 属性（fallback 为纯文本）。
  public var destination: String?

  public init(text: String, destination: String?) {
    self.text = text
    self.destination = destination
  }

  /// 预期成为可点击链接（destination 非 nil）。
  public var isLink: Bool { destination != nil }
}

/// 一个 canonical fixture 对单个 inline run 的语义预期。
public struct InkInlineTraitExpectation: Sendable, Equatable {

  /// 用于定位 run 的文本。
  public var text: String
  /// 粗体 trait；`nil` 表示不断言。
  public var isBold: Bool?
  /// 斜体 trait；`nil` 表示不断言。
  public var isItalic: Bool?
  /// 等宽 trait；`nil` 表示不断言。
  public var isMonospace: Bool?
  /// 行内代码背景身份；`nil` 表示不断言。
  public var hasInlineCodeBackground: Bool?

  public init(
    text: String,
    isBold: Bool? = nil,
    isItalic: Bool? = nil,
    isMonospace: Bool? = nil,
    hasInlineCodeBackground: Bool? = nil
  ) {
    self.text = text
    self.isBold = isBold
    self.isItalic = isItalic
    self.isMonospace = isMonospace
    self.hasInlineCodeBackground = hasInlineCodeBackground
  }
}

/// 一个 fixture 对段落几何（缩进/悬挂/固定行高）的最小预期。
public struct InkParagraphExpectation: Sendable, Equatable {

  /// 用于定位段落的文本片段。
  public var anchor: String

  /// 预期 `headIndent`（正文悬挂起点）；`nil` 表示不断言。
  public var headIndent: CGFloat?

  /// 预期 `firstLineHeadIndent`（marker 行缩进）；`nil` 表示不断言。
  public var firstLineHeadIndent: CGFloat?

  /// 预期固定行高（`minimumLineHeight == maximumLineHeight`）；`nil` 表示不断言。
  public var lineHeight: CGFloat?

  public init(
    anchor: String,
    headIndent: CGFloat? = nil,
    firstLineHeadIndent: CGFloat? = nil,
    lineHeight: CGFloat? = nil
  ) {
    self.anchor = anchor
    self.headIndent = headIndent
    self.firstLineHeadIndent = firstLineHeadIndent
    self.lineHeight = lineHeight
  }
}

/// 一个 fixture 对块级路由结果的最小预期（按顺序出现的 Block 类型）。
public struct InkBlockTypeExpectation: Sendable, Equatable {

  /// 期望出现的 Block 类型名（如 `InkTableBlock`、`InkAttributedTextBlock`）。
  public var typeName: String

  /// 期望该类型出现的次数；`nil` 表示只要求「至少一次」。
  public var count: Int?

  public init(typeName: String, count: Int? = nil) {
    self.typeName = typeName
    self.count = count
  }
}

/// fixture 适用的呈现通道。
public struct InkPresentationChannel: OptionSet, Sendable {

  public let rawValue: UInt

  public init(rawValue: UInt) { self.rawValue = rawValue }

  /// `InkAttributedRenderer` 富文本通道。
  public static let attributed = InkPresentationChannel(rawValue: 1 << 0)
  /// `InkBlockRenderer` 块路由通道（含富文本 fallback 块）。
  public static let block = InkPresentationChannel(rawValue: 1 << 1)
  /// `InkStreamRenderer` 流式 finish 终态通道。
  public static let streamingFinish = InkPresentationChannel(rawValue: 1 << 2)
  /// SwiftUI adapter 集成通道（静态 + promotion 后）。
  public static let swiftUI = InkPresentationChannel(rawValue: 1 << 3)

  /// 全部通道。
  public static let all: InkPresentationChannel = [.attributed, .block, .streamingFinish, .swiftUI]
}

/// 一个 fixture 对表格结构（headers / rows / alignments）的最小预期。
///
/// 单元格预期保存**原始 Markdown 文本**（与 ``InkTableBlock/rows`` 的公开契约一致，
/// 行内语义由共享 inline renderer 在呈现时解析）；对齐使用 corpus 本地枚举，
/// 避免测试支撑 target 直接依赖 swift-markdown 类型。
public struct InkTableExpectation: Sendable, Equatable {

  /// 单元格对齐（corpus 本地表示）。
  public enum Alignment: Sendable, Equatable {
    case left
    case center
    case right
  }

  /// 表头单元格（原始 Markdown）。
  public var headers: [String]

  /// 数据行（原始 Markdown；行长度必须与 headers 一致——parser 补齐契约）。
  public var rows: [[String]]

  /// 列对齐（长度与 headers 一致）。
  public var alignments: [Alignment?]

  public init(headers: [String], rows: [[String]], alignments: [Alignment?]) {
    self.headers = headers
    self.rows = rows
    self.alignments = alignments
  }
}

/// 单条 canonical fixture：Markdown 输入 + 预期语义投影 + 适用通道 + 不支持边界。
public struct InkSemanticCorpusFixture: Sendable {

  /// 流式通道按 token 边界拆分时的分片方式（缺省为按字符流切分）。
  public enum StreamingSplit: Sendable, Equatable {
    /// 整段一次 append。
    case whole
    /// 按固定字符数切分（模拟 token 流）。
    case everyCharacters(Int)
    /// 按空行（`\n\n`）边界切分。
    case blankLines
    /// 按行切分并保留换行符，覆盖表格 header / delimiter / data-row 边界。
    case lines
  }

  /// 稳定 ID（测试报告与证据引用用，不得改名）。
  public let id: String

  /// 人类可读标题。
  public let title: String

  /// Markdown 输入。
  public let markdown: String

  /// 流式分片策略。
  public let streamingSplit: StreamingSplit

  /// 预期出现的链接语义。
  public let expectedLinks: [InkLinkExpectation]

  /// 预期出现的 inline trait 语义。
  public let expectedInlineTraits: [InkInlineTraitExpectation]

  /// 预期段落几何（仅部分 fixture 需要）。
  public let expectedParagraphs: [InkParagraphExpectation]

  /// 预期表格结构（仅 block / streaming promotion 通道断言）。
  public let expectedTables: [InkTableExpectation]

  /// 预期块类型序列（仅 block 通道断言）。
  public let expectedBlockTypes: [InkBlockTypeExpectation]

  /// 适用通道；未列出的通道不得消费该 fixture。
  public let channels: InkPresentationChannel

  /// 明确的不支持边界说明（对外契约的一部分，不得删除）。
  public let unsupportedNotes: [String]

  public init(
    id: String,
    title: String,
    markdown: String,
    streamingSplit: StreamingSplit = .everyCharacters(3),
    expectedLinks: [InkLinkExpectation] = [],
    expectedInlineTraits: [InkInlineTraitExpectation] = [],
    expectedParagraphs: [InkParagraphExpectation] = [],
    expectedTables: [InkTableExpectation] = [],
    expectedBlockTypes: [InkBlockTypeExpectation] = [],
    channels: InkPresentationChannel = .all,
    unsupportedNotes: [String] = []
  ) {
    self.id = id
    self.title = title
    self.markdown = markdown
    self.streamingSplit = streamingSplit
    self.expectedLinks = expectedLinks
    self.expectedInlineTraits = expectedInlineTraits
    self.expectedParagraphs = expectedParagraphs
    self.expectedTables = expectedTables
    self.expectedBlockTypes = expectedBlockTypes
    self.channels = channels
    self.unsupportedNotes = unsupportedNotes
  }

  /// 按 fixture 声明的策略把 Markdown 拆为流式分片。
  public func streamingChunks() -> [String] {
    switch streamingSplit {
    case .whole:
      return [markdown]
    case .everyCharacters(let count):
      guard count > 0 else { return [markdown] }
      var chunks: [String] = []
      var index = markdown.startIndex
      while index < markdown.endIndex {
        let end = markdown.index(index, offsetBy: count, limitedBy: markdown.endIndex) ?? markdown.endIndex
        chunks.append(String(markdown[index..<end]))
        index = end
      }
      return chunks
    case .blankLines:
      return markdown
        .components(separatedBy: "\n\n")
        .filter { !$0.isEmpty }
        .map { $0 + "\n\n" }
    case .lines:
      let lines = markdown.components(separatedBy: "\n")
      return lines.enumerated().compactMap { index, line in
        let chunk = line + (index < lines.count - 1 ? "\n" : "")
        return chunk.isEmpty ? nil : chunk
      }
    }
  }
}

// MARK: - Corpus（关键 fixture 集合）

/// v0.0.2 canonical corpus。
///
/// ticket 01 只收录链接关键集；loose list / 混合嵌套 / 表格等 fixture 由后续
/// ticket 在同一处追加，**不得**在测试 target 内另起 fixture 集合。
public enum InkSemanticCorpus {

  /// 全部 fixture（顺序稳定，便于证据引用）。
  public static let all: [InkSemanticCorpusFixture] = [
    linkInline,
    linkReference,
    linkAutolink,
    linkRelative,
    linkUnsafeScheme,
    gfmBareURL,
    looseListContinuation,
    mixedListNesting,
    blockquoteInsideListItem,
    taskListMarkers,
    tableRichCell,
    tableEscapedPipe,
    tableEmptyAndRaggedRows,
  ]

  // MARK: 链接关键集

  /// 标准 inline 链接：链接文本 + destination 均保留。
  public static let linkInline = InkSemanticCorpusFixture(
    id: "link-inline",
    title: "标准 inline 链接",
    markdown: "前置 [文案](https://example.com/guide) 后置",
    expectedLinks: [
      InkLinkExpectation(text: "文案", destination: "https://example.com/guide"),
    ]
  )

  /// 引用链接：与 inline 链接获得相同文本与 destination（CommonMark 参考定义解析）。
  public static let linkReference = InkSemanticCorpusFixture(
    id: "link-reference",
    title: "引用链接（reference link）",
    markdown: """
    开头 [引用文案][ref] 与 [缩写][short]。

    [ref]: https://example.com/ref-target
    [short]: https://example.com/short-target
    """,
    expectedLinks: [
      InkLinkExpectation(text: "引用文案", destination: "https://example.com/ref-target"),
      InkLinkExpectation(text: "缩写", destination: "https://example.com/short-target"),
    ]
  )

  /// 标准自动链接：`<URL>` 保持 CommonMark 契约。
  public static let linkAutolink = InkSemanticCorpusFixture(
    id: "link-autolink",
    title: "标准自动链接",
    markdown: "访问 <https://example.com/auto> 了解",
    expectedLinks: [
      InkLinkExpectation(text: "https://example.com/auto", destination: "https://example.com/auto"),
    ]
  )

  /// 相对链接：destination 原样保留，由宿主按既有策略处理目标。
  public static let linkRelative = InkSemanticCorpusFixture(
    id: "link-relative",
    title: "相对链接",
    markdown: "参见 [相对文档](docs/guide.md)",
    expectedLinks: [
      InkLinkExpectation(text: "相对文档", destination: "docs/guide.md"),
    ]
  )

  /// 危险 scheme：`javascript:` fallback 为纯文本，不产生 `.link` 属性。
  public static let linkUnsafeScheme = InkSemanticCorpusFixture(
    id: "link-unsafe-scheme",
    title: "危险 scheme fallback",
    markdown: "点击 [危险](javascript:alert(1)) 文本",
    expectedLinks: [
      InkLinkExpectation(text: "危险", destination: nil),
    ],
    unsupportedNotes: [
      "javascript: 等非白名单 scheme 不渲染为链接；链接色也不应用（既有 0.0.1 契约）。",
    ]
  )

  /// GFM 裸 URL：固定版 swift-markdown 未启用 cmark-gfm autolink 扩展，
  /// 裸 URL 保持普通文本（不得伪造识别）。
  public static let gfmBareURL = InkSemanticCorpusFixture(
    id: "gfm-bare-url",
    title: "GFM 裸 URL 保守回退",
    markdown: "纯文本 https://example.org/path 结束",
    expectedLinks: [
      InkLinkExpectation(text: "https://example.org/path", destination: nil),
    ],
    unsupportedNotes: [
      "GFM bare URL autolink 未纳入支持矩阵：pinned swift-markdown 转换器未启用 autolink 扩展。",
    ]
  )

  // MARK: 列表关键集（ticket 02）

  /// loose list 续段：同一列表项的第二个段落必须继承列表缩进、悬挂缩进与固定行高。
  ///
  /// 注意：`InkAppearance.supportsDynamicType = false` 时正文行高为确定值 28，
  /// marker 宽度为 `ceil("• ".size(17pt).width)`；因此 fixture 只断言与首段相同的
  /// 固定行高与「续段 firstLine == 首 headIndent（内容列对齐）」结构由测试断言表达，
  /// 这里仅锁定确定性行高，避免把 marker 度量细节编码进 corpus。
  public static let looseListContinuation = InkSemanticCorpusFixture(
    id: "list-loose-continuation",
    title: "loose list 续段继承列表几何",
    markdown: "- 首段落在列表项内\n\n  续段仍属于同一列表项",
    expectedParagraphs: [
      InkParagraphExpectation(anchor: "续段仍属于", lineHeight: 28),
    ]
  )

  /// 有序 / 无序混合嵌套：更深层子列表在父级内容起点上累计缩进。
  public static let mixedListNesting = InkSemanticCorpusFixture(
    id: "list-mixed-nesting",
    title: "有序/无序混合嵌套累计缩进",
    markdown: "- 无序外层\n  1. 有序内层\n     - 无序深层",
    expectedParagraphs: [
      InkParagraphExpectation(anchor: "无序外层"),
      InkParagraphExpectation(anchor: "有序内层"),
      InkParagraphExpectation(anchor: "无序深层"),
    ]
  )

  /// 列表项内引用：引用内容归属对应列表项，缩进叠加列表内容起点。
  public static let blockquoteInsideListItem = InkSemanticCorpusFixture(
    id: "list-blockquote",
    title: "列表内引用归属列表项",
    markdown: "- 列表项开头\n\n  > 引用仍在列表项内",
    expectedParagraphs: [
      InkParagraphExpectation(anchor: "引用仍在列表项内", lineHeight: 24),
    ]
  )

  /// 既有任务列表契约：marker 与嵌套行为不因矩阵重构回退。
  public static let taskListMarkers = InkSemanticCorpusFixture(
    id: "list-task-markers",
    title: "任务列表标记保持既有行为",
    markdown: "- [ ] 待办事项\n- [x] 已完成事项",
    expectedLinks: [],
    unsupportedNotes: [
      "marker 形态（☐/☑）由既有 InkMarkdownTests 任务列表测试钉住；corpus 只覆盖归属与几何。",
    ]
  )

  // MARK: 表格关键集（ticket 03）

  /// 复杂单元格：强调、粗体、行内代码与链接组合保留各自 inline 语义。
  ///
  /// 行内代码内容使用 ASCII（`status`）：CJK 字符在 TextKit glyph 生成阶段会被
  /// 平台字体回退替换（SF Mono 无中文字形），属于系统渲染行为而非渲染器语义；
  /// 代码身份的 `inkInlineCodeBackground` / 链接属性在 CJK 场景下同样保留。
  public static let tableRichCell = InkSemanticCorpusFixture(
    id: "table-rich-cell",
    title: "复杂表格单元格 inline 语义",
    markdown: """
    | 名称 | 状态 | 备注 |
    | :--- | :---: | ---: |
    | **加粗** | `status` | [详情](https://example.com/cell) |
    | *斜体* | ***粗斜*** | 普通 |
    """,
    streamingSplit: .everyCharacters(3),
    expectedLinks: [
      InkLinkExpectation(text: "详情", destination: "https://example.com/cell"),
    ],
    expectedInlineTraits: [
      InkInlineTraitExpectation(text: "加粗", isBold: true),
      InkInlineTraitExpectation(
        text: "status",
        isMonospace: true,
        hasInlineCodeBackground: true
      ),
      InkInlineTraitExpectation(text: "斜体", isItalic: true),
      InkInlineTraitExpectation(text: "粗斜", isBold: true, isItalic: true),
    ],
    expectedTables: [
      InkTableExpectation(
        headers: ["名称", "状态", "备注"],
        rows: [
          ["**加粗**", "`status`", "[详情](https://example.com/cell)"],
          ["*斜体*", "***粗斜***", "普通"],
        ],
        alignments: [.left, .center, .right]
      ),
    ],
    expectedBlockTypes: [
      InkBlockTypeExpectation(typeName: "InkTableBlock", count: 1),
    ],
    channels: [.block, .streamingFinish, .swiftUI]
  )

  /// escaped pipe：转义竖线保留为单元格内容，不被拆成新列。
  ///
  /// pinned swift-markdown 实测契约：`\|` 解析为 Text("a | b")，
  /// `format()` 再序列化为未转义的 `a | b`——竖线保留在单元格内容中。
  public static let tableEscapedPipe = InkSemanticCorpusFixture(
    id: "table-escaped-pipe",
    title: "转义竖线保留在单元格内",
    markdown: """
    | 表达式 | 含义 |
    | --- | --- |
    | a \\| b | 或运算 |
    """,
    streamingSplit: .everyCharacters(2),
    expectedTables: [
      InkTableExpectation(
        headers: ["表达式", "含义"],
        rows: [["a | b", "或运算"]],
        alignments: [nil, nil]
      ),
    ],
    expectedBlockTypes: [
      InkBlockTypeExpectation(typeName: "InkTableBlock", count: 1),
    ],
    unsupportedNotes: [
      "escaped pipe 保留为单元格字面内容；format() 不再转义输出（pinned swift-markdown 实测）。",
    ]
  )

  /// 空单元格与不齐行：renderer 按 parser 结构稳定呈现（GFM 补齐/忽略契约）。
  public static let tableEmptyAndRaggedRows = InkSemanticCorpusFixture(
    id: "table-empty-ragged",
    title: "空单元格与不齐行稳定呈现",
    markdown: """
    | A | B | C |
    | --- | --- | --- |
    | 1 |  |
    | 2 | 3 | 4 | 5 |
    """,
    streamingSplit: .lines,
    expectedTables: [
      InkTableExpectation(
        headers: ["A", "B", "C"],
        rows: [
          ["1", "", ""],
          ["2", "3", "4"],
        ],
        alignments: [nil, nil, nil]
      ),
    ],
    expectedBlockTypes: [
      InkBlockTypeExpectation(typeName: "InkTableBlock", count: 1),
    ],
    channels: [.block, .streamingFinish, .swiftUI]
  )
}
