import Foundation
import UIKit
import WebKit

/// 基于本地、固定版本 Mermaid 的离线图片渲染器。
///
/// 此对象不持有图片缓存；调用方应将 `InkMermaidRenderRequest.cacheIdentity()` 交给现有图片
/// Store。WebKit 和 UIKit 调用均限定在主 actor，等待 JavaScript / 快照期间不会阻塞主线程。
@MainActor
public final class InkMermaidImageRenderer: NSObject {
  public static let rendererVersion = "ink-mermaid-renderer/1"
  public static let mermaidVersion = "11.16.0"

  public let limits: InkMermaidRenderLimits

  private let bridgeURL: URL?
  /// 延迟到获得全局调度 permit 后创建；排队请求不会提前分配 WebKit 页面进程。
  private var webView: WKWebView?
  private let pageLoadRouter = InkMermaidPageLoadRouter()
  private var pageReady = false
  private var currentRequest: InkMermaidRenderRequestState?

  public init(limits: InkMermaidRenderLimits = .init()) {
    self.limits = limits
    self.bridgeURL = Bundle.module.url(forResource: "InkMermaidBridge", withExtension: "html")
    super.init()
  }

  /// 供测试注入自定义 bundle；生产路径使用 ``init(limits:)``。
  init(limits: InkMermaidRenderLimits, bundle: Bundle) {
    self.limits = limits
    self.bridgeURL = bundle.url(forResource: "InkMermaidBridge", withExtension: "html")
    super.init()
  }

  /// 使用离线 HTML bridge 把 Mermaid 代码渲染为 PNG。调用方可按错误类别显示占位图或诊断。
  public func render(_ request: InkMermaidRenderRequest) async throws -> InkMermaidRenderResult {
    try validate(request)
    return try await InkMermaidRenderScheduler.shared.withPermit { [self] in
      let state = InkMermaidRenderRequestState()
      currentRequest = state
      state.armTimeout(after: limits.timeout)
      defer {
        state.finish()
        pageLoadRouter.clear(for: state)
        if currentRequest === state { currentRequest = nil }
      }

      let view = ensureWebView()
      state.setInvalidationHandler { [weak self, weak state] in
        guard let state else { return }
        self?.discardWebView(for: state)
      }
      try await loadBridgeIfNeeded(using: view, state: state)
      // Mermaid 11 的 layout 会等待可度量视口；零 frame 时 render Promise 可能永不 settle。
      let provisionalWidth = max(request.display.maxPixelWidth / request.display.scale, 320)
      view.frame = CGRect(x: 0, y: 0, width: provisionalWidth, height: max(provisionalWidth, 480))
      _ = try await evaluate(
        "window.inkMermaid.resize(\(view.frame.width), \(view.frame.height))",
        using: view,
        state: state
      )
      let rasterPlan = try await evaluateDiagram(request, using: view, state: state)
      view.frame = CGRect(origin: .zero, size: rasterPlan.layoutSizeInPoints)
      let layoutWidth = rasterPlan.layoutSizeInPoints.width
      let layoutHeight = rasterPlan.layoutSizeInPoints.height
      _ = try await evaluate(
        "window.inkMermaid.resize(\(layoutWidth), \(layoutHeight))",
        using: view,
        state: state
      )
      // Mermaid journey 等图天然远宽于列表容器；仅 resize viewport 而不改 SVG
      // 会在 overflow:hidden 下裁切快照。把 SVG 压到 layoutSize，保留 viewBox 等比装入。
      _ = try await evaluate(
        "window.inkMermaid.fitSvgToSize(\(layoutWidth), \(layoutHeight))",
        using: view,
        state: state
      )
      let image = try await snapshot(plan: rasterPlan, using: view, state: state)
      guard let pngData = image.pngData() else { throw InkMermaidRenderError.pngEncodingFailed }
      return InkMermaidRenderResult(
        image: image,
        pngData: pngData,
        cacheIdentity: request.cacheIdentity()
      )
    }
  }

  private func ensureWebView() -> WKWebView {
    if let webView { return webView }
    let preferences = WKWebpagePreferences()
    preferences.allowsContentJavaScript = true
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences = preferences
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.navigationDelegate = self
    view.isOpaque = false
    view.backgroundColor = .clear
    view.scrollView.isScrollEnabled = false
    view.scrollView.bounces = false
    webView = view
    return view
  }

