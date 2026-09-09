import Foundation
import Testing
@testable import ExampleApp

@MainActor
@Suite("SSE request lifecycle")
struct StreamRequestLifecycleTests {
  @Test("A queued validation failure cannot fail a replacement request")
  func serviceReplacementDiscardsOldError() async throws {
    let mock = MockSSEService(firstByteDelay: 0.01, chunkInterval: 0.01, answer: { $0 })
    let service = OpenAISSEService(mockService: mock)
    var events: [String] = []
    service.askStream(
      question: "invalid",
      config: LLMConfiguration(name: "Invalid", baseURL: "https://example.invalid"),
      onChunk: { events.append($0) },
      onComplete: { events.append("old-done") },
      onError: { _ in events.append("old-error") }
    )
    service.askStream(
      question: "replacement",
      config: LLMConfiguration(name: "Mock", baseURL: "", isMock: true),
      onChunk: { events.append($0) },
      onComplete: { events.append("done") },
      onError: { _ in events.append("new-error") }
    )
    try await waitUntil { events.contains("done") }
    #expect(events == ["replacement", "done"])
  }

  @Test("Cancelling before the first byte prevents startup and completion")
  func cancellationBeforeStartup() async throws {
    let service = MockSSEService(firstByteDelay: 0.02, chunkInterval: 0.01, answer: { $0 })
    var events: [String] = []
    service.askStream(question: "old", onChunk: { events.append($0) }, onComplete: { events.append("done") })
    service.cancel()
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(events.isEmpty)
  }

  @Test("Replacing a pending request emits only the replacement")
  func replacementBeforeStartup() async throws {
    let service = MockSSEService(firstByteDelay: 0.02, chunkInterval: 0.01, answer: { $0 })
    var events: [String] = []
    service.askStream(question: "old", onChunk: { events.append($0) }, onComplete: { events.append("old-done") })
    service.askStream(question: "new", onChunk: { events.append($0) }, onComplete: { events.append("new-done") })
    try await waitUntil { events.contains("new-done") }
    #expect(events == ["new", "new-done"])
  }

  @Test("Releasing a mock owner stops an already running timer")
  func releasingOwnerStopsDelivery() async throws {
    var service: MockSSEService? = MockSSEService(
      firstByteDelay: 0, chunkInterval: 0.01, answer: { _ in "first\nsecond\nthird" }
    )
    var events: [String] = []
    service?.askStream(question: "request", onChunk: { events.append($0) }, onComplete: { events.append("done") })
    try await waitUntil { !events.isEmpty }
    service = nil
    let deliveredBeforeRelease = events
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(events == deliveredBeforeRelease)
  }

  @Test("Queued events recheck cancellation when delivered")
  func queuedEventsAfterCancellation() async throws {
    var events: [String] = []
    let delivery = StreamRequestDelivery(
      onChunk: { events.append($0) },
      onComplete: { events.append("done") },
      onError: { _ in events.append("error") }
    )
    DispatchQueue.main.async {
      delivery.receive("late")
      delivery.fail(.cancelled)
      delivery.finish()
    }
    delivery.cancel()
    try await Task.sleep(nanoseconds: 30_000_000)
    #expect(events.isEmpty)
  }

  @Test("Termination releases transport before exactly one terminal event")
  func exactlyOnceTermination() {
    var events: [String] = []
    let delivery = StreamRequestDelivery(
      onChunk: { events.append($0) },
      onComplete: { events.append("done") },
      onError: { _ in events.append("error") }
    )
    delivery.onTermination = { events.append("released") }
    delivery.receive("first")
    delivery.finish()
    delivery.finish()
    delivery.fail(.cancelled)
    delivery.receive("late")
    delivery.cancel()
    #expect(events == ["first", "released", "done"])
  }

  @Test("A completion callback can start a new mock request")
  func reentrantReplacement() async throws {
    let service = MockSSEService(firstByteDelay: 0.01, chunkInterval: 0.01, answer: { $0 })
    var events: [String] = []
    service.askStream(question: "first", onChunk: { events.append($0) }, onComplete: {
      service.askStream(question: "second", onChunk: { events.append($0) }, onComplete: { events.append("done") })
    })
    try await waitUntil { events.contains("done") }
    #expect(events == ["first", "second", "done"])
  }

  private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(2)
    while !condition(), Date() < deadline {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(condition(), "The request did not complete within two seconds")
  }
}
