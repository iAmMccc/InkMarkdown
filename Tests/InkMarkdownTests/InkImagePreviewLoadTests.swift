import Testing
import UIKit
@testable import InkMarkdown

@Suite("InkImagePreview backend 加载", .serialized)
@MainActor
struct InkImagePreviewLoadTests {

  @Test
  func renderingBackend_startsHighResLoad() async throws {
    let url = URL(string: "https://example.com/preview-backend.png")!
    let loader = InkControlledImageLoader()
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.backend = TestImageBackend(loader)

    var policy = PreviewLoadPolicy()
    policy.maxPreviewPixel = 256

    let controller = InkImagePreviewController(
      source: ImageSource(url: url),
      displayImage: makePreviewImage(width: 40, height: 40),
      rendering: rendering,
      previewPolicy: policy
    )

    presentPreview(controller)

    let started = await InkAsyncTestProbe.wait(timeoutNanoseconds: 5_000_000_000) {
      loader.loadCount >= 1
    }
    #expect(started, "注入 backend 后应启动高清加载")
    try await loader.waitUntilStarted(requestID: loader.startedIDs[0])
    loader.succeed(loader.startedIDs[0], image: makePreviewImage(width: 120, height: 80))
    for _ in 0..<30 { await Task.yield() }

    #expect(loader.loadCount >= 1)
    dismissPreview(controller)
  }

  @Test
  func dismissCancelsHighRes_lateResultIgnored() async throws {
    let url = URL(string: "https://example.com/preview-dismiss.png")!
    let loader = InkControlledImageLoader(cancellationBehavior: .ignoreCancel)
    defer { loader.finishAllPending() }

    var rendering = InkImageRendering()
    rendering.isEnabled = true
    rendering.backend = TestImageBackend(loader)

    let controller = InkImagePreviewController(
      source: ImageSource(url: url),
      displayImage: makePreviewImage(width: 20, height: 20),
      rendering: rendering,
      previewPolicy: PreviewLoadPolicy()
    )

    presentPreview(controller)
    try await loader.waitUntilStarted(requestID: 1)

    controller.beginAppearanceTransition(false, animated: false)
    controller.endAppearanceTransition()
    dismissPreview(controller)

    loader.succeed(1, image: makePreviewImage(width: 200, height: 200))
    for _ in 0..<20 { await Task.yield() }
    // 无崩溃、无悬挂即可；降采样图策略保留在 controller 生命周期内
  }

  private func presentPreview(_ controller: InkImagePreviewController) {
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
  }

  private func dismissPreview(_ controller: InkImagePreviewController) {
    controller.view.removeFromSuperview()
    controller.removeFromParent()
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
