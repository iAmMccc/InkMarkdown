import Foundation
import UIKit
@testable import InkMarkdown

/// 事件驱动的可控图片加载器：按显式请求编号驱动 started / succeed / fail / cancel。
///
/// 不依赖真实网络或固定长 sleep；支持协作取消与忽略取消后的晚到结果。
final class InkControlledImageLoader: InkImageLoading, @unchecked Sendable {
  enum CancellationBehavior: Sendable {
    /// Task 取消时抛出 `CancellationError`，不再交付结果。
    case cooperative
    /// Task 取消后仍可 `succeed`/`fail` 晚到，供 generation 隔离测试。
    case ignoreCancel
  }

  struct Request: Sendable {
    let id: Int
    let source: ImageSource
    let display: DisplayContext
  }

  private struct Pending {
    let request: Request
    var continuation: CheckedContinuation<UIImage, Error>?
    var isCancelled = false
    var isFinished = false
    var bufferedResult: Result<UIImage, Error>?
  }

  private let lock = NSLock()
  private var nextID = 1
  private var pendings: [Int: Pending] = [:]
  private var _startedIDs: [Int] = []
  private var _cancelledIDs: [Int] = []
  private var _completedIDs: [Int] = []
  private var _failedIDs: [Int] = []

  var cancellationBehavior: CancellationBehavior
  var semanticIdentity: InkSemanticIdentity?

  init(
    cancellationBehavior: CancellationBehavior = .cooperative,
    semanticIdentity: InkSemanticIdentity? = InkSemanticIdentity("test.loader.controlled.v1")
  ) {
    self.cancellationBehavior = cancellationBehavior
    self.semanticIdentity = semanticIdentity
  }

  var startedIDs: [Int] {
    lock.lock(); defer { lock.unlock() }
    return _startedIDs
  }

  var cancelledIDs: [Int] {
    lock.lock(); defer { lock.unlock() }
    return _cancelledIDs
  }

  var completedIDs: [Int] {
    lock.lock(); defer { lock.unlock() }
    return _completedIDs
  }

  var failedIDs: [Int] {
    lock.lock(); defer { lock.unlock() }
    return _failedIDs
  }

  var pendingRequestIDs: [Int] {
    lock.lock(); defer { lock.unlock() }
    return pendings.keys.sorted()
  }

  var loadCount: Int { startedIDs.count }

  func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    let requestID: Int = {
      lock.lock(); defer { lock.unlock() }
      let id = nextID
      nextID += 1
      let request = Request(id: id, source: source, display: display)
      pendings[id] = Pending(request: request, continuation: nil)
      _startedIDs.append(id)
      return id
    }()

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
        lock.lock()
        guard var pending = pendings[requestID], !pending.isFinished else {
          lock.unlock()
          continuation.resume(throwing: CancellationError())
          return
        }
        if let buffered = pending.bufferedResult {
          pending.isFinished = true
          pending.bufferedResult = nil
          pendings.removeValue(forKey: requestID)
          switch buffered {
          case .success:
            _completedIDs.append(requestID)
          case .failure:
            _failedIDs.append(requestID)
          }
          lock.unlock()
          switch buffered {
          case .success(let image):
            continuation.resume(returning: image)
          case .failure(let error):
            continuation.resume(throwing: error)
          }
          return
        }
        if pending.isCancelled, cancellationBehavior == .cooperative {
          pending.isFinished = true
          pendings[requestID] = pending
          lock.unlock()
          continuation.resume(throwing: CancellationError())
          return
        }
        pending.continuation = continuation
        pendings[requestID] = pending
        lock.unlock()
      }
    } onCancel: { [weak self] in
      self?.observeCancel(requestID: requestID)
    }
  }

  /// 等待指定请求进入 `loadImage`（已分配编号）。超时错误带请求编号。
  func waitUntilStarted(
    requestID: Int,
    timeoutNanoseconds: UInt64 = 2_000_000_000
  ) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
      if startedIDs.contains(requestID) { return }
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    throw InkControlledImageLoaderTimeout(
      message: "waitUntilStarted timed out waiting for request #\(requestID); started=\(startedIDs)"
    )
  }

  /// 等待累计启动次数达到 `count`。
  func waitUntilLoadCount(
    _ count: Int,
    timeoutNanoseconds: UInt64 = 2_000_000_000
  ) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
      if loadCount >= count { return }
      try await Task.sleep(nanoseconds: 5_000_000)
    }
    throw InkControlledImageLoaderTimeout(
      message: "waitUntilLoadCount(\(count)) timed out; started=\(startedIDs)"
    )
  }

  func succeed(_ requestID: Int, image: UIImage = InkControlledImageLoader.defaultImage) {
    resume(requestID, with: .success(image))
  }

  func fail(_ requestID: Int, error: Error = ImageLoadError.decodeFailed) {
    resume(requestID, with: .failure(error))
  }

  /// 测试清理：所有未完成请求以失败结束，避免悬挂 continuation。
  func finishAllPending(error: Error = CancellationError()) {
    let ids: [Int] = {
      lock.lock(); defer { lock.unlock() }
      return pendings.keys.sorted()
    }()
    for id in ids {
      fail(id, error: error)
    }
  }

  deinit {
    finishAllPending()
  }

  static let defaultImage = UIImage(systemName: "photo")!

  private func observeCancel(requestID: Int) {
    lock.lock()
    guard var pending = pendings[requestID], !pending.isFinished else {
      lock.unlock()
      return
    }
    if !_cancelledIDs.contains(requestID) {
      _cancelledIDs.append(requestID)
    }
    pending.isCancelled = true
    switch cancellationBehavior {
    case .cooperative:
      pending.isFinished = true
      let continuation = pending.continuation
      pending.continuation = nil
      pendings[requestID] = pending
      lock.unlock()
      continuation?.resume(throwing: CancellationError())
    case .ignoreCancel:
      pendings[requestID] = pending
      lock.unlock()
    }
  }

  private func resume(_ requestID: Int, with result: Result<UIImage, Error>) {
    lock.lock()
    guard var pending = pendings[requestID], !pending.isFinished else {
      lock.unlock()
      return
    }
    if pending.continuation == nil {
      // succeed/fail 可能早于 continuation 安装；缓冲一次结果。
      pending.bufferedResult = result
      pendings[requestID] = pending
      lock.unlock()
      return
    }
    pending.isFinished = true
    let continuation = pending.continuation
    pending.continuation = nil
    pendings.removeValue(forKey: requestID)
    switch result {
    case .success:
      _completedIDs.append(requestID)
    case .failure:
      _failedIDs.append(requestID)
    }
    lock.unlock()
    switch result {
    case .success(let image):
      continuation?.resume(returning: image)
    case .failure(let error):
      continuation?.resume(throwing: error)
    }
  }
}

struct InkControlledImageLoaderTimeout: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}
