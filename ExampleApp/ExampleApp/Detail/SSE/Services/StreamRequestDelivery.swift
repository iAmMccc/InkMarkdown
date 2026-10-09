import Foundation

/// 一次传输请求的事件边界。终止先撤销资源，再通知消费者，允许回调安全地启动下一次请求。
@MainActor
final class StreamRequestDelivery {
  private(set) var isActive = true
  var onTermination: (() -> Void)?
  private let onChunk: @MainActor (String) -> Void
  private let onComplete: @MainActor () -> Void
  private let onError: @MainActor (LLMStreamError) -> Void

  init(
    onChunk: @escaping @MainActor (String) -> Void,
    onComplete: @escaping @MainActor () -> Void,
    onError: @escaping @MainActor (LLMStreamError) -> Void
  ) {
    self.onChunk = onChunk
    self.onComplete = onComplete
    self.onError = onError
  }

  func receive(_ chunk: String) {
    guard isActive else { return }
    onChunk(chunk)
  }

  func finish() {
    guard terminate() else { return }
    onComplete()
  }

  func fail(_ error: LLMStreamError) {
    guard terminate() else { return }
    onError(error)
  }

  func cancel() {
    _ = terminate()
  }

  private func terminate() -> Bool {
    guard isActive else { return false }
    isActive = false
    let cleanup = onTermination
    onTermination = nil
    cleanup?()
    return true
  }
}