  private func validate(_ request: InkMermaidRenderRequest) throws {
    guard limits.maximumSourceCharacters > 0,
          limits.minimumPixelWidth.isFinite, limits.minimumPixelWidth > 0,
          limits.maximumPixelWidth.isFinite, limits.maximumPixelWidth >= limits.minimumPixelWidth,
          limits.maximumPixelHeight.isFinite, limits.maximumPixelHeight > 0,
          limits.timeout > 0 else {
      throw InkMermaidRenderError.invalidLimits
    }
    guard request.source.count <= limits.maximumSourceCharacters else {
      throw InkMermaidRenderError.inputTooLarge(limit: limits.maximumSourceCharacters)
    }
    guard request.display.maxPixelWidth.isFinite,
          request.display.scale.isFinite,
          request.display.maxPixelWidth >= limits.minimumPixelWidth,
          request.display.scale >= 1 else {
      throw InkMermaidRenderError.invalidDisplaySize
    }
  }

  private func loadBridgeIfNeeded(using view: WKWebView, state: InkMermaidRenderRequestState) async throws {
    guard !pageReady else { return }
    guard let bridgeURL else { throw InkMermaidRenderError.bundledResourceMissing }
    try await state.awaitCallback { [self] completion in
      pageLoadRouter.bind(view: view, state: state, completion: completion)
      view.loadFileURL(bridgeURL, allowingReadAccessTo: bridgeURL.deletingLastPathComponent())
    }
  }

  private func discardWebView(for state: InkMermaidRenderRequestState) {
    guard currentRequest === state else { return }
    pageLoadRouter.clear(for: state)
    pageReady = false
    webView?.stopLoading()
    webView?.navigationDelegate = nil
    webView = nil
  }

