# InkMarkdown

[简体中文](README.zh-CN.md)

InkMarkdown is a Markdown rendering library built on top of Apple
[swift-markdown](https://github.com/swiftlang/swift-markdown). It currently
supports UIKit only.

The project does not try to replace `swift-markdown` as a parser. Instead, it
uses the Markup tree from `swift-markdown` and turns it into UIKit-native output:

- `NSAttributedString` for text rendering.
- UIKit block components for content that does not fit well in plain text.
- Incremental rendering for streaming Markdown, such as AI chat responses.

## Why InkMarkdown

Most modern Swift Markdown libraries focus on SwiftUI, parsing, or HTML output.
InkMarkdown focuses on the UIKit gap:

| Library type | What it usually provides | How InkMarkdown is different |
| --- | --- | --- |
| `swift-markdown` | CommonMark parsing and Markup AST | InkMarkdown adds UIKit rendering on top of the AST. |
| MarkdownUI / Textual | SwiftUI Markdown rendering | InkMarkdown currently supports UIKit only. |
| HTML / WebView renderers | HTML output or embedded web rendering | InkMarkdown renders native UIKit views and attributed text. |
| Simple attributed string renderers | Inline rich text | InkMarkdown also supports block routing, tables, code blocks, and streaming output. |

## Requirements

- Swift 6.2+
- iOS 14+

## Installation

Add InkMarkdown with Swift Package Manager:

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

Use the streaming renderer for AI-style incremental text:

```swift
let renderer = InkStreamRenderer()
renderer.bindTextView(textView)
renderer.append("## Streaming title\n")
renderer.append("Markdown content can keep growing.")
renderer.finish()
```

Customize rendering:

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
| Images | Supported as text fallback |
| Fixed line height | Supported |
| Ordered / unordered lists | Supported |
| Block quotes | Supported |
| Code blocks | Supported as attributed text and UIKit block component |
| Tables | Supported as UIKit block component |
| Thematic breaks | Supported |
| Custom inline syntax | Supported |
| Link tap callback | Supported |
| Streaming Markdown | Supported |
| SwiftUI renderer | Not supported |

## Project Structure

```text
Sources/InkMarkdown/       Library source
Tests/InkMarkdownTests/    Unit tests
ExampleApp/                UIKit example app
```

## Build and Test

```bash
swift build
swift test
```

Open the example app:

```bash
open ExampleApp/ExampleApp.xcodeproj
```

## License

See [LICENSE](LICENSE).
