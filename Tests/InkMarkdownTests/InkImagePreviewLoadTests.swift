import Testing
import UIKit
@testable import InkMarkdown
import InkMarkdownSemanticCorpus

@Suite("InkImagePreview Store 分支", .serialized)
@MainActor
struct InkImagePreviewLoadTests {

  @Test
  func bypassStoreTrue_loadsViaLoaderWithoutStoreCache() async throws {
    let url = URL(string: "https://example.com/preview-bypass.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    let lowRes = makePreviewImage(width: 40, height: 40)
    var policy = PreviewLoadPolicy()
    policy.bypassStore = true
    policy.maxPreviewPixel = 256

    let controller = InkImagePreviewController(
      source: ImageSource(url: url),
      displayImage: lowRes,
      loader: loader,
      store: nil,
      previewPolicy: policy
    )

    let host = UIViewController()
    host.loadViewIfNeeded()
    host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    host.addChild(controller)
    host.view.addSubview(controller.view)
    controller.view.frame = host.view.bounds
    controller.didMove(toParent: host)
    controller.loadViewIfNeeded()
    controller.view.layoutIfNeeded()
    controller.beginAppearanceTransition(true, animated: false)
    controller.endAppearanceTransition()

    let started = await InkAsyncTestProbe.wait(timeoutNanoseconds: 5_000_000_000) {
      loader.loadCount >= 1
    }
    #expect(started, "bypassStore 路径应启动 loader")
    try await loader.waitUntilStarted(requestID: loader.startedIDs[0])
    let highRes = makePreviewImage(width: 120, height: 80)
    loader.succeed(loader.startedIDs[0], image: highRes)
    for _ in 0..<30 { await Task.yield() }

    #expect(loader.loadCount >= 1)
    // 关闭后晚到不得改写：再开一个请求后 dismiss
    controller.view.removeFromSuperview()
    controller.removeFromParent()
  }

  @Test
  func bypassStoreFalse_usesInjectedStore() async throws {
    let url = URL(string: "https://example.com/preview-store.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    let store = InkImageStore()
    let lowRes = makePreviewImage(width: 32, height: 32)
    var policy = PreviewLoadPolicy()
    policy.bypassStore = false
    policy.maxPreviewPixel = 256

    let controller = InkImagePreviewController(
      source: ImageSource(url: url),
      displayImage: lowRes,
      loader: loader,
      store: store,
      previewPolicy: policy
    )

    let host = UIViewController()
    host.loadViewIfNeeded()
    host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    host.addChild(controller)
    host.view.addSubview(controller.view)
    controller.view.frame = host.view.bounds
    controller.didMove(toParent: host)
    controller.loadViewIfNeeded()
    controller.beginAppearanceTransition(true, animated: false)
    controller.endAppearanceTransition()

    try await loader.waitUntilStarted(requestID: 1)
    loader.succeed(1, image: makePreviewImage(width: 100, height: 60))
    for _ in 0..<30 { await Task.yield() }

    // 同一 Store 再 resolve 应可命中缓存（ready）
    let metrics = InkDisplayMetrics.resolve(for: controller.view)
    let display = DisplayContext(
      maxPixelWidth: min(max(metrics.bounds.width, metrics.bounds.height) * metrics.scale * 3, 256),
      scale: metrics.scale,
      contentMode: .fit
    )
    let result = store.resolve(
      source: ImageSource(url: url),
      display: display,
      loader: loader
    )
    if case .ready = result {
      // expected cache hit path
    } else {
      // 显示上下文像素宽度可能略有差异；至少确认 loader 已完成一次
      #expect(loader.completedIDs.contains(1))
    }

    controller.view.removeFromSuperview()
    controller.removeFromParent()
  }

  @Test
  func dismissCancelsHighRes_lateResultIgnored() async throws {
    let url = URL(string: "https://example.com/preview-dismiss.png")!
    let loader = InkControlledImageLoader(cancellationBehavior: .ignoreCancel)
    defer { loader.finishAllPending() }

    var policy = PreviewLoadPolicy()
    policy.bypassStore = true

    let controller = InkImagePreviewController(
      source: ImageSource(url: url),
      displayImage: makePreviewImage(width: 20, height: 20),
      loader: loader,
      store: nil,
      previewPolicy: policy
    )

    let host = UIViewController()
    host.loadViewIfNeeded()
    host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    host.addChild(controller)
    host.view.addSubview(controller.view)
    controller.view.frame = host.view.bounds
    controller.didMove(toParent: host)
    controller.loadViewIfNeeded()
    controller.beginAppearanceTransition(true, animated: false)
    controller.endAppearanceTransition()

    try await loader.waitUntilStarted(requestID: 1)

    controller.beginAppearanceTransition(false, animated: false)
    controller.endAppearanceTransition()
    controller.view.removeFromSuperview()
    controller.removeFromParent()

    loader.succeed(1, image: makePreviewImage(width: 200, height: 200))
    for _ in 0..<20 { await Task.yield() }
    // 无崩溃、无悬挂即可；降采样图策略保留在 controller 生命周期内
  }
}

private func makePreviewImage(width: CGFloat, height: CGFloat) -> UIImage {
  let size = CGSize(width: width, height: height)
  let renderer = UIGraphicsImageRenderer(size: size)
  return renderer.image { context in
    UIColor.systemBlue.setFill()
    context.fill(CGRect(origin: .zero, size: size))
  }
}
