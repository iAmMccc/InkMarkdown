import Testing
@testable import InkMarkdown

@MainActor
struct InkMermaidRenderSchedulerTests {
  @Test func cancellationRemovesQueuedRenderWithoutLeakingPermit() async throws {
    let scheduler = InkMermaidRenderScheduler(maxConcurrentRenders: 1, maximumQueuedRenders: 1)
    try await scheduler.withPermit {
      #expect(scheduler.activeCount == 1)
      let queued = Task { @MainActor in
        try await scheduler.withPermit { () async throws -> Bool in true }
      }
      await Task.yield()
      #expect(scheduler.queuedCount == 1)
      queued.cancel()
      await #expect(throws: CancellationError.self) { try await queued.value }
      #expect(scheduler.queuedCount == 0)
    }
    #expect(scheduler.activeCount == 0)
  }

  @Test func queueIsBounded() async throws {
    let scheduler = InkMermaidRenderScheduler(maxConcurrentRenders: 1, maximumQueuedRenders: 0)
    try await scheduler.withPermit {
      await #expect(throws: InkMermaidRenderError.queueFull(limit: 0)) {
        try await scheduler.withPermit { () async throws -> Bool in true }
      }
    }
  }
}
