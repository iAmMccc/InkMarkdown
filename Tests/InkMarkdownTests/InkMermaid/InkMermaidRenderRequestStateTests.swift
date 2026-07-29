import Testing
@testable import InkMarkdown

@Suite(.serialized)
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
    #expect(!state.isOpen)
  }

  @Test func cancellationResumesExactlyOnce() async {
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
    pending.cancel()
    let outcome = await pending.value
    guard case .failure = outcome else {
      Issue.record("cancellation should resume the caller")
      return
    }

    lateCompletion?(.success(42))
    #expect(!state.isOpen)
  }

  @Test func pollSleepEndsPromptlyAfterInvalidation() async {
    let state = InkMermaidRenderRequestState()
    let pending = Task { @MainActor in
      do {
        try await state.pollSleep(nanoseconds: 5_000_000_000)
        return Result<Void, Error>.success(())
      } catch {
        return .failure(error)
      }
    }

    await Task.yield()
    state.invalidate(with: InkMermaidRenderError.timedOut)
    let outcome = await pending.value
    guard case .failure(let error) = outcome else {
      Issue.record("poll sleep should not wait for the full interval after invalidation")
      return
    }
    #expect(error as? InkMermaidRenderError == .timedOut)
  }
}