  private func evaluateDiagram(
    _ request: InkMermaidRenderRequest,
    using view: WKWebView,
    state: InkMermaidRenderRequestState
  ) async throws -> InkMermaidRasterPlan {
    let requestID = UUID().uuidString
    // JSONSerialization produces a JavaScript string literal. Mermaid input is never concatenated as code.
    let payload: [String: Any] = [
      "id": requestID,
      "source": request.source,
      "theme": request.display.theme == .dark ? "dark" : "default"
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [])
    guard let json = String(data: data, encoding: .utf8) else {
      throw InkMermaidRenderError.invalidJavaScriptResponse
    }
    let escapedJSON = try InkMermaidBridgeEncoding.javaScriptStringLiteral(json)
    _ = try await evaluate("window.inkMermaid.renderViaCallback(\(escapedJSON))", using: view, state: state)
    var response = try await pollRenderResult(requestID: requestID, using: view, state: state)
    // Bridge may wrap `{ ok, value|error }` so JS errors keep their message across WK evaluateJavaScript.
    if let encoded = response as? String,
       let data = encoded.data(using: .utf8),
       let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
       object["ok"] is Bool {
      if object["ok"] as? Bool == true {
        response = object["value"] as Any
      } else {
        let message = (object["error"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Mermaid render failed"
        throw InkMermaidRenderError.javaScript(message: message)
      }
    }
    guard let encoded = response as? String,
          let dimensionData = encoded.data(using: .utf8),
          let object = try JSONSerialization.jsonObject(with: dimensionData) as? [String: Any],
          let width = object["width"] as? Double,
          let height = object["height"] as? Double else {
      throw InkMermaidRenderError.invalidJavaScriptResponse
    }
    return try InkMermaidRasterPlan.make(
      svgWidthInPoints: CGFloat(width),
      svgHeightInPoints: CGFloat(height),
      display: request.display,
      limits: limits
    )
  }

  private func evaluate(
    _ javaScript: String,
    using view: WKWebView,
    state: InkMermaidRenderRequestState
  ) async throws -> Any {
    try await state.awaitCallback { completion in
      view.evaluateJavaScript(javaScript) { response, error in
        Task { @MainActor in
          if let error {
            completion(.failure(InkMermaidRenderError.javaScript(message: Self.javaScriptErrorMessage(from: error))))
          } else {
            completion(.success(response as Any))
          }
        }
      }
    }
  }

  private static func javaScriptErrorMessage(from error: Error) -> String {
    let userInfo = (error as NSError).userInfo
    let keys = [
      "WKJavaScriptExceptionMessage",
      "NSLocalizedDescription",
    ]
    for key in keys {
      if let message = userInfo[key] as? String, !message.isEmpty {
        return message
      }
    }
    return error.localizedDescription
  }

  private func pollRenderResult(
    requestID: String,
    using view: WKWebView,
    state: InkMermaidRenderRequestState
  ) async throws -> Any {
    let escapedID = try InkMermaidBridgeEncoding.javaScriptStringLiteral(requestID)
    while state.isOpen {
      try Task.checkCancellation()
      do {
        let polled = try await evaluate(
          "window.inkMermaid.pollRenderResult(\(escapedID))",
          using: view,
          state: state
        )
        if polled is NSNull {
          try await state.pollSleep(nanoseconds: 50_000_000)
          continue
        }
        _ = try? await evaluate("window.inkMermaid.clearPendingRender()", using: view, state: state)
        return polled
      } catch {
        discardWebView(for: state)
        throw error
      }
    }
    discardWebView(for: state)
    throw InkMermaidRenderError.timedOut
  }

  private func snapshot(
    plan: InkMermaidRasterPlan,
    using view: WKWebView,
    state: InkMermaidRenderRequestState
  ) async throws -> UIImage {
    let configuration = WKSnapshotConfiguration()
    // Both APIs take points; UIImage's scale produces `outputSizeInPixels` without a second resize.
    configuration.rect = CGRect(origin: .zero, size: plan.layoutSizeInPoints)
    configuration.snapshotWidth = NSNumber(value: Double(plan.layoutSizeInPoints.width))
    let image = try await state.awaitCallback { completion in
      view.takeSnapshot(with: configuration) { image, error in
        Task { @MainActor in
          if let image {
            completion(.success(image))
          } else {
            completion(.failure(InkMermaidRenderError.snapshotFailed))
          }
        }
      }
    }
    guard image.size.width > 0, image.size.height > 0 else { throw InkMermaidRenderError.zeroSize }
    let actualPixelWidth = CGFloat(image.cgImage?.width ?? Int((image.size.width * image.scale).rounded(.up)))
    let actualPixelHeight = CGFloat(image.cgImage?.height ?? Int((image.size.height * image.scale).rounded(.up)))
    let maxPixelWidth = ceil(plan.layoutSizeInPoints.width * image.scale)
    let maxPixelHeight = ceil(plan.layoutSizeInPoints.height * image.scale)
    guard actualPixelWidth <= maxPixelWidth,
          actualPixelHeight <= maxPixelHeight else {
      throw InkMermaidRenderError.exceedsMaximumSize
    }
    return image
  }
}

extension InkMermaidImageRenderer: WKNavigationDelegate {
  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard self.webView === webView,
          let state = currentRequest,
          pageLoadRouter.complete(from: webView, currentRequest: state, result: .success(())) else {
      return
    }
    pageReady = true
  }

  public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    guard self.webView === webView,
          let state = currentRequest else { return }
    _ = pageLoadRouter.complete(
      from: webView,
      currentRequest: state,
      result: .failure(InkMermaidRenderError.pageLoadFailed)
    )
  }

  public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    guard self.webView === webView,
          let state = currentRequest else { return }
    _ = pageLoadRouter.complete(
      from: webView,
      currentRequest: state,
      result: .failure(InkMermaidRenderError.pageLoadFailed)
    )
  }

  public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    guard self.webView === webView,
          let state = currentRequest else { return }
    state.invalidate(with: InkMermaidRenderError.pageProcessTerminated)
  }

  public func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    guard self.webView === webView,
          let state = currentRequest,
          pageLoadRouter.hasActiveRoute(for: webView, currentRequest: state) else {
      decisionHandler(.cancel)
      return
    }
    // The bridge is local. Block every attempted navigation (including Mermaid click directives).
    if navigationAction.navigationType == .other, navigationAction.request.url?.isFileURL == true {
      decisionHandler(.allow)
    } else {
      decisionHandler(.cancel)
    }
  }
}
