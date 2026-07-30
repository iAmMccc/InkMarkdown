import Foundation

/// ExampleApp 共用的 Mermaid 图表类型样例（对齐本地打包的 Mermaid 11.16.0）。
///
/// 样例刻意避免外链图标 / HTML 标签：离线 CSP 与 `securityLevel: strict` 下这些特性会失败。
enum DemoMermaidSamples {

  /// 组件 Pager / 综合 Demo 共用的完整类型矩阵 Markdown。
  static var typeMatrixMarkdown: String {
    sections.map { section in
      """
      ## \(section.title)

      ```mermaid
      \(section.source)
      ```
      """
    }.joined(separator: "\n\n")
  }

  /// 分类型场景（综合 Demo 逐条展示）。
  static let sections: [Section] = [
    Section(title: "1. 流程图 flowchart", source: """
    flowchart TB
        subgraph Client
            A[UserInput] --> B[InkMarkdown]
            B --> C[Mermaid Bridge]
        end
        subgraph Server
            D[DataService] --> E[AIService]
        end
        C -.request.-> D
        E -.stream.-> B
    """),
    Section(title: "2. 时序图 sequenceDiagram", source: """
    sequenceDiagram
        participant U as User
        participant F as Frontend
        participant B as Backend
        participant AI as AIService
        U->>F: submit query keyword
        F->>B: fetch sample dataset
        B->>AI: call analysis API
        AI-->>B: stream analysis result
        B-->>F: push SSE chunks
        F-->>U: render diagram live
        Note over F,U: mermaid renders while streaming
    """),
    Section(title: "3. 类图 classDiagram", source: """
    classDiagram
        class EntityRecord {
            +String name
            +String externalId
            +Number metricValue
            +getScore() Score
        }
        class ActorRecord {
            +String name
            +String secretId
            +link() void
        }
        class Score {
            +String level
            +String desc
        }
        EntityRecord "1" --> "*" ActorRecord : owns
        EntityRecord "1" --> "1" Score : rating
        ActorRecord --|> EntityRecord : controls
    """),
    Section(title: "4. 状态图 stateDiagram-v2", source: """
    stateDiagram-v2
        [*] --> Draft
        Draft --> InReview : submit
        InReview --> Approved : docs complete
        InReview --> Rejected : docs missing
        Rejected --> Draft : resubmit
        Approved --> [*]
    """),
    Section(title: "5. 实体关系图 erDiagram", source: """
    erDiagram
        ENTITY ||--o{ ACTOR : employs
        ENTITY ||--|| SCORE : has
        ENTITY {
            string name
            string externalId
        }
        ACTOR {
            string name
            string secretId
        }
        SCORE {
            string level
            string desc
        }
    """),
    Section(title: "6. 用户旅程图 journey", source: """
    journey
        title Sample User Journey
        section Discover
          Open App: 5: User
          Enter keyword: 4: User
        section Understand
          View overview: 5: User
          Expand details: 3: User
        section Act
          Save item: 4: User
          Export report: 3: User
    """),
    Section(title: "7. 甘特图 gantt", source: """
    gantt
        title Project Plan
        dateFormat YYYY-MM-DD
        section Build
        Task Alpha      :done,    des1, 2026-06-01, 2026-06-03
        Task Beta       :active,  des2, 2026-06-04, 5d
        section Verify
        Task Gamma      :         des3, after des2, 3d
        Task Delta      :         des4, after des3, 1d
    """),
    Section(title: "8. 饼图 pie", source: """
    pie title Category Distribution
        "CategoryA" : 297
        "CategoryB" : 269
        "CategoryC" : 17
        "CategoryD" : 8
    """),
    Section(title: "9. 象限图 quadrantChart", source: """
    quadrantChart
        title Feature Priority Matrix
        x-axis Low Effort --> High Effort
        y-axis Low Value --> High Value
        quadrant-1 Do First
        quadrant-2 Plan Next
        quadrant-3 Defer
        quadrant-4 Reassess
        StreamRender: [0.7, 0.8]
        ChartZoom: [0.4, 0.6]
        ThemeExt: [0.6, 0.4]
        Experimental: [0.2, 0.3]
    """),
    Section(title: "10. 需求图 requirementDiagram", source: """
    requirementDiagram
        requirement offlineRender {
            id: 1
            text: offline mermaid render
            risk: high
            verifymethod: test
        }
        element Renderer {
            type: component
        }
        Renderer - satisfies -> offlineRender
    """),
    Section(title: "11. Git 图 gitGraph", source: """
    gitGraph
        commit id: "init"
        branch feat/mermaid
        checkout feat/mermaid
        commit id: "render"
        commit id: "zoom-dl"
        checkout main
        merge feat/mermaid
        commit id: "release"
    """),
    Section(title: "12. C4 架构图 C4Context", source: """
    C4Context
        title Sample System Context
        Person(user, "Analyst", "View sample reports")
        System(app, "InkMarkdown App", "Render Markdown / diagrams")
        System_Ext(llm, "AI Service", "Generate analysis text")
        Rel(user, app, "View report")
        Rel(app, llm, "Request generation")
    """),
    Section(title: "13. 思维导图 mindmap", source: """
    mindmap
      root((Sample Domain))
        DomainA
          FieldA1
          FieldA2
        DomainB
          FieldB1
          FieldB2
        DomainC
          TopicC1
          TopicC2
    """),
    Section(title: "14. 时间线 timeline", source: """
    timeline
        title Product Milestones
        2025 : Step1
             : Step2
        2026 Q1 : Step3
                : Step4
        2026 Q3 : Step5
                : Step6
    """),
    Section(title: "15. 桑基图 sankey-beta", source: """
    sankey-beta
    Parse,Render,40
    Parse,Chart,30
    Chart,WebKit,25
    Chart,Cache,5
    Render,Display,45
    """),
    Section(title: "16. XY 图 xychart-beta", source: """
    xychart-beta
        title "Render time (ms)"
        x-axis [fc, seq, cls, pie]
        y-axis "ms" 0 --> 120
        bar [80, 95, 70, 40]
        line [80, 95, 70, 40]
    """),
    Section(title: "17. 数据包图 packet-beta", source: """
    packet-beta
    0-15: "Source Port"
    16-31: "Destination Port"
    32-63: "Sequence Number"
    64-79: "Checksum"
    """),
    Section(title: "18. 看板图 kanban", source: """
    kanban
      Todo
        [Parse Markdown]
        [Upgrade Mermaid]
      Doing
        [Diagram QA]
      Done
        [Offline Bridge]
    """),
    Section(title: "19. 架构图 architecture-beta", source: """
    architecture-beta
        group api(cloud)[API]
        service parser(server)[Parser] in api
        service render(server)[Renderer] in api
        parser:R --> L:render
    """),
    Section(title: "20. 块图 block-beta", source: """
    block-beta
        columns 3
        A["Input"] B["Parse"] C["Render"]
        A --> B
        B --> C
    """),
    Section(title: "21. 雷达图 radar-beta", source: """
    radar-beta
      title Capabilities
      axis parse, style, stream, chart, ext
      curve Ink{5, 4, 5, 4, 5}
      curve Base{3, 4, 2, 1, 3}
    """),
    Section(title: "22. 韦恩图 venn-beta", source: """
    venn-beta
      title Capability Overlap
      set Markdown
      set UIKit
      set Mermaid
      union Markdown, UIKit
      union UIKit, Mermaid
    """),
    Section(title: "23. 鱼骨图 ishikawa", source: """
    ishikawa
      Render Failure
        Engine
          Version mismatch
          Syntax unsupported
        Environment
          CSP restriction
          WebKit timeout
        Input
          Invalid syntax
          Oversized source
    """),
    Section(title: "24. 事件建模图 eventmodeling", source: """
    eventmodeling
    tf 01 ui QueryUI
    tf 02 cmd SubmitQuery
    tf 03 evt QueryReceived
    tf 04 cmd RenderDiagram
    tf 05 evt DiagramReady
    """),
    Section(title: "25. 树视图 treeView-beta", source: """
    treeView-beta
      root InkMarkdown
        Parser
        Rendering
          Mermaid
          LaTeX
          Image
        Configuration
    """),
    Section(title: "26. Wardley 图 wardley-beta", source: """
    wardley-beta
      title Capability Evolution
      anchor UserNeed [0.95, 0.6] label [-15, 10]
      component Visibility [0.7, 0.4] label [-20, 10]
      component WebKitBridge [0.45, 0.55] label [-30, 10]
      component NativeRender [0.2, 0.7] label [-30, 10]
      UserNeed -> Visibility
      Visibility -> WebKitBridge
      Visibility -> NativeRender
    """),
  ]

  struct Section {
    let title: String
    let source: String
  }
}
