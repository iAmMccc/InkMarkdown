# Final Verification Evidence

Date: 2026-09-01

Hosted-boundary remediation baseline: `23d867713b9ab967cf0346bff8d44895c3fcf3f5`. 本轮只允许本地 commit；push、PR 更新与远端 CI 按维护者要求延期。

## Local automated verification

| Check | Tool / destination | Result |
| --- | --- | --- |
| Complete package test | native `xcodebuild` fallback, `InkMarkdown-Package`, iPhone 17 Pro / iOS 26.5, Debug | 298 logical tests: 297 passed, 0 failed, 1 skipped; test operation 22.4s |
| Deterministic Mermaid package target | native `xcodebuild` fallback, `InkMarkdownMermaidTests`, same destination | 8 passed, 0 failed, 0 skipped |
| App-hosted Mermaid PNG integration | native `xcodebuild` fallback, `ExampleAppMermaidIntegrationTests`, same destination | 1 passed, 0 failed, 0 skipped; test operation 11.0s |
| ExampleApp Debug build | native `xcodebuild` fallback, iPhone 17 Pro / iOS 26.5 | passed |
| ExampleApp Release build | native `xcodebuild` fallback, iPhone 17 Pro / iOS 26.5 | passed |
| ExampleApp Debug run | XcodeBuildMCP, iPad Pro 11-inch (M5) / iOS 26.5 | build, install, and launch passed; 12.0s |
| ExampleApp Debug run | XcodeBuildMCP, iPhone 16 Pro / iOS 18.5 | build, install, and launch passed; 8.6s |
| Isolated consumer builds | XcodeBuildMCP, iPhone 16 Pro / iOS 18.5 | Core 9.2s; SwiftUI 4.0s; LaTeX 3.1s; Mermaid 2.3s; all passed |
| Package manifests | `swift package dump-package` | root exposes four products; consumer fixture contains four single-product targets |
| GitHub configuration | Ruby YAML parser | all workflow, action, issue-form, and Dependabot YAML parsed |
| Patch integrity | `git diff --check` | passed |

The skipped package test is the existing iOS 14-only ICS case; no iOS 14 runtime is installed on this machine.

### Current app-hosted wide-journey result

- Scheme / target / destination: `ExampleApp` / `ExampleAppMermaidIntegrationTests`, iPhone 17 Pro / iOS 26.5 Simulator, Debug.
- Result: `rendersWideJourneyWithoutRightEdgeClipping()` passed 1/1 using the production default timeout and production single retry.
- Assertions: 400px output width, bounded height, PNG payload, cache identity, and right-side non-background pixel density protecting `Act` / `Export report`.
- Result bundle: `~/Library/Developer/Xcode/DerivedData/ExampleApp-dtkjypnkylsasgccwnrxfzappddk/Logs/Test/Test-ExampleApp-2026.09.01_14-58-20-+0800.xcresult`.
- The Package-side Mermaid target separately passed 8/8 deterministic tests. Its result bundle is `~/Library/Developer/Xcode/DerivedData/InkMarkdown-fegkjzhxkpkatfgscsnwljoxebbz/Logs/Test/Test-InkMarkdown-Package-2026.09.01_14-59-36-+0800.xcresult`.
- The full Package result bundle is `~/Library/Developer/Xcode/DerivedData/InkMarkdown-fegkjzhxkpkatfgscsnwljoxebbz/Logs/Test/Test-InkMarkdown-Package-2026.09.01_15-01-42-+0800.xcresult`.

The preceding hostless 9-test run at `d43b27e` remains useful historical reproduction evidence, but it is superseded as a CI seam. GitHub run `33476630553` spent about 241 seconds across two 120-second attempts because its SwiftPM runner had no `UIApplication` and the WebContent process became unresponsive. The JavaScript watchdog could not run while WebKit's event loop was stalled. No production timeout, sleep, or retry was increased; the one real PNG regression moved to the lifecycle boundary it requires.

## Manual verification

See `compatibility-and-ui.md` for the iPad/iPhone ExampleApp walkthrough. It records passed static, configuration, component, streaming, and SwiftUI wide-Mermaid right-edge paths plus the unverified network-image, minimum-runtime, physical-device, full accessibility, and separate UIKit-bottom visual boundaries.

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

A fourth fresh-context `gpt-5.6-sol` / `max` pair inspected `23d8677...61954f8`. Standards found no P1/P2, one P3 runtime-status drift, and two judgement-call duplication/scattered-count smells. Spec found one P2 stale 299-test reference. This follow-up aligns the stale count and runtime row and centralizes the UIKit/SwiftUI wide-journey acceptance Markdown; exact counts remain repeated only where current-state or release evidence requires them. Both reviewers returned `PASS` in the narrow post-remediation check.

A fifth fresh-context `gpt-5.6-sol` / `max` pair reviewed the added release checklist. It found no P1 and identified four unique P2 issues plus one P3: authority precedence was too broad, the `0.0.1` source-compatibility gate allowed documented breakage, the Phase S2/S3 semantic matrix and lifecycle gates were incomplete, PR jobs tested GitHub's default merge ref rather than the exact candidate head SHA, and the reusable checklist hard-coded one branch name. Remediation makes authority layers explicit, requires source compatibility, adds key semantic/lifecycle gates without expanding visual tests, pins and verifies the candidate checkout in every CI job, and makes the PR head branch maintainer-selected. Standards then returned `PASS`; Spec found one residual P2 because the opt-in gate omitted Core image rendering, so the final checklist now names its loading, Store, cancellation, cache, and security-policy contracts alongside LaTeX/Mermaid addons. The final Spec follow-up returned `PASS`. Remote execution remains deferred and is not claimed by this local evidence.

## Remote delivery

Remote delivery is intentionally deferred. No push or PR mutation is authorized in this run, and local verification is not remote CI evidence. When the maintainer later authorizes delivery, the PR head SHA and its required GitHub Actions jobs must be checked on that exact SHA.

## External decisions and blockers

- iOS/iPadOS 14 runtime execution is unavailable locally; the minimum deployment target was not raised.
- GitHub private vulnerability reporting was verified disabled, and no other private security channel is documented. `SECURITY.md` must not be created until a maintainer authorizes and confirms a working private route.
- No merge, tag, or GitHub Release is authorized by this readiness task.
