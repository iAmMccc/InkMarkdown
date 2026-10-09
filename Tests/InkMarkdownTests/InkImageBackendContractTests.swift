import Testing
import UIKit
@testable import InkMarkdown

@MainActor
private final class UncachedBackend: InkImageBackend {
  var calls = 0
  var ignoredCancellation = false
  func image(for request: InkImageRequest) async throws -> UIImage {
    calls += 1
    if ignoredCancellation {
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
    return UIImage(systemName: "photo")!
  }
}

@Suite @MainActor
struct InkImageBackendContractTests {
  let source = ImageSource(url: URL(string: "https://example.com/image.png")!)
  let display = DisplayContext(maxPixelWidth: 100, scale: 1)

  @Test func missingBackendReportsExplicitError() async {
    var rendering = InkImageRendering()
    var failures = 0
    rendering.onFailure = { _, error in
      if case ImageLoadError.backendNotConfigured = error { failures += 1 }
    }
    let loader = InkImageStore().loader(for: rendering)
    await #expect(throws: ImageLoadError.self) {
      _ = try await loader.loadImage(source: source, display: display)
    }
    #expect(failures == 1)
  }

  @Test func coreDoesNotAddCacheAroundCustomBackend() async throws {
    let backend = UncachedBackend()
    var rendering = InkImageRendering()
    rendering.backend = backend
    let loader = InkImageStore().loader(for: rendering)
    _ = try await loader.loadImage(source: source, display: display)
    _ = try await loader.loadImage(source: source, display: display)
    #expect(backend.calls == 2)
  }

  @Test func backendIdentityChangesConfigurationSemantics() {
    var first = InkImageRendering()
    first.backend = UncachedBackend()
    var second = first
    #expect(first == second)
    second.backend = UncachedBackend()
    #expect(first != second)
  }

  @Test func cancelledPresentationIgnoresNoncooperativeBackend() async throws {
    let backend = UncachedBackend()
    backend.ignoredCancellation = true
    var rendering = InkImageRendering()
    rendering.backend = backend
    let store = InkImageStore()
    let loader = store.loader(for: rendering)
    var completed = false
    guard case .loading(let subscribe) = store.resolve(source: source, display: display, loader: loader) else {
      Issue.record("Expected async result"); return
    }
    let subscription = subscribe { _ in completed = true }
    await Task.yield()
    subscription.cancel()
    try await Task.sleep(nanoseconds: 150_000_000)
    #expect(!completed)
  }

  @Test func sourcePolicyRunsBeforeCustomBackend() async {
    let backend = UncachedBackend()
    var rendering = InkImageRendering()
    rendering.backend = backend
    rendering.securityPolicy.allowedHosts = ["allowed.example"]
    let loader = InkImageStore().loader(for: rendering)
    await #expect(throws: ImageLoadError.self) {
      _ = try await loader.loadImage(source: source, display: display)
    }
    #expect(backend.calls == 0)
  }
}
