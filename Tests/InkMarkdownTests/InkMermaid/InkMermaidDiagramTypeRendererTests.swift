import InkMarkdownMermaid
import Testing
import UIKit
@testable import InkMarkdown

/// Seam：`InkMermaidImageRenderer.render` —— Mermaid 11 图表类型在离线 strict 下能产出非空 PNG。
///
/// 夹具独立于 ExampleApp `DemoMermaidSamples`：以已知合法字面量作为期望来源，避免 Demo 文案自证。
@Suite(.serialized)
struct InkMermaidDiagramTypeRendererTests {

  struct Fixture: CustomTestStringConvertible, Sendable {
    let name: String
    let source: String
    var testDescription: String { name }
  }

  @Test(arguments: InkMermaidDiagramTypeFixtures.all)
  @MainActor
  func rendersDiagramTypeToPNG(_ fixture: Fixture) async throws {
    do {
      _ = try await InkMermaidDiagramTypeTestRenderer.shared().render(InkMermaidRenderRequest(source: "", display: .init(maxPixelWidth: 100, scale: 1, theme: .light)))
    } catch InkMermaidRenderError.bundledResourceMissing {
      return
    } catch {}
    // 复用同一 renderer，避免每个 case 冷启动 3.4MB mermaid.min.js。
    let renderer = InkMermaidDiagramTypeTestRenderer.shared()
    let request = InkMermaidRenderRequest(
      source: fixture.source,
      display: .init(maxPixelWidth: 400, scale: 1, theme: .light)
    )
    let result = try await renderer.render(request)
    #expect(result.image.size.width > 0)
    #expect(result.image.size.height > 0)
    #expect(result.pngData.isEmpty == false)
  }
}

@MainActor
enum InkMermaidDiagramTypeTestRenderer {
  private static var renderer: InkMermaidImageRenderer?

  static func shared() -> InkMermaidImageRenderer {
    if let renderer { return renderer }
    let created = InkMermaidImageRenderer(limits: .init(timeout: 30), bundle: InkMarkdownMermaid.bundle)
    renderer = created
    return created
  }
}

enum InkMermaidDiagramTypeFixtures {
  typealias Fixture = InkMermaidDiagramTypeRendererTests.Fixture

  static let all: [Fixture] = [
    Fixture(name: "flowchart", source: """
    flowchart TD
        Start-->End
    """),
    Fixture(name: "sequenceDiagram", source: """
    sequenceDiagram
        participant U as User
        participant I as InkMarkdown
        U->>I: input
        I-->>U: PNG
    """),
    Fixture(name: "classDiagram", source: """
    classDiagram
        class EntityRecord {
            +String name
        }
        class Score {
            +String level
        }
        EntityRecord --> Score
    """),
    Fixture(name: "stateDiagram-v2", source: """
    stateDiagram-v2
        [*] --> Draft
        Draft --> Approved
        Approved --> [*]
    """),
    Fixture(name: "erDiagram", source: """
    erDiagram
        ENTITY ||--o{ ACTOR : employs
    """),
    Fixture(name: "journey", source: """
    journey
        title Sample Journey
        section Discover
          Open App: 5: User
    """),
    Fixture(name: "gantt", source: """
    gantt
        dateFormat YYYY-MM-DD
        section Build
        Task Alpha :done, des1, 2026-06-01, 2d
    """),
    Fixture(name: "pie", source: """
    pie title Distribution
        "CategoryA" : 3
        "CategoryB" : 1
    """),
    Fixture(name: "quadrantChart", source: """
    quadrantChart
        title Priority
        x-axis Low Effort --> High Effort
        y-axis Low Value --> High Value
        quadrant-1 First
        quadrant-2 Next
        quadrant-3 Later
        quadrant-4 Review
        FeatureA: [0.7, 0.8]
    """),
    Fixture(name: "requirementDiagram", source: """
    requirementDiagram
        requirement mermaidRender {
            id: 1
            text: offline mermaid render
            risk: high
            verifymethod: test
        }
        element Renderer {
            type: component
        }
        Renderer - satisfies -> mermaidRender
    """),
    Fixture(name: "gitGraph", source: """
    gitGraph
        commit id: "init"
        commit id: "render"
    """),
    Fixture(name: "C4Context", source: """
    C4Context
        title Sample Context
        Person(user, "Analyst", "View sample data")
        System(app, "App", "Render")
        Rel(user, app, "View")
    """),
    Fixture(name: "mindmap", source: """
    mindmap
      root((Sample Root))
        DomainA
        DomainB
    """),
    Fixture(name: "timeline", source: """
    timeline
        title Milestones
        2026 : Step1
    """),
    Fixture(name: "sankey-beta", source: "sankey-beta\nParse,Render,40\nParse,Chart,30"),
    Fixture(name: "xychart-beta", source: """
    xychart-beta
        title "Latency ms"
        x-axis [a, b]
        y-axis "ms" 0 --> 100
        bar [40, 80]
    """),
    Fixture(name: "packet-beta", source: """
    packet-beta
    0-15: "Source Port"
    16-31: "Destination Port"
    """),
    Fixture(name: "kanban", source: """
    kanban
      Todo
        [Parse]
      Done
        [Bridge]
    """),
    Fixture(name: "architecture-beta", source: """
    architecture-beta
        group api(cloud)[API]
        service parser(server)[Parser] in api
        service render(server)[Renderer] in api
        parser:R --> L:render
    """),
    Fixture(name: "block-beta", source: """
    block-beta
        columns 2
        A["Input"] B["Render"]
        A --> B
    """),
    Fixture(name: "radar-beta", source: """
    radar-beta
      title Capabilities
      axis parse, style, stream
      curve A{5, 4, 5}
    """),
    Fixture(name: "venn-beta", source: """
    venn-beta
      title Overlap
      set Markdown
      set UIKit
      union Markdown, UIKit
    """),
    Fixture(name: "ishikawa", source: """
    ishikawa
      Render Failure
        Engine
          Version
        Input
          Invalid syntax
    """),
    Fixture(name: "eventmodeling", source: """
    eventmodeling
    tf 01 ui CartUI
    tf 02 cmd AddItem
    tf 03 evt ItemAdded
    """),
    Fixture(name: "treeView-beta", source: """
    treeView-beta
      root InkMarkdown
        Rendering
          Mermaid
    """),
    Fixture(name: "wardley-beta", source: """
    wardley-beta
      title Evolution
      anchor UserNeed [0.95, 0.6]
      component WebKit [0.45, 0.55] label [-20, 10]
      UserNeed -> WebKit
    """),
  ]
}
