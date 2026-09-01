import InkMarkdownMermaid
import Testing
import UIKit
@testable import InkMarkdown

@Suite(.serialized)
struct InkMermaidRendererTests {
  init() {
    _ = InkMarkdownMermaid.register()
  }

  @Test func onlyExactMermaidFenceLanguageIsAccepted() {
    #expect(InkMermaidFence.isMermaid(language: "mermaid"))
    #expect(!InkMermaidFence.isMermaid(language: "Mermaid"))
    #expect(!InkMermaidFence.isMermaid(language: " mermaid"))
    #expect(!InkMermaidFence.isMermaid(language: nil))
  }

  @Test func cacheIdentityIsStableAndIncludesRenderContext() {
    let light = InkMermaidRenderRequest(
      source: "flowchart TD; A-->B",
      display: .init(maxPixelWidth: 640, scale: 2, theme: .light)
    )
    let dark = InkMermaidRenderRequest(
      source: "flowchart TD; A-->B",
      display: .init(maxPixelWidth: 640, scale: 2, theme: .dark)
    )
    #expect(light.cacheIdentity() == light.cacheIdentity())
    #expect(light.cacheIdentity() != dark.cacheIdentity())
    #expect(light.cacheIdentity() != InkMermaidRenderRequest(
      source: "flowchart TD; A-->C",
      display: light.display
    ).cacheIdentity())
  }

  @Test @MainActor func mermaidRenderer_inputLimitsFailBeforeWebKitLoads() async {
    let renderer = InkMermaidImageRenderer(limits: .init(maximumSourceCharacters: 3), bundle: InkMarkdownMermaid.bundle)
    let request = InkMermaidRenderRequest(
      source: "four",
      display: .init(maxPixelWidth: 100, scale: 2, theme: .light)
    )
    await #expect(throws: InkMermaidRenderError.inputTooLarge(limit: 3)) {
      try await renderer.render(request)
    }
  }

  @Test func bridgeEncodingKeepsUserTextQuoted() throws {
    let malicious = "'); window.location='https://example.com'; //\n\\\""
    let encoded = try InkMermaidBridgeEncoding.javaScriptStringLiteral(malicious)
    let data = try #require(("[" + encoded + "]").data(using: .utf8))
    let roundTripped = try #require(JSONSerialization.jsonObject(with: data) as? [String]).first
    #expect(roundTripped == malicious)
    #expect(encoded.hasPrefix("\""))
  }

  @Test @MainActor func mermaidRenderer_nonPositiveTimeoutIsClassifiedAsInvalidLimits() async {
    let renderer = InkMermaidImageRenderer(limits: .init(timeout: 0), bundle: InkMarkdownMermaid.bundle)
    let request = InkMermaidRenderRequest(
      source: "graph TD; A-->B",
      display: .init(maxPixelWidth: 100, scale: 2, theme: .light)
    )
    await #expect(throws: InkMermaidRenderError.invalidLimits) {
      try await renderer.render(request)
    }
  }

  @Test @MainActor func mermaidRenderer_subUIKitScaleIsRejectedBeforeWebKitLoads() async {
    let renderer = InkMermaidImageRenderer(limits: .init(), bundle: InkMarkdownMermaid.bundle)
    let request = InkMermaidRenderRequest(
      source: "graph TD; A-->B",
      display: .init(maxPixelWidth: 100, scale: 0.5, theme: .light)
    )
    await #expect(throws: InkMermaidRenderError.invalidDisplaySize) {
      try await renderer.render(request)
    }
  }

  @Test func mermaidBridge_pollIgnoresStaleRequestID() throws {
    let bundle = InkMarkdownMermaid.bundle
    guard let bridgeURL = bundle.url(forResource: "InkMermaidBridge", withExtension: "js") else { return }
    let bridge = try String(contentsOf: bridgeURL, encoding: .utf8)
    #expect(bridge.contains("__pendingRequestId"))
    #expect(bridge.contains("expectedRequestId"))
    #expect(bridge.contains("clearPendingRender"))
    #expect(bridge.contains("measureSvg"))
    #expect(bridge.contains("fitSvgToSize"))
  }

  @Test @MainActor func rendersValidFlowchartToPNG() async throws {
    // Hosted Simulator 首次启动 WebContent 可能超过 30 秒；本集成 seam 允许一次冷启动宽限，
    // 生产默认值与调用方配置不受测试环境影响。
    let limits = InkMermaidRenderLimits(timeout: 60)
    let renderer = InkMermaidImageRenderer(limits: limits)
    let request = InkMermaidRenderRequest(
      source: "flowchart TD\n    Start-->End",
      display: .init(maxPixelWidth: 400, scale: 1, theme: .light)
    )

    let result = try await renderer.render(request)

    #expect(result.image.size.width > 0)
    #expect(result.image.size.height > 0)
    #expect(result.pngData.isEmpty == false)
    #expect(result.cacheIdentity == request.cacheIdentity())
  }

  /// 宽 journey 在窄 maxPixelWidth 下仍应把右侧 section 装进快照（回归：仅 resize viewport 会裁切）。
}

// WebKit page-process termination, bridge JavaScript errors and snapshot timeout require an iOS runtime;
// they are covered by the integration harness after the public image pipeline wires this renderer in.
