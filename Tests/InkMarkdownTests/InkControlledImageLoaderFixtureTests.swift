import Testing
import UIKit
@testable import InkMarkdown

@Suite("InkControlledImageLoader fixture 对接", .serialized)
struct InkControlledImageLoaderFixtureTests {

  @Test @MainActor
  func failureCompletesOnce_withoutRetry() async throws {
    var rendering = InkImageRendering()
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }
    rendering.backend = TestImageBackend(loader)

    let store = InkImageStore()
    let bound = store.loader(for: rendering)
    let source = ImageSource(url: URL(string: "https://example.com/fail.png")!)
    let display = DisplayContext(maxPixelWidth: 200, scale: 2)
    let result = store.resolve(source: source, display: display, loader: bound)
    guard case .loading(let subscribe) = result else {
      Issue.record("应为 loading")
      return
    }

    var received: [UIImage?] = []
    let subscription = subscribe { received.append($0) }
    try await loader.waitUntilStarted(requestID: 1)
    loader.fail(1)
    try? await Task.sleep(nanoseconds: 50_000_000)

    #expect(loader.loadCount == 1)
    #expect(loader.failedIDs == [1])
    #expect(received.contains(where: { $0 == nil }))
    subscription.cancel()
  }

  @Test @MainActor
  func backendCache_secondResolveIsReady() async throws {
    var rendering = InkImageRendering()
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }
    rendering.backend = TestImageBackend(loader)

    let store = InkImageStore()
    let bound = store.loader(for: rendering)
    let source = ImageSource(url: URL(string: "https://example.com/cached.png")!)
    let display = DisplayContext(maxPixelWidth: 300, scale: 2)

    guard case .loading(let subscribe) = store.resolve(source: source, display: display, loader: bound) else {
      Issue.record("首次应为 loading")
      return
    }
    var completed = false
    let subscription = subscribe { _ in completed = true }
    try await loader.waitUntilStarted(requestID: 1)
    loader.succeed(1)
    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while !completed, DispatchTime.now().uptimeNanoseconds < deadline {
      await Task.yield()
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(completed)

    if case .ready = store.resolve(source: source, display: display, loader: bound) {
      // backend 缓存命中
    } else {
      Issue.record("第二次应 ready（backend 缓存）")
    }
    #expect(loader.loadCount == 1)
    subscription.cancel()
  }
}
