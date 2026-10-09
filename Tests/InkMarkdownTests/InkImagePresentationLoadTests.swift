import Testing
import UIKit
@testable import InkMarkdown

@Suite("InkImagePresentationLoad 订阅生命周期", .serialized)
@MainActor
struct InkImagePresentationLoadTests {

  private func boundLoader(
    _ loader: InkControlledImageLoader
  ) -> (store: InkImageStore, loader: any InkImageLoading) {
    var rendering = InkImageRendering()
    rendering.backend = TestImageBackend(loader)
    let store = InkImageStore()
    return (store, store.loader(for: rendering))
  }

  @Test
  func readyAfterWarmCache_skipsPendingAndLoader() async throws {
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }
    let (store, bound) = boundLoader(loader)

    let source = ImageSource(url: URL(string: "https://example.com/cached.png")!)
    let display = DisplayContext(maxPixelWidth: 120, scale: 2)

    let load = InkImagePresentationLoad()
    var pendingCount = 0
    var completions: [InkImagePresentationLoad.Completion] = []

    load.start(
      source: source,
      display: display,
      loader: bound,
      store: store,
      onPending: { pendingCount += 1 },
      onCompletion: { completions.append($0) }
    )
    #expect(pendingCount == 1)
    try await loader.waitUntilStarted(requestID: 1)
    loader.succeed(1, image: InkControlledImageLoader.defaultImage)
    let deadline = DispatchTime.now().uptimeNanoseconds + 2_000_000_000
    while completions.isEmpty, DispatchTime.now().uptimeNanoseconds < deadline {
      await Task.yield()
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(completions.count == 1)
    if case .image = completions.first {} else {
      Issue.record("首次应得到 image")
    }

    let load2 = InkImagePresentationLoad()
    var pending2 = 0
    var completions2: [InkImagePresentationLoad.Completion] = []
    let loadsBefore = loader.loadCount
    load2.start(
      source: source,
      display: display,
      loader: bound,
      store: store,
      onPending: { pending2 += 1 },
      onCompletion: { completions2.append($0) }
    )
    #expect(pending2 == 0)
    #expect(loader.loadCount == loadsBefore)
    #expect(completions2.count == 1)
    if case .image = completions2.first {} else {
      Issue.record("backend 缓存命中应同步 image")
    }
  }

  @Test
  func replaceAWithB_lateASuppressed_BCompletes() async throws {
    let loader = InkControlledImageLoader(cancellationBehavior: .ignoreCancel)
    defer { loader.finishAllPending() }
    let (store, bound) = boundLoader(loader)

    let display = DisplayContext(maxPixelWidth: 100, scale: 2)
    let load = InkImagePresentationLoad()
    var completions: [InkImagePresentationLoad.Completion] = []

    load.start(
      source: ImageSource(url: URL(string: "https://example.com/a.png")!),
      display: display,
      loader: bound,
      store: store,
      onPending: {},
      onCompletion: { completions.append($0) }
    )
    try await loader.waitUntilStarted(requestID: 1)

    load.start(
      source: ImageSource(url: URL(string: "https://example.com/b.png")!),
      display: display,
      loader: bound,
      store: store,
      onPending: {},
      onCompletion: { completions.append($0) }
    )
    try await loader.waitUntilStarted(requestID: 2)

    let imageB = UIImage(systemName: "b.circle")!
    loader.succeed(1, image: UIImage(systemName: "a.circle")!)
    loader.succeed(2, image: imageB)
    try? await Task.sleep(nanoseconds: 60_000_000)

    #expect(completions.count == 1)
    if case .image(let img) = completions.first {
      #expect(img === imageB || img.size == imageB.size)
    } else {
      Issue.record("只应收到 B 的 image")
    }
  }

  @Test
  func soloCancel_cancelsUnderlyingLoad() async throws {
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }
    let (store, bound) = boundLoader(loader)

    let display = DisplayContext(maxPixelWidth: 100, scale: 2)
    let solo = InkImagePresentationLoad()
    solo.start(
      source: ImageSource(url: URL(string: "https://example.com/solo.png")!),
      display: display,
      loader: bound,
      store: store,
      onPending: {},
      onCompletion: { _ in }
    )
    try await loader.waitUntilStarted(requestID: 1)
    solo.cancel()
    try? await Task.sleep(nanoseconds: 30_000_000)
    #expect(loader.cancelledIDs.contains(1))
  }

  @Test
  func pendingReentrancy_startAndCancel_doNotWriteBackStaleHandle() async throws {
    let loader = InkControlledImageLoader(cancellationBehavior: .ignoreCancel)
    defer { loader.finishAllPending() }
    let (store, bound) = boundLoader(loader)

    let display = DisplayContext(maxPixelWidth: 80, scale: 2)
    let load = InkImagePresentationLoad()
    var completions: [InkImagePresentationLoad.Completion] = []
    var nested = false

    load.start(
      source: ImageSource(url: URL(string: "https://example.com/outer.png")!),
      display: display,
      loader: bound,
      store: store,
      onPending: {
        guard !nested else { return }
        nested = true
        load.start(
          source: ImageSource(url: URL(string: "https://example.com/inner.png")!),
          display: display,
          loader: bound,
          store: store,
          onPending: {},
          onCompletion: { completions.append($0) }
        )
      },
      onCompletion: { completions.append($0) }
    )

    try await loader.waitUntilLoadCount(2)
    loader.succeed(1, image: UIImage(systemName: "1.circle")!)
    loader.succeed(2, image: UIImage(systemName: "2.circle")!)
    try? await Task.sleep(nanoseconds: 60_000_000)

    #expect(completions.count == 1)
    load.cancel()
    load.cancel()
    #expect(completions.count == 1)
  }

  @Test
  func completionReentrancy_startNewRequest_notCancelledByOldCleanup() async throws {
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }
    let (store, bound) = boundLoader(loader)

    let display = DisplayContext(maxPixelWidth: 80, scale: 2)
    let load = InkImagePresentationLoad()
    var phase = 0
    var finals: [InkImagePresentationLoad.Completion] = []

    load.start(
      source: ImageSource(url: URL(string: "https://example.com/first.png")!),
      display: display,
      loader: bound,
      store: store,
      onPending: {},
      onCompletion: { completion in
        finals.append(completion)
        if phase == 0 {
          phase = 1
          load.start(
            source: ImageSource(url: URL(string: "https://example.com/second.png")!),
            display: display,
            loader: bound,
            store: store,
            onPending: {},
            onCompletion: { finals.append($0) }
          )
        }
      }
    )
    try await loader.waitUntilStarted(requestID: 1)
    loader.succeed(1)
    try await loader.waitUntilStarted(requestID: 2)
    loader.succeed(2)
    try? await Task.sleep(nanoseconds: 60_000_000)

    #expect(finals.count == 2)
  }
}

