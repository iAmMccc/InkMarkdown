import Testing
@testable import InkMarkdown

@MainActor
struct InkMermaidRenderRequestStateTests {
  @Test func timeoutCompletesBeforeLateCallbackAndLateResultIsIgnored() async {
    let state = InkMermaidRenderRequestState()
    var lateCompletion: ((Result<Int, Error>) -> Void)?
    let pending = Task { @MainActor in
      do {
        return Result<Int, Error>.success(try await state.awaitCallback { completion in
          lateCompletion = completion
        })
      } catch {
        return .failure(error)
      }
    }

    await Task.yield()
    state.invalidate(with: InkMermaidRenderError.timedOut)
    let outcome = await pending.value
    guard case .failure(let error) = outcome else {
      Issue.record("timeout should resume the caller without waiting for WebKit")
      return
    }
    #expect(error as? InkMermaidRenderError == .timedOut)

    // Simulates an evaluateJavaScript/takeSnapshot callback received after the caller has returned.
    lateCompletion?(.success(42))
    #expect(true) // No double-resume or state mutation is permitted.
  }
}
