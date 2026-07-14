# InkMarkdown

[简体中文](README.zh-CN.md)

InkMarkdown is a **UIKit-only** Markdown rendering library built on Apple
[swift-markdown](https://github.com/swiftlang/swift-markdown). It turns the
Markup tree into `NSAttributedString` and native block `UIView`s, including an
incremental renderer for AI chat and other streaming content.

InkMarkdown deliberately does not provide a SwiftUI renderer. MarkdownUI and
Textual already serve that ecosystem; this project focuses on UIKit hosts and
does not use WebView / HTML-first rendering as its primary path.

The project does not replace `swift-markdown` as a parser. It consumes the
Markup tree and turns it into native UI:

- `NSAttributedString` for rich text.
- Block `UIView`s for tables, code blocks, and thematic breaks.
- Incremental rendering for streaming Markdown.
- Host extension points for inline syntax, block routing, source filtering,
  appearance, and link handling.

## Why InkMarkdown

| Library type | What it usually provides | How InkMarkdown is different |
| --- | --- | --- |
| `swift-markdown` | Parsing + Markup AST | Adds a UIKit-native **render layer** on top. |
| MarkdownUI / Textual | Mature **SwiftUI** rendering | Focuses on UIKit instead of duplicating their SwiftUI scope. |
| Microsoft SwiftStreamingMarkdown | Streaming + SwiftUI-oriented product features | Pure native stack with **block routing**, fixed line height, and host-pluggable handlers—built for embedding in existing UIKit apps first. |
| HTML / WebView renderers | HTML or embedded web | Native text + views; no WebView required for core content. |
| Simple attributed-string helpers | Inline rich text | Block routing (tables / code), streaming, and extension points. |

## Requirements

- Swift 6.2+
- iOS 14+ (current package declaration)

## Installation

```swift
.package(url: "https://github.com/iAmMccc/InkMarkdown.git", branch: "main")
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
| SwiftUI renderer | Not supported (out of scope) |

Tables require `InkBlockRenderer`; the attributed-string-only path does not
provide grid layout. Images currently use a text fallback, and strikethrough
keeps its content without applying a strike style. See the
[current status](docs/current-status.md) for the complete limitation list.

## Documentation

- [Documentation index](docs/README.md)
- [Current implementation status](docs/current-status.md)
- [Contributor guide](docs/contributor-guide/README.md)
- [Rendering semantics](docs/spec/README.md)
- [Roadmap](docs/roadmap.md)

## Project Structure

```text
Sources/InkMarkdown/       Library source
Tests/InkMarkdownTests/    Unit tests
ExampleApp/                UIKit example app
docs/                      Architecture, spec, roadmap
```

## Build and Test

InkMarkdown imports UIKit directly, so macOS-host `swift build` / `swift test`
fails with `no such module 'UIKit'`. Test against an iOS Simulator.

Use [XcodeBuildMCP](https://www.xcodebuildmcp.com/) first to discover the
project, select the `InkMarkdown` scheme and an available simulator, and run
the simulator tests. If the current MCP client does not expose SwiftPM package
testing, use the native fallback documented in the
[development guide](docs/contributor-guide/04-development.md#回退到原生-xcodebuild).

Latest verification: 32 tests passed, 0 failed, using the `InkMarkdown` scheme
on iPhone 17 Pro / iOS 26.5 (July 13, 2026).

```bash
open ExampleApp/ExampleApp.xcodeproj
```

## Contributing

Start with the [contributor guide](docs/contributor-guide/README.md).
Public behavior changes should include tests and matching documentation.

## License

See [LICENSE](LICENSE).
