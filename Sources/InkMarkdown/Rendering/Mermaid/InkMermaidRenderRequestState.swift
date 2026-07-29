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
  private var timeoutWorkItem: DispatchWorkItem?
  private var invalidationHandler: (() -> Void)?

  func armTimeout(after timeout: TimeInterval) {
    let item = DispatchWorkItem { [weak self] in
      self?.invalidate(with: InkMermaidRenderError.timedOut)
    }
    timeoutWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: item)
  }

  func setInvalidationHandler(_ handler: @escaping () -> Void) {
    invalidationHandler = handler
  }

  func awaitCallback<T>(
    _ start: @escaping (@escaping (Result<T, Error>) -> Void) -> Void
  ) async throws -> T {
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
      Task { @MainActor in self?.invalidate(with: CancellationError()) }
    })
  }

  func finish() {
    guard isActive else { return }
    isActive = false
    timeoutWorkItem?.cancel()
    timeoutWorkItem = nil
    pendingID = nil
    failPending = nil
    invalidationHandler = nil
  }

  func invalidate(with error: Error) {
    guard isActive else { return }
    isActive = false
    timeoutWorkItem?.cancel()
    timeoutWorkItem = nil
    invalidationHandler?()
    invalidationHandler = nil
    let fail = failPending
    failPending = nil
    pendingID = nil
    fail?(error)
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
}
