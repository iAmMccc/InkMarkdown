# CI and Consumer Evidence

Date: 2026-09-01

Current hosted-boundary remediation baseline: `23d867713b9ab967cf0346bff8d44895c3fcf3f5`. Earlier CI/consumer isolation work remains part of the branch history.

## Failure reproduction

Environment: XcodeBuildMCP, `InkMarkdown-Package`, iPhone 16 Pro, iOS 18.5, Debug.

- Historical GitHub failure path: Mermaid WebKit PNG rendering returned `.timedOut`.
- GitHub run `33476630553` reproduced the remaining flaw after timeout calibration: the hostless SwiftPM test runner logged that it had no `UIApplication`, WebContent became unresponsive, and two 120-second attempts ended after about 241 seconds.
- Current pre-fix addon target run: 18 tests, 16 passed and 2 failed after 194.7 seconds. Failures were `rendersValidFlowchartToPNG()` and the parameterized diagram-type renderer; logs showed WebContent starting after the first timeout window.
- A second failure appeared when the generated-addon contract suite and real Mermaid renderer suite shared one test process: the contract temporarily replaced the global addon registry while another suite restored the production registration.
- The first CI draft selected the buildable `InkMarkdown` product scheme for package tests. XcodeBuildMCP reproduced that this scheme has no Test action, so all filtered test jobs would fail before running a test.

## Root cause and correction

- Swift Testing `.serialized` only serializes cases within one suite. Separate suites still entered the process concurrently.
- `InkMermaidRenderScheduler` serialized real renders, but did not isolate process-global test registry mutation.
- The 26-diagram matrix exceeded the repository's key-path-only policy and was removed. The single retained real PNG integration renders a wide journey and keeps the right-edge pixel assertion that protects the historical clipping regression.
- Test targets isolate Core, addon registration contracts, LaTeX, deterministic Mermaid contracts, SwiftUI, and the app-hosted Mermaid key path at execution/process and lifecycle boundaries. No production lock, sleep, timeout increase, or retry loop was added to hide test interference.
- CI package jobs use the test-enabled `InkMarkdown-Package` aggregate scheme; `-only-testing` separates test execution but does not isolate the aggregate build graph.
- A dedicated external-consumer fixture builds Core, SwiftUI, LaTeX, and Mermaid product schemes separately, proving product-level compile/link isolation.
- A raw SwiftPM test process is not a valid lifecycle host for real WKWebView rendering. The single real Mermaid PNG test therefore lives in `ExampleAppMermaidIntegrationTests`, where XCTest launches and retains ExampleApp. It asserts right-side ink after 400px fitting and uses production's default timeout plus one bounded retry.
- The hosted CI job consumes the setup action's verified Simulator UDID, explicitly boots it, waits for `bootstatus`, then runs only the app-hosted integration target.

## Focused local results

| Lane | Result |
| --- | --- |
| Core + core contract + ExampleApp policy | 220 passed, 0 failed, 0 skipped; 35.8s |
| Addon registration contract + LaTeX | 7 passed, 0 failed, 0 skipped; 28.8s |
| Historical hostless Mermaid target | 9 passed locally but failed on GitHub; superseded as the real-PNG CI seam |
| SwiftUI adapter | 62 passed, 0 failed, 1 skipped; 33.8s |
| ExampleApp Debug build | passed; 10.5s |
| ExampleApp Release build | passed; 45.2s |
| Deterministic Mermaid package target | 8 passed, 0 failed, 0 skipped; iPhone 17 Pro / iOS 26.5 |
| App-hosted Mermaid integration | 1 passed, 0 failed, 0 skipped; iPhone 17 Pro / iOS 26.5 |
| Isolated consumer builds | Core 9.2s; SwiftUI 4.0s; LaTeX 3.1s; Mermaid 2.3s; all passed |
| Latest complete Package | 298 logical tests: 297 passed, 0 failed, 1 skipped; test operation 22.4s |

The skipped SwiftUI test is the existing iOS 14-only ICS case; this machine has iOS 18.5 and 26.5 runtimes only.

## Complete package result

After moving the one real-PNG case to the app host, the complete `InkMarkdown-Package` scheme ran on iPhone 17 Pro / iOS 26.5:

- 298 logical tests;
- 297 passed;
- 0 failed;
- 1 skipped;
- 22.4 seconds for the test operation.

The separate app-hosted target passed 1/1, so the key-path inventory remains one-for-one rather than deleting the clipping regression. These are local native-`xcodebuild` fallback results after the XcodeBuildMCP transport closed; they do not replace later same-SHA GitHub Actions evidence.

## Consumer and CI structure

- `InkMarkdownTests` depends only on `InkMarkdown`.
- Addon contract, LaTeX, and deterministic Mermaid tests use independent package test targets and therefore independent process-global registration state.
- `InkMarkdownSwiftUITests` depends on the SwiftUI adapter product.
- ExampleApp consumes all four local products together through an Xcode local Swift package reference and builds in Debug and Release.
- `.github/fixtures/consumer-smoke` provides four independent external targets; each imports exactly one product and builds through its own product scheme.
- GitHub Actions exposes separate Core, SwiftUI, addon-contract, deterministic Mermaid, app-hosted Mermaid PNG, four product-isolated consumer builds, and ExampleApp Debug/Release signals while sharing one pinned-toolchain setup action.

## Pending final evidence

- PR run [33474934456](https://github.com/iAmMccc/InkMarkdown/actions/runs/33474934456) at `4c6ff6f` passed 9 of 10 jobs; the hostless Mermaid lane timed out twice at 60 seconds.
- Follow-up run `33476630553` at the current remote baseline again passed 9 of 10 jobs; the same hostless lane timed out twice at 120 seconds and proved that more timeout did not fix the missing App lifecycle.
- Re-run proportionate final validation if later source changes affect these lanes.
- Push、PR 更新与远端 CI are explicitly deferred by the maintainer. When later authorized, push the final candidate SHA and require every necessary job—including `ExampleApp / Mermaid integration`—to pass on that exact SHA.
