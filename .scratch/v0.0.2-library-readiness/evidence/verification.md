# Final Verification Evidence

Date: 2026-09-01

Pre-review local HEAD: `19b06c39f4b4fdf373aff6dbe144199e387b3b51`. The release-candidate SHA is the PR head commit containing this evidence; GitHub's immutable PR/check metadata is authoritative because a commit cannot embed its own hash.

## Local automated verification

| Check | Tool / destination | Result |
| --- | --- | --- |
| Complete package test | XcodeBuildMCP, `InkMarkdown-Package`, iPhone 16 Pro / iOS 18.5, Debug | 299 total: 298 passed, 0 failed, 1 skipped; 27.1s |
| ExampleApp Debug run | XcodeBuildMCP, iPad Pro 11-inch (M5) / iOS 26.5 | build, install, and launch passed; 12.0s |
| ExampleApp Debug run | XcodeBuildMCP, iPhone 16 Pro / iOS 18.5 | build, install, and launch passed; 8.6s |
| ExampleApp Release build | XcodeBuildMCP, iPhone 16 Pro / iOS 18.5 | passed; 31.0s |
| Isolated consumer builds | XcodeBuildMCP, iPhone 16 Pro / iOS 18.5 | Core 9.2s; SwiftUI 4.0s; LaTeX 3.1s; Mermaid 2.3s; all passed |
| Review-remediation Mermaid lane | XcodeBuildMCP, `InkMarkdown-Package`, iPhone 16 Pro / iOS 18.5, Debug | wide journey/right-edge regression retained; exact committed-tree record below |
| Package manifests | `swift package dump-package` | root exposes four products; consumer fixture contains four single-product targets |
| GitHub configuration | Ruby YAML parser | all workflow, action, issue-form, and Dependabot YAML parsed |
| Patch integrity | `git diff --check a9fc7cb..HEAD` | passed |

The skipped package test is the existing iOS 14-only ICS case; no iOS 14 runtime is installed on this machine.

### Exact wide-journey remediation rerun

- Timestamp: `2026-09-01T14:03:15+08:00` (`2026-09-01T06:03:15Z` artifact timestamp).
- Clean committed HEAD: `d43b27e91a5f6d68e417ece7b3a2eb19b97033d4`.
- Tested source tree: `65d41c7f2e434e39af12a7b81766e36085dd8a4d` (`HEAD:Sources`).
- Tested test tree: `3d0207d4bc6c8724b07f98ceb23d692caa673f08` (`HEAD:Tests`).
- Tool / scheme / destination: XcodeBuildMCP `test_sim`, `InkMarkdown-Package`, iPhone 16 Pro / iOS 18.5 Simulator, Debug.
- Command: `test_sim(extraArgs: ["-only-testing:InkMarkdownMermaidTests"], progress: true)`.
- Result: 9 passed, 0 failed, 0 skipped; 30.8s. This includes `rendersWideJourneyWithoutRightEdgeClipping()` with a 120-second per-attempt hosted-runner budget.
- Build log: `~/Library/Developer/XcodeBuildMCP/workspaces/InkMarkdown-124472009cd9/logs/test_sim_2026-09-01T06-03-15-409Z_pid53535_8b5d7c6a.log`.
- Result bundle: `~/Library/Developer/XcodeBuildMCP/workspaces/InkMarkdown-124472009cd9/result-bundles/test_sim_2026-09-01T06-03-15-409Z_pid53535_e2c652bd.xcresult`.

The evidence-only remediation commit after `d43b27e` does not change `Sources/` or `Tests/`; the scoped tree hashes above remain the tested code identity. The earlier 299-test package run used the same `Sources/` tree; the only later test-tree change is the focused Mermaid timeout calibration rerun here. Final GitHub CI must still validate the complete PR head SHA.

## Manual verification

See `compatibility-and-ui.md` for the iPad/iPhone ExampleApp walkthrough. It records passed static, configuration, component, and streaming key paths plus the unverified network-image, minimum-runtime, physical-device, and full accessibility boundaries.

## Independent review

Two fresh-context `gpt-5.6-sol` / `max` reviewers inspected `a9fc7cb..19b06c3` independently:

- Standards found three P2 items and one P3 item: aggregate package jobs were described too strongly, public test commands selected a scheme without a Test action, the conduct policy lacked a confidential intake route, and a removed Mermaid test left a stale comment.
- Spec found three P2 items: same-SHA remote delivery was still pending, four-product consumer isolation lacked compile evidence, and public test commands selected the wrong scheme.

Remediation added four isolated consumer builds, corrected all repository test commands to `InkMarkdown-Package`, made package-lane build limits explicit, and removed the stale comment. Same-SHA CI remains a delivery step below. Confidential conduct/security intake remains an explicit maintainer decision; repository text must not claim that route exists.

A second fresh-context Standards/Spec pair reviewed `a9fc7cb..049db14`. It found no production-source defect, but identified current-doc drift plus an overstatement caused by removing the wide-Mermaid regression. Final remediation:

- keeps one real WebKit PNG key path and changes it to a wide journey with right-edge pixel semantics, without restoring the 26-type matrix or adding UI tests;
- corrects the XcodeBuildMCP test scheme, test inventory/counts, four-product module map, and current-task source of truth;
- leaves push/PR/same-SHA CI and external platform/governance decisions as explicit gates.

A third fresh-context verification pair inspected `049db14..cde27bc`. Standards reported zero P1/P2. Spec found five evidence/inventory inconsistencies: the focused test lacked committed-tree identity, two files gave circular post-CI SHA instructions, three test targets were omitted from public trees, source counts still described an old dirty workspace, and `CONCERNS.md` denied completed ExampleApp evidence. The evidence-only remediation containing this paragraph fixes those items and leaves the tested `Sources/` / `Tests/` tree hashes above unchanged.

## Remote delivery

The PR head SHA and its required GitHub Actions jobs are the remote evidence. Do not edit this file merely to copy those values after CI succeeds: that would create a different, unverified SHA. Do not treat local verification as remote CI evidence.

## External decisions and blockers

- iOS/iPadOS 14 runtime execution is unavailable locally; the minimum deployment target was not raised.
- GitHub private vulnerability reporting was verified disabled, and no other private security channel is documented. `SECURITY.md` must not be created until a maintainer authorizes and confirms a working private route.
- No merge, tag, or GitHub Release is authorized by this readiness task.
