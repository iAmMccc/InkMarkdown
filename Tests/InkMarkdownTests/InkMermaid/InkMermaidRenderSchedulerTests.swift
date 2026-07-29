import Testing
@testable import InkMarkdown

@MainActor
private final class PermitGate {
  private var continuation: CheckedContinuation<Void, Never>?

  func wait() async {
    await withCheckedContinuation { continuation = $0 }
  }

  func open() {
    continuation?.resume()
    continuation = nil
  }
}

@MainActor
struct InkMermaidRenderSchedulerTests {
  @Test func cancellationRemovesQueuedRenderWithoutLeakingPermit() async throws {
    let scheduler = InkMermaidRenderScheduler(maxConcurrentRenders: 1)
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

  @Test func moreThanEightQueuedWaitersDoNotFailEarly() async throws {
    let scheduler = InkMermaidRenderScheduler(maxConcurrentRenders: 1)
    let gate = PermitGate()
    let waiterCount = 10

    let holder = Task { @MainActor in
      try await scheduler.withPermit {
        await gate.wait()
      }
    }
    await Task.yield()
    #expect(scheduler.activeCount == 1)

    var waiters: [Task<Void, Error>] = []
    waiters.reserveCapacity(waiterCount)
    for _ in 0..<waiterCount {
      waiters.append(Task { @MainActor in
        try await scheduler.withPermit { () async throws -> Void in }
      })
    }
    await Task.yield()
    #expect(scheduler.queuedCount == waiterCount)

    for waiter in waiters {
      #expect(waiter.isCancelled == false)
    }

    gate.open()
    try await holder.value
    for waiter in waiters {
      try await waiter.value
    }
    #expect(scheduler.activeCount == 0)
    #expect(scheduler.queuedCount == 0)
  }

  @Test func activeCountNeverExceedsOneDuringSerialExecution() async throws {
    let scheduler = InkMermaidRenderScheduler(maxConcurrentRenders: 1)
    let gate = PermitGate()
    var observedPeak = 0

    let holder = Task { @MainActor in
      try await scheduler.withPermit {
        observedPeak = max(observedPeak, scheduler.activeCount)
        await gate.wait()
      }
    }
    await Task.yield()
    observedPeak = max(observedPeak, scheduler.activeCount)

    let runner = Task { @MainActor in
      try await scheduler.withPermit {
        observedPeak = max(observedPeak, scheduler.activeCount)
      }
    }
    await Task.yield()
    #expect(scheduler.queuedCount == 1)
    observedPeak = max(observedPeak, scheduler.activeCount)
    #expect(observedPeak <= 1)

    gate.open()
    try await holder.value
    try await runner.value
    #expect(scheduler.activeCount == 0)
    #expect(observedPeak <= 1)
  }

  @Test func cancelledWaiterDoesNotConsumePermitOnRelease() async throws {
    let scheduler = InkMermaidRenderScheduler(maxConcurrentRenders: 1)
    let gate = PermitGate()
    let acquired = PermitGate()

    let holder = Task { @MainActor in
      try await scheduler.withPermit {
        await gate.wait()
      }
    }
    await Task.yield()

    let cancelled = Task { @MainActor in
      try await scheduler.withPermit {
        await acquired.wait()
      }
    }
    await Task.yield()
    #expect(scheduler.queuedCount == 1)

    cancelled.cancel()
    await #expect(throws: CancellationError.self) { try await cancelled.value }
    #expect(scheduler.queuedCount == 0)

    let successor = Task { @MainActor in
      try await scheduler.withPermit {
        acquired.open()
      }
    }
    await Task.yield()
    #expect(scheduler.queuedCount == 1)

    gate.open()
    try await holder.value
    try await successor.value
    #expect(scheduler.activeCount == 0)
  }
}
