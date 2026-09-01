# CI and Consumer Evidence

Date: 2026-09-01

Baseline: `7993112` plus the CI/test-target change set documented here.

## Failure reproduction

Environment: XcodeBuildMCP, `InkMarkdown-Package`, iPhone 16 Pro, iOS 18.5, Debug.

- Historical GitHub failure path: Mermaid WebKit PNG rendering returned `.timedOut`.
- Current pre-fix addon target run: 18 tests, 16 passed and 2 failed after 194.7 seconds. Failures were `rendersValidFlowchartToPNG()` and the parameterized diagram-type renderer; logs showed WebContent starting after the first timeout window.
- A second failure appeared when the generated-addon contract suite and real Mermaid renderer suite shared one test process: the contract temporarily replaced the global addon registry while another suite restored the production registration.
- The first CI draft selected the buildable `InkMarkdown` product scheme for package tests. XcodeBuildMCP reproduced that this scheme has no Test action, so all filtered test jobs would fail before running a test.

## Root cause and correction

- Swift Testing `.serialized` only serializes cases within one suite. Separate suites still entered the process concurrently.
- `InkMermaidRenderScheduler` serialized real renders, but did not isolate process-global test registry mutation.
- The 26-diagram matrix and wide-image pixel assertion duplicated the retained real PNG integration seam and ExampleApp manual coverage. They were removed under the repository's key-path-only test policy.
- Test targets now isolate Core, addon registration contracts, LaTeX, Mermaid/WebKit, and SwiftUI. No production lock, sleep, or retry loop was added to hide test interference.
- CI package jobs use the test-enabled `InkMarkdown-Package` aggregate scheme; `-only-testing` filters retain lane isolation.
- The single retained real Mermaid PNG integration allows a 60-second hosted-Simulator cold-start window; production defaults remain unchanged.

## Focused local results

| Lane | Result |
| --- | --- |
| Core + core contract + ExampleApp policy | 220 passed, 0 failed, 0 skipped; 35.8s |
| Addon registration contract + LaTeX | 7 passed, 0 failed, 0 skipped; 28.8s |
| Mermaid integration | 9 passed, 0 failed, 0 skipped; 49.9s |
| SwiftUI adapter | 62 passed, 0 failed, 1 skipped; 33.8s |
| ExampleApp Debug build | passed; 10.5s |
| ExampleApp Release build | passed; 45.2s |
| CI-equivalent Mermaid lane (`InkMarkdown-Package`) | 9 passed, 0 failed, 0 skipped; 47.0s |

The skipped SwiftUI test is the existing iOS 14-only ICS case; this machine has iOS 18.5 and 26.5 runtimes only.

## Complete package result

After the test-target isolation and CI changes were integrated at `7de8adb`, the complete `InkMarkdown-Package` scheme ran on iPhone 16 Pro / iOS 18.5:

- 299 total tests;
- 298 passed;
- 0 failed;
- 1 skipped;
- 128.8 seconds.

This is local XcodeBuildMCP evidence. It does not replace the required GitHub Actions result for the final pushed candidate SHA.

## Consumer and CI structure

- `InkMarkdownTests` depends only on `InkMarkdown`.
- Addon contract, LaTeX, and Mermaid tests use independent test targets and therefore independent process-global registration state.
- `InkMarkdownSwiftUITests` depends on the SwiftUI adapter product.
- ExampleApp consumes all four local products through an Xcode local Swift package reference and builds in Debug and Release.
- GitHub Actions now exposes independent Core, SwiftUI, addon-contract, Mermaid, ExampleApp Debug, and ExampleApp Release signals while sharing one pinned-toolchain setup action.

## Pending final evidence

- Re-run proportionate final validation if later source changes affect these lanes.
- Push the final candidate SHA and require all GitHub jobs to pass on that exact SHA.
