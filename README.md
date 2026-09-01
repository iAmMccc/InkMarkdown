# InkMarkdown

[简体中文](README.zh-CN.md)

[![Swift](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Deployment](https://img.shields.io/badge/Deployment-iOS%2014.0-lightgrey.svg)](https://developer.apple.com/ios/)
[![UIKit](https://img.shields.io/badge/Framework-UIKit%20First-blue.svg)](https://developer.apple.com/documentation/uikit)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

InkMarkdown is a **UIKit-first** Markdown parsing and rendering framework built on Apple's [`swift-markdown`](https://github.com/swiftlang/swift-markdown). It transforms the Markup AST into native `NSAttributedString` rich text and native block `UIView`s, while providing a frame-paced incremental renderer for AI streaming applications.

> 📌 **Product scope**: the released `0.0.1` public beta supports UIKit hosts. The unreleased `0.0.2` branch includes the optional `InkMarkdownSwiftUI` adapter product, so SwiftUI hosts reuse the same rendering semantics without a second native SwiftUI renderer. The manifests declare iOS/iPadOS 14.0 as the deployment boundary and exclude other Apple platforms; this is not yet a claim of delivered minimum-OS runtime support. The SwiftUI ExampleApp compiles with a 14.0 deployment target, while iOS/iPadOS 14 runtime validation, accessibility coverage, and performance baselines remain `0.0.2` release blockers. See the [technical design](docs/contributor-guide/08-swiftui-adapter-architecture.md) and [ADR-008](docs/decisions/ADR-008-swiftui-adapter-architecture.md). WebView/HTML wrappers remain outside the core path.

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
  - Source filtering runs once before parsing for each top-level render; nested Thought content and its following suffix reuse the prepared source without invoking the filter again.
- **Opt-in Local Diagram & Math Support**:
  - Native rendering for LaTeX formulas (`$...$`, `$$...$$`) and Mermaid diagrams via local offline image generation and bounded image storage.
- **SwiftUI Adapter (unreleased `0.0.2`)**:
  - The separate `InkMarkdownSwiftUI` product hosts the UIKit rendering engine in SwiftUI and preserves one configuration snapshot across streaming and terminal block routing.

---

## Requirements

| Toolchain / Platform | Requirement |
| --- | --- |
| Swift Toolchain | 6.2+ (Package configured with Swift 5 language mode) |
| Deployment Scope | Manifest minimum: iOS / iPadOS 14.0; minimum-OS runtime validation is still pending for unreleased `0.0.2` |
| Framework | UIKit rendering engine; optional SwiftUI adapter in unreleased `0.0.2` |

---

## Installation

For released `0.0.1`, add InkMarkdown to your `Package.swift` dependencies:

```swift
dependencies: [
  .package(url: "https://github.com/iAmMccc/InkMarkdown.git", from: "0.0.1")
]
```

Or add the repository URL directly in Xcode via **File > Add Package Dependencies...**.

### Version and Product Boundary

`0.0.1` is the released UIKit public beta. Its package exposes only the `InkMarkdown` product. The core UIKit examples in this README use that product and are the appropriate starting point for a `0.0.1` integration.

`0.0.2` is not released. The current branch adds these separate products:

- `InkMarkdownSwiftUI`: SwiftUI adapter over the UIKit rendering engine.
- `InkMarkdownLaTeX`: opt-in LaTeX renderer and generated-image loader.
- `InkMarkdownMermaid`: opt-in Mermaid renderer, resources, and generated-image loader.

The API boundary is also versioned: released `0.0.1` provides the UIKit core symbols, including `InkAttributedRenderer`, `InkBlockRenderer`, `InkStreamRenderer`, `InkConfiguration`, and `InkInlineSyntax`; unreleased `0.0.2` adds `InkMarkdownView`, `InkStreamMarkdownView`, `InkMarkdownRenderSession`, `.inkConfiguration(...)`, and the separate `InkMarkdownLaTeX.register()` / `InkMarkdownMermaid.register()` APIs.

Do not use `.package(..., from: "0.0.2")` yet. For unreleased branch validation, select an explicit branch or revision and add only the products needed by that validation. The SwiftUI and separate add-on sections below are `0.0.2`-only; do not copy their imports into an app that depends on released `0.0.1`.

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

````swift
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
````

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

### 4. Custom Configuration & Extensions (0.0.1 and later)

Configure custom appearance, inline syntax, and link handlers:

```swift
import Foundation
import InkMarkdown
import UIKit

struct CustomMentionSyntax: InkInlineSyntax {
    private let mentionPattern = try! NSRegularExpression(pattern: #"@\w+"#)

    func render(text: String, context: InkInlineContext) -> NSAttributedString? {
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        let matches = mentionPattern.matches(in: text, range: fullRange)
        guard !matches.isEmpty else { return nil }

        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: context.baseFont,
                .foregroundColor: context.textColor,
            ]
        )
        for match in matches {
            result.addAttribute(
                .foregroundColor,
                value: UIColor.systemBlue,
                range: match.range
            )
        }
        return result
    }
}

var configuration = InkConfiguration(inlineSyntaxes: [CustomMentionSyntax()])
configuration.linkTapHandler = { url, _ in
    print("User tapped link: \(url)")
    return true // Return true if handled
}

let attributed = InkAttributedRenderer.render(
    "Hello @InkMarkdown",
    configuration: configuration
)
```

`InkInlineSyntax` receives one plain-text segment plus its `InkInlineContext`. Return `nil` when the extension does not match; use the context's font and color so the result follows its containing paragraph or table cell.

### 4.1 Optional LaTeX & Mermaid (unreleased 0.0.2 only)

The current unreleased branch keeps these add-ons out of the core product. Link and import the separate products, register them before the first render, then enable their configuration:

```swift
import InkMarkdown
import InkMarkdownLaTeX
import InkMarkdownMermaid

_ = InkMarkdownLaTeX.register()
_ = InkMarkdownMermaid.register()

var configuration = InkConfiguration.standard
configuration.enableLaTeXRendering()
configuration.appearance.mermaidRendering.isEnabled = true

let attributed = InkAttributedRenderer.render(
    "Inline formula: $x^2$",
    configuration: configuration
)
```

### 5. SwiftUI Adapter (unreleased `0.0.2`)

This section applies only to the unreleased `InkMarkdownSwiftUI` product. A dependency on released `0.0.1` cannot import this module.

Add the `InkMarkdownSwiftUI` product when integrating a SwiftUI host. The adapter keeps scrolling and transport ownership in the host while reusing the UIKit rendering engine:

```swift
import SwiftUI
import InkMarkdown
import InkMarkdownSwiftUI

struct MarkdownScreen: View {
    // Keep session ownership local; promotion state drives the adapter transition.
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

For streaming, the host app feeds received deltas to `session.append(_:)`, then calls `finish()`, `cancel()`, or `reset()` as appropriate. See the [SwiftUI ExampleApp guide](docs/contributor-guide/10-swiftui-example-app.md) for the six symmetric adapter examples.

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

> Version note: in released `0.0.1`, LaTeX and Mermaid support belonged to the single `InkMarkdown` product. In unreleased `0.0.2`, they require the separate products and registration shown above.

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
  -scheme InkMarkdown-Package \
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
- 🆘 [Support](SUPPORT.md)
- 🤝 [Code of Conduct](CODE_OF_CONDUCT.md)

---

## Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md), [Support](SUPPORT.md), [Code of Conduct](CODE_OF_CONDUCT.md), and [Contributor Guide](docs/contributor-guide/README.md) before submitting pull requests or opening issues.

---

## License

InkMarkdown is released under the [MIT License](LICENSE).
