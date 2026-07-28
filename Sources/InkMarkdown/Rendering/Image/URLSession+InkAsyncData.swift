import Foundation

extension URLSession {

  /// iOS 14 兼容的异步 GET 请求（系统 ``URLSession/data(from:)`` 需 iOS 15+）。
  func inkData(from url: URL) async throws -> (Data, URLResponse) {
    try await withCheckedThrowingContinuation { continuation in
      let task = dataTask(with: url) { data, response, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        guard let data, let response else {
          continuation.resume(throwing: ImageLoadError.invalidResponse)
          return
        }
        continuation.resume(returning: (data, response))
      }
      task.resume()
    }
  }
}
