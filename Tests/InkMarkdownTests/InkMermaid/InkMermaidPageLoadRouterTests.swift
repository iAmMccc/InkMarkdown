import Testing
@testable import InkMarkdown

@MainActor
struct InkMermaidPageLoadRouterTests {
  private final class FakeWebView {}

  @Test func staleViewFinishCannotCompleteNewRequestRoute() {
    let router = InkMermaidPageLoadRouter()
    let oldView = FakeWebView()
    let newView = FakeWebView()
    let oldState = InkMermaidRenderRequestState()
    let newState = InkMermaidRenderRequestState()
    var oldCompleted = false
    var newCompleted = false

    router.bind(view: oldView, state: oldState) { _ in oldCompleted = true }
    router.clear(for: oldState) // Equivalent to timeout/cancel discarding the old WKWebView.
    router.bind(view: newView, state: newState) { _ in newCompleted = true }

    let staleWasRouted = router.complete(
      from: oldView,
      currentRequest: newState,
      result: .success(())
    )
    #expect(!staleWasRouted)
    #expect(!oldCompleted)
    #expect(!newCompleted)

    let currentWasRouted = router.complete(
      from: newView,
      currentRequest: newState,
      result: .success(())
    )
    #expect(currentWasRouted)
    #expect(newCompleted)
  }

  @Test func clearedOldRouteCannotAuthorizePolicyForNewRequest() {
    let router = InkMermaidPageLoadRouter()
    let reusedView = FakeWebView()
    let oldState = InkMermaidRenderRequestState()
    let newState = InkMermaidRenderRequestState()

    router.bind(view: reusedView, state: oldState) { _ in }
    router.clear(for: oldState)
    #expect(!router.hasActiveRoute(for: reusedView, currentRequest: newState))

    router.bind(view: reusedView, state: newState) { _ in }
    #expect(router.hasActiveRoute(for: reusedView, currentRequest: newState))
  }

  @Test func failureCompletionClearsRouteSoLaterPolicyIsCancelled() {
    let router = InkMermaidPageLoadRouter()
    let view = FakeWebView()
    let state = InkMermaidRenderRequestState()
    var receivedFailure = false

    router.bind(view: view, state: state) { result in
      if case .failure = result { receivedFailure = true }
    }
    #expect(router.complete(
      from: view,
      currentRequest: state,
      result: .failure(InkMermaidRenderError.pageLoadFailed)
    ))
    #expect(receivedFailure)
    #expect(!router.hasActiveRoute(for: view, currentRequest: state))
  }
}
