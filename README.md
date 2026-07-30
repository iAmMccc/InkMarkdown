# InkMarkdown

[简体中文](README.zh-CN.md)

[![Swift](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2014+-lightgrey.svg)](https://developer.apple.com/ios/)
[![UIKit](https://img.shields.io/badge/Framework-UIKit%20Only-blue.svg)](https://developer.apple.com/documentation/uikit)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

InkMarkdown is a **UIKit-dedicated** Markdown parsing and rendering framework built on Apple's [`swift-markdown`](https://github.com/swiftlang/swift-markdown). It transforms the Markup AST into native `NSAttributedString` rich text and native block `UIView`s, while providing a frame-paced incremental renderer for AI streaming applications.

> 📌 **UIKit Scope**: InkMarkdown is designed exclusively for UIKit hosts to fill the capability gap in existing Apple Markdown libraries. It deliberately omits SwiftUI renderers (which are already served by MarkdownUI and Textual) and avoids WebView/HTML wrappers.

---

## Key Features

- **Dual Rendering Pipelines**:
  - **`InkAttributedRenderer`**: Converts Markdown to `NSAttributedString` with strict fixed line height and downward context passing.
  - **`InkBlockRenderer`**: Routes AST nodes into native `UIView` block components (tables, code blocks, thematic breaks, images).
- **Streaming AI Renderer (`InkStreamRenderer`)**:
  - Dual-buffer architecture (background parsing queue + CADisplayLink frame-driven output).
  - Smooth text display with zero main-thread parsing stutter and bound `UITextView` differential updates.
- **Extensible Architecture**:
  - Host-definable inline syntax (`InkInlineSyntax`), block routing (`InkBlockHandler`), source filtering, and link tap interception.
- **Opt-in Local Diagram & Math Support**:
  - Native rendering for LaTeX formulas (`$...$`, `$$...$$`) and Mermaid diagrams via local offline image generation and bounded image storage.

---

## Requirements

| Toolchain / Platform | Requirement |
| --- | --- |
| Swift Toolchain | 6.2+ (Package configured with Swift 5 language mode) |
| Target Platform | iOS 14.0+ |
| Framework | UIKit (No SwiftUI dependency) |

---

## Installation

Add InkMarkdown to your `Package.swift` dependencies:

```swift
dependencies: [
  .package(url: "https://github.com/iAmMccc/InkMarkdown.git", branch: "main")
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
| Code Blocks | Supported | `NSAttributedString` / `InkCodeBlockView` |
| Tables | Supported | `InkTableView` (`InkBlockRenderer` required) |
| Thematic Breaks | Supported | `InkThematicBreakView` |
| Inline Math (`$...$`) | Supported (Opt-in) | `InkImageAttachment` |
| Block Math (`$$...$$`) | Supported (Opt-in) | `InkLaTeXBlockView` (`InkBlockRenderer` required) |
| Mermaid Diagrams | Supported (Opt-in) | `InkMermaidBlockView` (`InkBlockRenderer` required) |
| Images | Supported (Opt-in) | Text placeholder by default; `InkImageBlockView` when enabled |

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
├── Tests/InkMarkdownTests/   # Unit, snapshot, streaming & performance tests
├── ExampleApp/               # UIKit demo app with SSE streaming & components
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
- 📐 [Rendering Semantics Spec](docs/spec/README.md)
- 🛣️ [Development Roadmap](docs/roadmap.md)
- 📝 [Architecture Decision Records (ADRs)](docs/decisions/README.md)

---

## Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) and [Contributor Guide](docs/contributor-guide/README.md) before submitting pull requests or opening issues.

---

## License

InkMarkdown is released under the [MIT License](LICENSE).
