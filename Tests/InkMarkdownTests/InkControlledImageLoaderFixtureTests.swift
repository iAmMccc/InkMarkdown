import Testing
import UIKit
@testable import InkMarkdown

@Suite("InkControlledImageLoader fixture 对接", .serialized)
struct InkControlledImageLoaderFixtureTests {

  @MainActor
  private func waitUntilReady(
    store: InkImageStore,
    source: ImageSource,
    display: DisplayContext,
    loader: InkControlledImageLoader,
    timeoutNanoseconds: UInt64 = 2_000_000_000
  ) async -> Bool {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
      if case .ready = store.resolve(source: source, display: display, loader: loader) {
        return true
      }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return false
  }

  @Test @MainActor
  func sharedInflight_twoSubscribersOneLoad_lastCancelDoesNotDropOther() async throws {
    let store = InkImageStore()
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    let source = ImageSource(url: URL(string: "https://example.com/shared.png")!)
    let display = DisplayContext(maxPixelWidth: 300, scale: 2, contentMode: .fit)

    let first = store.resolve(source: source, display: display, loader: loader)
    let second = store.resolve(source: source, display: display, loader: loader)
    guard case .loading(let subscribeA) = first else {
      Issue.record("第一次应为 loading")
      return
    }
    guard case .loading(let subscribeB) = second else {
      Issue.record("第二次应为 loading（共享 inflight）")
      return
    }

    var completions: [UIImage?] = []
    let subA = subscribeA { image in completions.append(image) }
    let subB = subscribeB { image in completions.append(image) }

    try await loader.waitUntilLoadCount(1)
    #expect(loader.loadCount == 1)

    // 取消其中一个订阅不应取消共享加载。
    subA.cancel()
    #expect(loader.cancelledIDs.isEmpty)

    loader.succeed(1)
    #expect(await waitUntilReady(store: store, source: source, display: display, loader: loader))
    #expect(completions.contains(where: { $0 != nil }))
    subB.cancel()
  }

  @Test @MainActor
  func queuedCancel_neverStartsLoader() async throws {
    var configuration = InkImageStore.Configuration()
    configuration.maxConcurrentLoads = 1
    configuration.maxPendingLoads = 2
    let store = InkImageStore(configuration: configuration)
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    let display = DisplayContext(maxPixelWidth: 300, scale: 2)
    let active = store.resolve(
      source: ImageSource(url: URL(string: "https://example.com/active.png")!),
      display: display,
      loader: loader
    )
    guard case .loading = active else {
      Issue.record("首项应为 loading")
      return
    }
    try await loader.waitUntilStarted(requestID: 1)

    let queued = store.resolve(
      source: ImageSource(url: URL(string: "https://example.com/queued.png")!),
      display: display,
      loader: loader
    )
    guard case .queued(let subscribe) = queued else {
      Issue.record("第二项应为 queued")
      return
    }
    #expect(store.pendingLoadCount == 1)
    #expect(loader.loadCount == 1)

    let subscription = subscribe { _ in }
    subscription.cancel()
    #expect(store.pendingLoadCount == 0)
    #expect(loader.loadCount == 1)

    loader.succeed(1)
    try? await Task.sleep(nanoseconds: 50_000_000)
    #expect(loader.loadCount == 1)
  }

  @Test @MainActor
  func replaceAWithB_lateAIgnored_BCompletes() async throws {
    let store = InkImageStore()
    let loader = InkControlledImageLoader(cancellationBehavior: .ignoreCancel)
    defer { loader.finishAllPending() }

    let display = DisplayContext(maxPixelWidth: 300, scale: 2)
    let sourceA = ImageSource(url: URL(string: "https://example.com/a.png")!)
    let sourceB = ImageSource(url: URL(string: "https://example.com/b.png")!)

    let resultA = store.resolve(source: sourceA, display: display, loader: loader)
    guard case .loading(let subscribeA) = resultA else {
      Issue.record("A 应为 loading")
      return
    }
    var imageA: UIImage?
    let subA = subscribeA { imageA = $0 }
    try await loader.waitUntilStarted(requestID: 1)

    let resultB = store.resolve(source: sourceB, display: display, loader: loader)
    guard case .loading(let subscribeB) = resultB else {
      Issue.record("B 应为 loading")
      return
    }
    var imageB: UIImage?
    let subB = subscribeB { imageB = $0 }
    try await loader.waitUntilStarted(requestID: 2)

    // A 晚到：忽略取消模式下仍可交付，但不得覆盖 B 的订阅结果语义——
    // 这里验证 fixture 能按编号分别完成，且 B 最终 ready。
    let imageForA = UIImage(systemName: "a.circle")!
    let imageForB = UIImage(systemName: "b.circle")!
    loader.succeed(2, image: imageForB)
    #expect(await waitUntilReady(store: store, source: sourceB, display: display, loader: loader))
    #expect(imageB != nil)

    loader.succeed(1, image: imageForA)
    try? await Task.sleep(nanoseconds: 30_000_000)
    // A 的订阅仍可能收到自己的结果；关键是 B 缓存不被 A 替换。
    if case .ready(let readyB) = store.resolve(source: sourceB, display: display, loader: loader) {
      #expect(readyB === imageForB || readyB.size == imageForB.size)
    } else {
      Issue.record("B 应保持 ready")
    }
    _ = imageA
    subA.cancel()
    subB.cancel()
  }

  @Test @MainActor
  func failureCompletesOnce_withoutRetry() async throws {
    let store = InkImageStore()
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    let source = ImageSource(url: URL(string: "https://example.com/fail.png")!)
    let display = DisplayContext(maxPixelWidth: 200, scale: 2)
    let result = store.resolve(source: source, display: display, loader: loader)
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
}
