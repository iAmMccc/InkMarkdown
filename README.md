# InkMarkdown

[简体中文](README.zh-CN.md)

[![Swift](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2014+-lightgrey.svg)](https://developer.apple.com/ios/)
[![UIKit](https://img.shields.io/badge/Framework-UIKit%20First-blue.svg)](https://developer.apple.com/documentation/uikit)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

InkMarkdown is a **UIKit-first** Markdown parsing and rendering framework built on Apple's [`swift-markdown`](https://github.com/swiftlang/swift-markdown). It transforms the Markup AST into native `NSAttributedString` rich text and native block `UIView`s, while providing a frame-paced incremental renderer for AI streaming applications.

> 📌 **Product scope**: the released `0.0.1` public beta supports UIKit hosts. The unreleased `0.0.2` branch includes the optional `InkMarkdownSwiftUI` adapter product, so SwiftUI hosts reuse the same rendering semantics without a second native SwiftUI renderer. Its product scope is iOS/iPadOS 14+ only; other Apple platforms are not supported. The SwiftUI ExampleApp now compiles with a 14.0 deployment target, while iPad/iOS 14 runtime validation, accessibility coverage, and performance baselines remain `0.0.2` release blockers. See the [technical design](docs/contributor-guide/08-swiftui-adapter-architecture.md) and [ADR-008](docs/decisions/ADR-008-swiftui-adapter-architecture.md). WebView/HTML wrappers remain outside the core path.

---

## Key Features

- **Dual Rendering Pipelines**:
  - **`InkAttributedRenderer`**: Converts Markdown to `NSAttributedString` with strict fixed line height and downward context passing.
  - **`InkBlockRenderer`**: Routes AST nodes into native `UIView` block components (tables, code blocks, thematic breaks, images).
- **Streaming AI Renderer (`InkStreamRenderer`)**:
  - Dual-buffer architecture (background parsing queue + CADisplayLink frame-driven output).
  - Frame-paced display with a background parsing queue and bound `UITextView` differential updates; performance claims require reproducible benchmarks.
- **Thought Process Blocks**:
  - Prefix `<think>` / `<thought>` streams become collapsible native `InkThoughtBlock` views; matching closing tags preserve the exact following Markdown suffix.
- **Extensible Architecture**:
  - Host-definable inline syntax (`InkInlineSyntax`), block routing (`InkBlockHandler`), source filtering, and link tap interception.
- **Opt-in Local Diagram & Math Support**:
  - Native rendering for LaTeX formulas (`$...$`, `$$...$$`) and Mermaid diagrams via local offline image generation and bounded image storage.
- **SwiftUI Adapter (unreleased `0.0.2`)**:
  - The separate `InkMarkdownSwiftUI` product hosts the UIKit rendering engine in SwiftUI and preserves one configuration snapshot across streaming and terminal block routing.

---

## Requirements

| Toolchain / Platform | Requirement |
| --- | --- |
| Swift Toolchain | 6.2+ (Package configured with Swift 5 language mode) |
| Target Platform | Released `0.0.1`: iOS 14.0+; unreleased `0.0.2`: iOS / iPadOS 14.0+ (iPad validation pending) |
| Framework | UIKit rendering engine; optional SwiftUI adapter in unreleased `0.0.2` |

---

## Installation

Add InkMarkdown to your `Package.swift` dependencies:

```swift
dependencies: [
  .package(url: "https://github.com/iAmMccc/InkMarkdown.git", from: "0.0.1")
]
```

Or add the repository URL directly in Xcode via **File > Add Package Dependencies...**.

---

## Quick Start

### 1. Attributed Text Rendering

Render Markdown directly into an `NSAttributedString`:

```swift
import InkMarkdown
import UIKit

let markdown = """
# InkMarkdown Title

Hello **UIKit**, this is *attributed text*.
"""

let attributedString = InkAttributedRenderer.render(markdown)
label.attributedText = attributedString
```

### 2. Block Component Rendering

Render Markdown into a list of native UIKit block components:

```swift
let markdown = """
| Header 1 | Header 2 |
| -------- | -------- |
| Cell 1   | Cell 2   |

```swift
print("Hello World")
```
"""

let blocks = InkBlockRenderer.render(markdown)
for block in blocks {
    let view = block.makeView()
    stackView.addArrangedSubview(view)
}
```

### 3. Streaming AI Output

Bind streaming Markdown chunks from SSE/WebSocket directly to a `UITextView`:

```swift
let streamRenderer = InkStreamRenderer(configuration: .standard)
streamRenderer.bindTextView(textView)

// Append received chunks
streamRenderer.append("## Streaming Response\n")
streamRenderer.append("Thinking through the solution...")

// Signal end of stream
streamRenderer.finish()
```

### 4. Custom Configuration & Extensions

Configure custom appearance, inline syntax, and link handlers:

```swift
struct CustomMentionSyntax: InkInlineSyntax {
    let pattern = #"@(\w+)"#
    func match(in text: String) -> [NSRange] { /* matching logic */ }
    func apply(to attributedString: NSMutableAttributedString, range: NSRange, context: InkTextContext) {
        attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
    }
}

var config = InkConfiguration(
    inlineSyntaxes: [CustomMentionSyntax()],
    linkTapHandler: { url, hostView in
        print("User tapped link: \(url)")
        return true // Return true if handled
    }
)

// Opt-in local LaTeX and Mermaid diagram rendering
config.enableLaTeXRendering()
config.appearance.mermaidRendering.isEnabled = true

let attributed = InkAttributedRenderer.render(markdown, configuration: config)
```

### 5. SwiftUI Adapter (unreleased `0.0.2`)

Add the `InkMarkdownSwiftUI` product when integrating a SwiftUI host. The adapter keeps scrolling and transport ownership in the host while reusing the UIKit rendering engine:

```swift
import SwiftUI
import InkMarkdownSwiftUI

struct MarkdownScreen: View {
    @StateObject private var session = InkMarkdownRenderSession()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                InkMarkdownView("# Hello SwiftUI")
                InkStreamMarkdownView(session: session)
            }
        }
    }
}
```

For configuration, pass an explicit `InkConfiguration` or inject one for a view subtree:

```swift
var configuration = InkConfiguration.standard
configuration.appearance.text.fontSize = 18

InkMarkdownView(markdown)
    .inkConfiguration(configuration)
```

For streaming, the host app feeds received deltas to `session.append(_:)`, then calls `finish()`, `cancel()`, or `reset()` as appropriate. See the [SwiftUI ExampleApp guide](docs/contributor-guide/10-swiftui-example-app.md) for the three adapter examples.

---

## Supported Syntax & Limitations

| Markdown Feature | Implementation Status | Output Format |
| --- | --- | --- |
| Headings (H1–H6) | Supported | `NSAttributedString` |
| Paragraphs & Emphasis | Supported | `NSAttributedString` |
| Inline Code | Supported | `NSAttributedString` |
| Links & Callbacks | Supported | `NSAttributedString` + `linkTapHandler` |
| Ordered / Unordered Lists | Supported | `NSAttributedString` |
| Block Quotes | Supported | `NSAttributedString` |
| Code Blocks | Supported | `NSAttributedString` / code-block `UIView` from `InkCodeBlock` |
| Tables | Supported | table `UIView` from `InkTableBlock` (`InkBlockRenderer` required) |
| Thematic Breaks | Supported | separator `UIView` from `InkThematicBreakBlock` |
| Inline Math (`$...$`) | Supported (Opt-in) | `InkImageAttachment` |
| Block Math (`$$...$$`) | Supported (Opt-in) | generated `InkImageBlock` (`InkBlockRenderer` required) |
| Mermaid Diagrams | Supported (Opt-in) | generated `InkImageBlock` (`InkBlockRenderer` required) |
| Images | Supported (Opt-in) | Text placeholder by default; enabled inline images use `InkImageAttachment`, standalone blocks use `InkImageBlock` |
| Thought Process (`<think>` / `<thought>`) | Supported | collapsible `InkThoughtBlock` from `InkBlockRenderer`; streaming prefix supported |

> ℹ️ **Note**: For complete details on rendering behavior and edge cases, see [Current Project Status](docs/current-status.md) and [Rendering Spec](docs/spec/README.md).

---

## Project Structure

```text
InkMarkdown/
├── Sources/InkMarkdown/
│   ├── Configuration/       # InkConfiguration, InkAppearance & RenderEnvironment
│   ├── Parser/              # InkParser (swift-markdown AST wrapper)
│   └── Rendering/
│       ├── AttributedString/# InkAttributedRenderer (TextKit pipeline)
│       ├── Block/           # InkBlockRenderer & InkBlockHandler routing
│       ├── Components/      # Native UIKit views (Table, CodeBlock, Separator)
│       ├── Image/           # Image store, downloader & attachment handlers
│       ├── LaTeX/           # LaTeX formula image generation & handlers
│       ├── Mermaid/         # Mermaid diagram generator & handlers
│       └── InkStreamRenderer.swift # CADisplayLink dual-buffered streaming
├── Sources/InkMarkdownSwiftUI/ # Unreleased v0.0.2 SwiftUI adapter target
├── Tests/InkMarkdownTests/   # Unit, snapshot, streaming & performance tests
├── ExampleApp/               # UIKit + SwiftUI demo app with streaming & components
└── docs/                     # Architectural decisions (ADR), specs & guides
```

---

## Building and Testing

Because InkMarkdown directly imports `UIKit`, running `swift build` or `swift test` on macOS hosts will fail with `no such module 'UIKit'`. Tests must run against an **iOS Simulator**.

### Preferred Test Execution

Use [XcodeBuildMCP](https://www.xcodebuildmcp.com/) or `xcodebuild` with an iOS Simulator target:

```bash
xcodebuild test \
  -scheme InkMarkdown \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
```

### Running the Example App

Open the Xcode project to run interactive component and streaming demos:

```bash
open ExampleApp/ExampleApp.xcodeproj
```

---

## Documentation Index

- 📖 [Documentation Hub](docs/README.md)
- 📊 [Current Project Status](docs/current-status.md)
- 🏗️ [Architecture Overview](docs/contributor-guide/02-architecture.md)
- 🧩 [SwiftUI Adapter Technical Design](docs/contributor-guide/08-swiftui-adapter-architecture.md)
- 📐 [Rendering Semantics Spec](docs/spec/README.md)
- 🛣️ [Development Roadmap](docs/roadmap.md)
- 📝 [Architecture Decision Records (ADRs)](docs/decisions/README.md)

---

## Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) and [Contributor Guide](docs/contributor-guide/README.md) before submitting pull requests or opening issues.

---

## License

InkMarkdown is released under the [MIT License](LICENSE).
