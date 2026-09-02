import Foundation

/// 图片 HTTP 会话代理：合并重定向校验、有界字节累计与 Swift Task 取消桥接。
///
/// // 为什么 合并到单一 delegate：
/// `URLSession` 的 delegate 是会话级的；重定向拦截（`URLSessionTaskDelegate`）与
/// 响应体累计（`URLSessionDataDelegate`）必须挂在同一个对象上。按 `ObjectIdentifier(task)`
/// 分簿记，支持同会话并发请求。
///
/// 资源安全边界（ADR-006）：
/// - 重定向最多 `policy.maxRedirects` 次；配置 host 白名单时每次跳转重新校验；
/// - 响应体超过 `policy.maxResponseBytes` 时**在完整载入前**取消请求并抛出
///   `payloadTooLarge`（优先用 `Content-Length` 预判，否则按累计字节拦截）。
final class ImageHTTPSessionDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {

  let policy: ImageSecurityPolicy

  init(policy: ImageSecurityPolicy) {
    self.policy = policy
    self.redirectCounts = RedirectCounts()
    super.init()
  }

  // MARK: - 请求簿记

  private struct Pending {
    let continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>
    let urlTask: URLSessionTask
    var data: Data = Data()
    var response: HTTPURLResponse?
  }

  private let lock = NSLock()
  private var pendings: [ObjectIdentifier: Pending] = [:]

  /// 有界取数：成功返回完整数据与响应；失败 / 超限 / 取消分别抛出对应错误。
  ///
  /// 外层 Swift Task 被取消时，取消会传播到底层 `URLSessionTask`（ADR-006 订阅取消契约）。
  func boundedData(from url: URL, session: URLSession) async throws -> (Data, HTTPURLResponse) {
    let box = TaskBox()
    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>) in
        let task = session.dataTask(with: URLRequest(url: url))
        guard box.install(task) else {
          continuation.resume(throwing: ImageLoadError.cancelled)
          return
        }
        lock.lock()
        pendings[ObjectIdentifier(task)] = Pending(
          continuation: continuation,
          urlTask: task
        )
        lock.unlock()
        task.resume()
      }
    }, onCancel: {
      box.cancel()
    })
  }

  /// 一次性收尾：幂等移除 pending 并恢复 continuation。
  private func finish(taskID: ObjectIdentifier, result: Result<(Data, HTTPURLResponse), Error>) {
    lock.lock()
    guard let pending = pendings.removeValue(forKey: taskID) else {
      lock.unlock()
      return
    }
    lock.unlock()
    pending.continuation.resume(with: result)
  }

  // MARK: - URLSessionDataDelegate

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    let taskID = ObjectIdentifier(dataTask)
    let httpResponse = response as? HTTPURLResponse

    lock.lock()
    pendings[taskID]?.response = httpResponse
    lock.unlock()

    // Content-Length 可信时提前拒绝，避免为注定超限的响应下载任何字节。
    if let expected = httpResponse?.expectedContentLength,
       expected > 0, expected > policy.maxResponseBytes {
      finish(taskID: taskID, result: .failure(ImageLoadError.payloadTooLarge(Int(expected))))
      completionHandler(.cancel)
      return
    }

    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    let taskID = ObjectIdentifier(dataTask)
    lock.lock()
    pendings[taskID]?.data.append(data)
    let accumulated = pendings[taskID]?.data.count ?? 0
    lock.unlock()

    if accumulated > policy.maxResponseBytes {
      finish(taskID: taskID, result: .failure(ImageLoadError.payloadTooLarge(accumulated)))
      dataTask.cancel()
    }
  }

  // MARK: - URLSessionTaskDelegate（重定向 + 完成）

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    let taskID = ObjectIdentifier(task)
    lock.lock()
    let count = (redirectCounts.values[taskID] ?? 0) + 1
    if count > policy.maxRedirects {
      redirectCounts.values.removeValue(forKey: taskID)
      lock.unlock()
      completionHandler(nil)
      return
    }
    redirectCounts.values[taskID] = count
    lock.unlock()

    guard let redirectURL = request.url,
          policy.rejectionReason(forRedirectURL: redirectURL) == nil else {
      completionHandler(nil)
      return
    }
    completionHandler(request)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let taskID = ObjectIdentifier(task)
    lock.lock()
    redirectCounts.values.removeValue(forKey: taskID)
    let pending = pendings[taskID]
    lock.unlock()

    if let error {
      let inkError: Error
      let nsError = error as NSError
      if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
        inkError = ImageLoadError.cancelled
      } else if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
        inkError = ImageLoadError.timeout
      } else {
        inkError = error
      }
      finish(taskID: taskID, result: .failure(inkError))
      return
    }

    guard let pending, let response = pending.response else {
      finish(taskID: taskID, result: .failure(ImageLoadError.invalidResponse))
      return
    }
    finish(taskID: taskID, result: .success((pending.data, response)))
  }

  // MARK: - 计数器（在 delegate 锁内访问）

  private let redirectCounts: RedirectCounts

  private final class RedirectCounts {
    var values: [ObjectIdentifier: Int] = [:]
  }
}

/// 跨 `withTaskCancellationHandler` 的 URLSessionTask 句柄：处理「取消先于注册」竞态。
private final class TaskBox: @unchecked Sendable {
  private let lock = NSLock()
  private var task: URLSessionTask?
  private var isCancelled = false

  /// 原子安装底层任务；取消先发生时拒绝安装并立即取消新任务。
  func install(_ task: URLSessionTask) -> Bool {
    lock.lock()
    guard !isCancelled else {
      lock.unlock()
      task.cancel()
      return false
    }
    self.task = task
    lock.unlock()
    return true
  }

  func cancel() {
    lock.lock()
    isCancelled = true
    let task = task
    lock.unlock()
    task?.cancel()
  }
}
