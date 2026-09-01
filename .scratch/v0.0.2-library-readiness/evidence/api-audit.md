# Public Interface and Module-Depth Audit

Date: 2026-09-01

Baseline: released tag `0.0.1`. Candidate: local `feat/swiftUI` working tree after `307d83d` plus the package-access changes described below.

## Method

- Compared public/open type declarations in `0.0.1:Sources/InkMarkdown` with the current UIKit core sources.
- Inspected every removed or changed public declaration line in the source diff and matched it to its current declaration or compatibility facade.
- Reused the external-consumer compile contracts for `InkRenderableBlock`, `InkBlockHandler`, `InkInlineSyntax`, `InkConfiguration`, closure properties, `InkImageBlock`, the legacy store initializer, and `InkImageBlockView`.
- Built all package products, ran the affected core/addon/SwiftUI contract suites, and type-checked a consumer probe that imports only `InkMarkdown`.

## Compatibility result

- No public type name from the released `0.0.1` UIKit core was removed.
- Changed declarations retain source-compatible entry points. In particular, `InkImageBlock` remains a `UIView`, `init(source:store:rendering:)` remains as a deprecated compatibility initializer, and `InkImageBlockView` remains as a deprecated alias.
- The `0.0.1`-style external extension fixture still compiles without adding `Sendable`, actor, or SPI requirements.
- This is a source-compatibility audit. The package does not enable library evolution and does not claim binary compatibility.

## Deepening correction

The following unreleased implementation seams were public only so sibling package targets could communicate:

- `InkGeneratedAddonRuntime`;
- `InkLaTeXRenderingProviding` and `InkMermaidRenderingProviding`;
- `InkThoughtScanner` and its streaming state;
- `InkThoughtPresentationPolicy`.

They are now `package` or `internal`. `InkMarkdownSwiftUI`, `InkMarkdownLaTeX`, `InkMarkdownMermaid`, and package tests retain access, while an external consumer importing only `InkMarkdown` cannot name them. This narrows the public interface without removing any released `0.0.1` API.

## Validation

- `InkMarkdown-Package` build: passed.
- Affected contract selection: 72 passed, 0 failed, 1 skipped on iPhone 16 Pro / iOS 18.5.
- External package-access probe: compilation failed at each implementation seam with `cannot find ... in scope`, confirming those names are absent from the consumer interface.
- Existing deprecated API warnings are expected compatibility signals; no deprecated facade was removed.

## Open boundary

The new SwiftUI adapter and separate addon products are unreleased `0.0.2` interfaces. Their consumer-facing entry points remain public; package registries, scanners, and backend provider protocols are not consumer contracts.
