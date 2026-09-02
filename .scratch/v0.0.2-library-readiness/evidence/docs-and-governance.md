# Documentation and Governance Evidence

Inspection baseline: `feat/swiftUI` at commit `7993112` (`79931128536e2f15188c3134b4ce3964b0870cad`). CI and test-target work was integrated separately as `7de8adb` and `307d83d`; public-interface and ExampleApp fixes were integrated separately as `f388957` and `679000a`.

This evidence is committed with the documentation/governance change set. The immutable PR head SHA and GitHub check metadata are the remote evidence; do not create a post-CI evidence commit merely to copy them into repository files.

## Private vulnerability reporting channel check

The repository files were checked for a confirmed private vulnerability reporting route:

- No `SECURITY.md`, `.github/SECURITY.md`, or equivalent security-reporting file exists in the checked repository.
- No documented security-reporting email address, private form, or private-reporting URL was found in the checked Markdown and configuration files.
- `docs/codebase/CONCERNS.md` records product security considerations and the absence of security configuration, but it does not provide a private reporting channel.
- GitHub's repository API returned `{\"enabled\":false}` for private vulnerability reporting on 2026-09-01.

Conclusion: the repository does not currently provide a private vulnerability reporting channel. Both repository files and the GitHub repository setting were verified.

## Maintainer decision required

Before adding security-reporting instructions, the maintainer should choose and confirm one private channel, such as the hosting platform's private vulnerability reporting or security-advisory workflow. Only after confirmation should `SECURITY.md` be added or updated with the exact route and disclosure expectations.

Until then, public issues and issue forms must not receive credentials, private data, or suspected vulnerability details. This file records evidence and a recommendation; it does not claim that a private channel exists.

## Assets changed in this pass

- README documentation now separates released `0.0.1` core usage from unreleased `0.0.2` products and uses the current `InkInlineSyntax.render(text:context:)` contract.
- `CHANGELOG.md` now states the current Package result—298 logical tests, 297 passed, 1 skipped—and the separate app-hosted Mermaid 1/1 result, while keeping incomplete accessibility and minimum-runtime validation explicit.
- `CONTRIBUTING.md`, `SUPPORT.md`, `CODE_OF_CONDUCT.md`, issue forms, the pull request template, and Dependabot configuration now describe the project's contribution and validation boundaries.
- `docs/release-checklist.md` now defines the local, compatibility, manual, remote-CI, governance, and separately authorized publication gates for v0.0.2 without treating local evidence as release approval.

## Validation

- The current English/Chinese `InkInlineSyntax` sample was type-checked with the iOS Simulator SDK, deployment target iOS 14.0, and the locally built `InkMarkdown` module; it completed without diagnostics.
- All repository GitHub YAML files parsed successfully.
- `git diff --check` passed after integration edits.

## Open items

- No security channel was selected or confirmed; do not create `SECURITY.md` in this pass.
- iOS/iPadOS 14 runtime validation, complete accessibility and semantic manual coverage, and real-device performance baselines remain v0.0.2 blockers documented by the authoritative status files.
