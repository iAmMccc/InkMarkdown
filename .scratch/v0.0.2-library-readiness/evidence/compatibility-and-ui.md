# Compatibility and ExampleApp Evidence

Date: 2026-09-01

Candidate: `feat/swiftUI` readiness change set, including the public-interface narrowing and ExampleApp observation fix recorded in the local task. The immutable PR head SHA and GitHub check metadata are the remote evidence; do not create a post-CI evidence commit merely to copy them into this file.

## Available runtime matrix

| Host | Runtime | ExampleApp Debug | Manual result |
| --- | --- | --- | --- |
| iPad Pro 11-inch (M5) | iOS 26.5 | XcodeBuildMCP build/install/launch passed in 12.0s | passed for the key static, component, configuration, and streaming paths |
| iPhone 16 Pro | iOS 18.5 | XcodeBuildMCP build/install/launch passed in 8.6s | passed for narrow-layout and key state paths |

This machine only exposes iOS 18.5 and iOS 26.5 runtimes. iOS/iPadOS 14 execution remains an environment blocker; the deployment target was not raised.

## iPad manual walkthrough

### Static Markdown

- Both Thought cards kept their complete body inside the gray card background; adjacent ordinary Markdown remained outside the card.
- Collapsing the second Thought and updating the same document preserved its collapsed state.
- The ambiguity fixture kept the two Thought identities independent.

### Components and configuration

- The table remained horizontally scrollable and contained; inline and block LaTeX rendered.
- The Mermaid flowchart produced a visible diagram.
- The network-image fixture remained at its placeholder during this run, so external image loading was not claimed as verified.
- Explicit and Environment-provided configurations rendered the same Thought boundary and inline-code background.
- Turning Thought collapsing off expanded the card and removed the fold affordance; turning it on restored the prior fold state.
- Changing text sizing refreshed mounted content without losing fold state.

### Streaming continuity

- A streaming Thought was collapsed, received another fragment, changed width, was unmounted/remounted, closed, and promoted to final content without losing collapse state.
- After promotion, the label became `已深度思考`, the suffix `Thought 后的普通回答。` remained outside the card, and the session reached `finished`.
- Switching to the accessibility-extra-large render environment enlarged the card and suffix immediately while retaining the collapsed state.

The first walkthrough exposed an ExampleApp-only observation bug: `finish()` completed, but the parent SwiftUI controls observed only `StreamingDemoViewModel`, not its nested session, so the state label and buttons waited for an unrelated redraw. `StreamingDemoViewModel` now forwards session-state changes through `objectWillChange`. A fresh build showed `streaming` immediately after append and `finished` immediately after completion, with correct button availability. Per project policy, this UI-observation correction was verified manually and did not add a UI unit test.

## iPhone manual walkthrough

- Static Thought cards fit the narrow screen and fully contained their visible body background. Updating the same document produced the revised Thought content.
- The configuration page kept the Thought body, inline-code background, and outside suffix visually distinct without horizontal overflow.
- The component page contained the table at phone width; inline/block LaTeX and the Mermaid flowchart rendered after scrolling. The network image again remained a placeholder.
- The streaming page changed from `idle` to `streaming` immediately after one mock fragment and to `finished` immediately after completion; controls enabled and disabled with the state.

## Runtime-log observations

- iOS 26.5 emitted the already-recorded Simulator/WebKit duplicate `UIAccessibilityLoaderWebShared` warning. No ExampleApp crash accompanied it.
- One earlier iOS 26.5 same-document update emitted repeated `_NSLayoutTreeLineFragmentRectForGlyphAtIndex invalid glyph index 76` diagnostics. The current iPhone 16 Pro / iOS 18.5 same-document update did not reproduce that diagnostic, and both runs remained interactive. This is recorded as a platform-specific observation, not claimed as a confirmed library defect or as resolved.

## Not verified

- iOS/iPadOS 14 runtime behavior;
- physical-device behavior or a release performance baseline;
- full VoiceOver/manual accessibility traversal;
- external network-image success;
- real model/SSE credentials and remote endpoint behavior.

No UI automation suite or non-key-path UI unit test was added. The interactions above are manual ExampleApp acceptance evidence.
