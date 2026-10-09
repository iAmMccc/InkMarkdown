import Foundation
import Kingfisher
import InkMarkdown

/// 在 Kingfisher 累计响应数据之前执行限制；每个 downloader 独享此代理。
final class InkBoundedDownloadDelegate: SessionDelegate, @unchecked Sendable {
  let policy: ImageSecurityPolicy
  private let lock = NSLock()
  private var bytes: [Int: Int] = [:]
  private var redirects: [Int: Int] = [:]
  private var firstRejection: ImageLoadError?

  // 每个代理只服务一次图片请求；完成回调后仍保留原因，供等待下载的后端读取。
  var rejectionError: ImageLoadError? {
    lock.lock()
    defer { lock.unlock() }
    return firstRejection
  }

  private func reject(_ error: ImageLoadError, task: URLSessionTask) {
    lock.lock()
    if firstRejection == nil { firstRejection = error }
    lock.unlock()
    task.cancel()
  }

  init(policy: ImageSecurityPolicy) { self.policy = policy; super.init() }

  override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                           didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      reject(.invalidResponse, task: dataTask)
      return .cancel
    }
    guard response.expectedContentLength <= policy.maxResponseBytes else {
      reject(.payloadTooLarge(Int(clamping: response.expectedContentLength)), task: dataTask)
      return .cancel
    }
    return await super.urlSession(session, dataTask: dataTask, didReceive: response)
  }

  override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    lock.lock()
    let count = (bytes[dataTask.taskIdentifier] ?? 0) + data.count
    bytes[dataTask.taskIdentifier] = count
    lock.unlock()
    guard count <= policy.maxResponseBytes else {
      reject(.payloadTooLarge(count), task: dataTask)
      return
    }
    super.urlSession(session, dataTask: dataTask, didReceive: data)
  }

  override func urlSession(_ session: URLSession, task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest) async -> URLRequest? {
    let count = nextRedirect(task.taskIdentifier)
    guard count <= policy.maxRedirects, let url = request.url,
          policy.rejectionReason(forRedirectURL: url) == nil else {
      reject(.sourceRejected, task: task)
      return nil
    }
    return request
  }

  private func nextRedirect(_ taskID: Int) -> Int {
    lock.lock()
    let count = (redirects[taskID] ?? 0) + 1
    redirects[taskID] = count
    lock.unlock()
    return count
  }

  override func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    lock.lock()
    bytes.removeValue(forKey: task.taskIdentifier)
    redirects.removeValue(forKey: task.taskIdentifier)
    lock.unlock()
    super.urlSession(session, task: task, didCompleteWithError: error)
  }
}
