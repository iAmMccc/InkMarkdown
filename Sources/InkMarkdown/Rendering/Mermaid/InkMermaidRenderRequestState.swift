import Foundation

/// 单次 Mermaid 渲染的 completion gate。
///
/// WebKit 的 JavaScript / snapshot API 不保证会及时响应 Task 取消。该 gate 由主 actor
/// 独占，超时或取消时会先恢复当前等待者；此后同一 generation 的迟到 callback 会被忽略，
/// 因此调用方不需要等待 WebKit 协作取消即可释放渲染 permit。
@MainActor
final class InkMermaidRenderRequestState {
  let generation = UUID()

  private var isActive = true
  private var pendingID: UUID?
  private var failPending: ((Error) -> Void)?
  private var timeoutTask: Task<Void, Never>?
  private var invalidationHandler: (() -> Void)?

  var isOpen: Bool { isActive }

  func armTimeout(after timeout: TimeInterval) {
    timeoutTask?.cancel()
    timeoutTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(nanoseconds: Self.nanoseconds(for: timeout))
        guard !Task.isCancelled else { return }
        self?.invalidate(with: InkMermaidRenderError.timedOut)
      } catch {
        // Task.sleep 被取消时静默退出；finish/invalidate 会取消该 task。
      }
    }
  }

  func setInvalidationHandler(_ handler: @escaping () -> Void) {
    invalidationHandler = handler
  }

  func awaitCallback<T>(
    _ start: @escaping (@escaping (Result<T, Error>) -> Void) -> Void
  ) async throws -> T {
    try throwIfInactive()
    try Task.checkCancellation()
    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { continuation in
        guard isActive else {
          continuation.resume(throwing: InkMermaidRenderError.timedOut)
          return
        }
        let operationID = UUID()
        pendingID = operationID
        failPending = { [weak self] error in
          guard self?.pendingID == operationID else { return }
          self?.pendingID = nil
          self?.failPending = nil
          continuation.resume(throwing: error)
        }
        start { [weak self] result in
          Task { @MainActor in
            self?.complete(operationID: operationID, result: result, continuation: continuation)
          }
        }
      }
    }, onCancel: { [weak self] in
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          self?.invalidate(with: CancellationError())
        }
      }
    })
  }

  /// 轮询间隔 sleep；超时/取消后尽快结束，避免 poll 在 invalidate 后继续空转。
  func pollSleep(nanoseconds: UInt64) async throws {
    let chunk: UInt64 = 10_000_000
    var remaining = nanoseconds
    while remaining > 0, isActive {
      try Task.checkCancellation()
      let step = min(chunk, remaining)
      try await Task.sleep(nanoseconds: step)
      remaining -= step
    }
    try throwIfInactive()
  }

  func throwIfInactive() throws {
    guard isActive else { throw InkMermaidRenderError.timedOut }
  }

  func finish() {
    guard isActive else { return }
    isActive = false
    timeoutTask?.cancel()
    timeoutTask = nil
    pendingID = nil
    failPending = nil
    invalidationHandler = nil
  }

  func invalidate(with error: Error) {
    guard isActive else { return }
    isActive = false
    timeoutTask?.cancel()
    timeoutTask = nil
    invalidationHandler?()
    invalidationHandler = nil
    let fail = failPending
    failPending = nil
    fail?(error)
    pendingID = nil
  }

  private func complete<T>(
    operationID: UUID,
    result: Result<T, Error>,
    continuation: CheckedContinuation<T, Error>
  ) {
    guard isActive, pendingID == operationID else { return }
    pendingID = nil
    failPending = nil
    continuation.resume(with: result)
  }

  private static func nanoseconds(for timeout: TimeInterval) -> UInt64 {
    UInt64(max(0, timeout) * 1_000_000_000)
  }
}
