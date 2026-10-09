import Testing
import UIKit
import InkMarkdown
@testable import InkMarkdownKingfisher

private final class ImageProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "image.test" }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let url = request.url!
    if url.path == "/waiting" { return }
    let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==")!
    let status = url.path == "/error" ? 500 : 200
    let headers = url.path == "/length" ? ["Content-Length": "999999"] : [:]
    client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: status,
      httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

@Suite @MainActor
struct KingfisherTransportTests {
  private func backend() -> InkKingfisherImageBackend {
    let session = URLSessionConfiguration.ephemeral
    session.protocolClasses = [ImageProtocol.self]
    return InkKingfisherImageBackend(sessionConfiguration: session)
  }

  private func request(_ path: String, limit: Int = 1024) -> InkImageRequest {
    var policy = ImageSecurityPolicy()
    policy.maxResponseBytes = limit
    return InkImageRequest(source: ImageSource(url: URL(string: "https://image.test/" + path)!),
      display: DisplayContext(maxPixelWidth: 64, scale: 1), securityPolicy: policy)
  }

  @Test func kingfisherDownloadsAndDecodes() async throws {
    let backend = backend()
    let r = request("image")
    let image = try await backend.image(for: r)
    #expect(image.size.width == 1)
    #expect(backend.cachedImage(for: r) != nil)
  }

  @Test(arguments: ["error", "length", "chunked"])
  func rejectsInvalidOrOversizedResponses(path: String) async {
    let backend = backend()
    let r = request(path, limit: path == "chunked" ? 8 : 1024)
    do {
      _ = try await backend.image(for: r)
      Issue.record("Invalid response accepted: \(path)")
    } catch {
      assertPolicyFailure(error, path: path, limit: r.securityPolicy.maxResponseBytes)
    }
    #expect(backend.cachedImage(for: r) == nil)
  }

  private func assertPolicyFailure(_ error: Error, path: String, limit: Int) {
    switch (path, error) {
    case ("error", ImageLoadError.invalidResponse): break
    case ("length", ImageLoadError.payloadTooLarge(let bytes)):
      #expect(bytes == 999999)
    case ("chunked", ImageLoadError.payloadTooLarge(let bytes)):
      #expect(bytes > limit)
    default: Issue.record("Expected a specific policy failure for \(path), received \(error)")
    }
  }

  @Test(arguments: ["error", "length", "chunked"])
  func failureCallbackPreservesPolicyReason(path: String) async {
    let backend = backend()
    let r = request(path, limit: path == "chunked" ? 8 : 1024)
    var rendering = InkImageRendering()
    rendering.backend = backend
    rendering.securityPolicy = r.securityPolicy
    var callbacks = 0
    rendering.onFailure = { _, error in
      callbacks += 1
      assertPolicyFailure(error, path: path, limit: r.securityPolicy.maxResponseBytes)
    }
    let loader = InkImageStore().loader(for: rendering)
    do {
      _ = try await loader.loadImage(source: r.source, display: r.display)
      Issue.record("Invalid response accepted")
    } catch {
      assertPolicyFailure(error, path: path, limit: r.securityPolicy.maxResponseBytes)
    }
    #expect(callbacks == 1)
    #expect(backend.cachedImage(for: r) == nil)
  }

  @Test func userCancellationDoesNotReportPolicyFailure() async throws {
    let backend = backend()
    let r = request("waiting")
    var rendering = InkImageRendering()
    rendering.backend = backend
    var callbacks = 0
    rendering.onFailure = { _, _ in callbacks += 1 }
    let loader = InkImageStore().loader(for: rendering)
    let task = Task { try await loader.loadImage(source: r.source, display: r.display) }
    try await Task.sleep(nanoseconds: 20_000_000)
    task.cancel()
    do {
      _ = try await task.value
      Issue.record("Cancelled request succeeded")
    } catch {
      #expect(error is CancellationError)
    }
    #expect(callbacks == 0)
    #expect(backend.cachedImage(for: r) == nil)
  }

  @Test func redirectLimitAndHostRevalidation() async {
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let url = URL(string: "https://image.test/start")!
    let task = session.dataTask(with: url)
    let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: nil)!
    var policy = ImageSecurityPolicy()
    policy.maxRedirects = 1
    policy.allowedHosts = ["image.test"]
    policy.redirectRevalidatesHost = false
    let delegate = InkBoundedDownloadDelegate(policy: policy)
    let allowed = URLRequest(url: URL(string: "https://image.test/next")!)
    #expect(await delegate.urlSession(session, task: task,
      willPerformHTTPRedirection: response, newRequest: allowed) != nil)
    #expect(await delegate.urlSession(session, task: task,
      willPerformHTTPRedirection: response, newRequest: allowed) == nil)
    let restricted = InkBoundedDownloadDelegate(policy: policy)
    #expect(await restricted.urlSession(session, task: session.dataTask(with: url),
      willPerformHTTPRedirection: response,
      newRequest: URLRequest(url: URL(string: "https://other.test/image")!)) == nil)
  }
}
