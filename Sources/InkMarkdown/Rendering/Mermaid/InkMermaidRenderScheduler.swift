import Foundation

/// Mermaid WebKit 工作的唯一并发 owner。
///
/// Store 负责按图片键去重与准入队列上限；本调度器只限制不同图表同时创建的 WebView 数量。
/// 默认严格串行，等待队列不设独立上限，避免形成第二个失败型准入队列。
@MainActor
final class InkMermaidRenderScheduler {
  static let shared = InkMermaidRenderScheduler(maxConcurrentRenders: 1)

  private let maxConcurrentRenders: Int
  private var activeRenders = 0
  private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, Error>)] = []

  init(maxConcurrentRenders: Int) {
    self.maxConcurrentRenders = max(1, maxConcurrentRenders)
  }

  var activeCount: Int { activeRenders }
  var queuedCount: Int { waiters.count }

  func withPermit<T>(_ operation: @escaping @MainActor () async throws -> T) async throws -> T {
    try await acquire()
    defer { release() }
    try Task.checkCancellation()
    return try await operation()
  }

  private func acquire() async throws {
    try Task.checkCancellation()
    if activeRenders < maxConcurrentRenders {
      activeRenders += 1
      return
    }
    let id = UUID()
    try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        if Task.isCancelled {
          continuation.resume(throwing: CancellationError())
        } else {
          waiters.append((id, continuation))
        }
      }
    }, onCancel: { [weak self] in
      Task { @MainActor in self?.cancelWaiter(id: id) }
    })
  }

  private func release() {
    while !waiters.isEmpty {
      let waiter = waiters.removeFirst()
      // A cancellation handler removes cancelled waiters before release; this guard is defensive.
      waiter.continuation.resume()
      return
    }
    activeRenders -= 1
  }

  private func cancelWaiter(id: UUID) {
    guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
    let waiter = waiters.remove(at: index)
    waiter.continuation.resume(throwing: CancellationError())
  }
}