@Suite("InkImagePresentationLoadAsync 一次终结", .serialized)
@MainActor
struct InkImagePresentationLoadAsyncTests {

  private func boundLoader(
    _ loader: InkControlledImageLoader
  ) -> (store: InkImageStore, loader: any InkImageLoading) {
    var rendering = InkImageRendering()
    rendering.backend = TestImageBackend(loader)
    let store = InkImageStore()
    return (store, store.loader(for: rendering))
  }

  @Test
  func syncReady_completesWithoutPendingLoader() async throws {
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }
    let (store, bound) = boundLoader(loader)

    let source = ImageSource(url: URL(string: "https://example.com/async-ready.png")!)
    let display = DisplayContext(maxPixelWidth: 100, scale: 2)

    let warmLoad = InkImagePresentationLoad()
    warmLoad.start(
      source: source,
      display: display,
      loader: bound,
      store: store,
      onCompletion: { _ in }
    )
    try await loader.waitUntilStarted(requestID: 1)
    loader.succeed(1)
    try? await Task.sleep(nanoseconds: 40_000_000)

    let loadsBefore = loader.loadCount
    let image = try await InkImagePresentationLoadAsync.loadImage(
      source: source,
      display: display,
      loader: bound,
      store: store
    )
    #expect(image.size.width > 0)
    #expect(loader.loadCount == loadsBefore)
  }

  @Test
  func preCancel_doesNotStartLoader() async throws {
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }
    let (store, bound) = boundLoader(loader)

    let source = ImageSource(url: URL(string: "https://example.com/async-precancel.png")!)
    let display = DisplayContext(maxPixelWidth: 90, scale: 2)

    let task = Task {
      try await InkImagePresentationLoadAsync.loadImage(
        source: source,
        display: display,
        loader: bound,
        store: store
      )
    }
    task.cancel()
    do {
      _ = try await task.value
      Issue.record("预取消应抛 CancellationError")
    } catch is CancellationError {
      // expected
    } catch {
      Issue.record("应得到 CancellationError，实际 \(error)")
    }
    try? await Task.sleep(nanoseconds: 30_000_000)
    #expect(loader.loadCount == 0)
  }

  @Test
  func cancelAfterStart_resumesOnce() async throws {
    let loader = InkControlledImageLoader(cancellationBehavior: .ignoreCancel)
    defer { loader.finishAllPending() }
    let (store, bound) = boundLoader(loader)

    let source = ImageSource(url: URL(string: "https://example.com/async-cancel.png")!)
    let display = DisplayContext(maxPixelWidth: 80, scale: 2)

    let task = Task {
      try await InkImagePresentationLoadAsync.loadImage(
        source: source,
        display: display,
        loader: bound,
        store: store
      )
    }
    try await loader.waitUntilStarted(requestID: 1)
    task.cancel()
    do {
      _ = try await task.value
      Issue.record("取消后应抛 CancellationError")
    } catch is CancellationError {
      // expected
    } catch {
      Issue.record("应得到 CancellationError，实际 \(error)")
    }

    loader.succeed(1)
    try? await Task.sleep(nanoseconds: 40_000_000)
  }

  @Test
  func failure_mapsDecodeFailedOnce() async throws {
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }
    let (store, bound) = boundLoader(loader)

    let source = ImageSource(url: URL(string: "https://example.com/async-fail.png")!)
    let display = DisplayContext(maxPixelWidth: 70, scale: 2)

    let task = Task {
      try await InkImagePresentationLoadAsync.loadImage(
        source: source,
        display: display,
        loader: bound,
        store: store
      )
    }
    try await loader.waitUntilStarted(requestID: 1)
    loader.fail(1)
    do {
      _ = try await task.value
      Issue.record("失败应抛错")
    } catch ImageLoadError.decodeFailed {
      // expected
    } catch {
      Issue.record("应得到 decodeFailed，实际 \(error)")
    }
  }
}
