import Foundation

/// HTTP 重定向拦截器：限制次数并在每次跳转后重新校验目标主机。
final class RedirectValidator: NSObject, URLSessionTaskDelegate {

  let policy: ImageSecurityPolicy
  private let lock = NSLock()
  private var redirectCounts: [ObjectIdentifier: Int] = [:]

  init(policy: ImageSecurityPolicy) {
    self.policy = policy
    super.init()
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    let taskID = ObjectIdentifier(task)
    lock.lock()
    let count = (redirectCounts[taskID] ?? 0) + 1
    if count > policy.maxRedirects {
      redirectCounts.removeValue(forKey: taskID)
      lock.unlock()
      completionHandler(nil)
      return
    }
    redirectCounts[taskID] = count
    lock.unlock()
    guard policy.redirectRevalidatesHost,
          let host = request.url?.host else {
      completionHandler(request)
      return
    }
    if policy.allowedHosts.isEmpty && policy.emptyHostPolicy == .rejectAll {
      completionHandler(nil)
      return
    }
    if !policy.allowedHosts.isEmpty && !policy.allowedHosts.contains(host) {
      completionHandler(nil)
      return
    }
    completionHandler(request)
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    lock.lock()
    redirectCounts.removeValue(forKey: ObjectIdentifier(task))
    lock.unlock()
  }
}
