# InkMarkdown

[简体中文](README.zh-CN.md)

InkMarkdown is a Markdown rendering library built on Apple
[swift-markdown](https://github.com/swiftlang/swift-markdown).

**Positioning:** Apple-platform native Markdown rendering with a pluggable
pipeline (parse → transform → render). **UIKit is shipping now; SwiftUI is on
the roadmap** (same intermediate model, separate backend). It does not target
WebView / HTML-first rendering as the primary path.

The project does not replace `swift-markdown` as a parser. It consumes the
Markup tree and turns it into native UI:

- **Today (UIKit):** `NSAttributedString`, block `UIView`s, streaming for AI chat.
- **Planned (SwiftUI):** a SwiftUI backend over the same pipeline / IR, without
  forcing UIKit-only hosts to take a SwiftUI dependency for the core path.

## Why InkMarkdown

| Library type | What it usually provides | How InkMarkdown is different |
| --- | --- | --- |
| `swift-markdown` | Parsing + Markup AST | Adds a native **render layer** and (planned) transform IR on top. |
| MarkdownUI / Textual | Mature **SwiftUI** rendering | **UIKit-first** today; SwiftUI later as a **second backend**, not a fork of those APIs. |
| Microsoft SwiftStreamingMarkdown | Streaming + SwiftUI-oriented product features | Pure native stack with **block routing**, fixed line height, and host-pluggable handlers—built for embedding in existing UIKit apps first. |
| HTML / WebView renderers | HTML or embedded web | Native text + views; no WebView required for core content. |
| Simple attributed-string helpers | Inline rich text | Block routing (tables / code), streaming, and extension points. |

## Requirements

- Swift 6.2+
- iOS 14+ (current package declaration)

## Installation

```swift
.package(url: "https://github.com/<owner>/InkMarkdown.git", branch: "main")
```

## Usage

Render Markdown as `NSAttributedString`:

```swift
import InkMarkdown

let markdown = """
# Title

Hello **InkMarkdown**.
"""

let attributed = InkAttributedRenderer.render(markdown)
```

Render Markdown as UIKit blocks:

```swift
let blocks = InkBlockRenderer.render(markdown)
let views = blocks.map { $0.makeView() }
```

Streaming (AI-style incremental text):

```swift
let renderer = InkStreamRenderer()
renderer.bindTextView(textView)
renderer.append("## Streaming title\n")
renderer.append("Markdown content can keep growing.")
renderer.finish()
```

Customize:

```swift
let configuration = InkConfiguration(
  inlineSyntaxes: [MyInlineSyntax()],
  linkTapHandler: { url, view in
    // Return true when the app handles the link.
    false
  }
)

let attributed = InkAttributedRenderer.render(markdown, configuration: configuration)
```

## Current Markdown Support

| Area | Status |
| --- | --- |
| Headings | Supported |
| Paragraphs | Supported |
| Strong / emphasis | Supported |
| Inline code | Supported |
| Links | Supported |
| Images | Text fallback |
| Fixed line height | Supported |
| Ordered / unordered lists | Supported |
| Block quotes | Supported |
| Code blocks | Attributed text + UIKit block |
| Tables | UIKit block |
| Thematic breaks | Supported |
| Custom inline syntax | Supported |
| Link tap callback | Supported |
| Streaming Markdown | Supported |
| SwiftUI renderer | Roadmap (not shipped) |

## Project Structure

```text
Sources/InkMarkdown/       Library source
Tests/InkMarkdownTests/    Unit tests
ExampleApp/                UIKit example app
docs/                      Architecture, spec, roadmap
```

## Build and Test

```bash
swift build
swift test
```

```bash
open ExampleApp/ExampleApp.xcodeproj
```

## License

See [LICENSE](LICENSE).
