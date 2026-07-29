import Testing
import UIKit
@testable import InkMarkdown

struct InkMermaidRendererTests {
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

  @Test @MainActor func inputLimitsFailBeforeWebKitLoads() async {
    let renderer = InkMermaidImageRenderer(limits: .init(maximumSourceCharacters: 3))
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

  @Test @MainActor func nonPositiveTimeoutIsClassifiedAsInvalidLimits() async {
    let renderer = InkMermaidImageRenderer(limits: .init(timeout: 0))
    let request = InkMermaidRenderRequest(
      source: "graph TD; A-->B",
      display: .init(maxPixelWidth: 100, scale: 2, theme: .light)
    )
    await #expect(throws: InkMermaidRenderError.invalidLimits) {
      try await renderer.render(request)
    }
  }

  @Test @MainActor func subUIKitScaleIsRejectedBeforeWebKitLoads() async {
    let renderer = InkMermaidImageRenderer()
    let request = InkMermaidRenderRequest(
      source: "graph TD; A-->B",
      display: .init(maxPixelWidth: 100, scale: 0.5, theme: .light)
    )
    await #expect(throws: InkMermaidRenderError.invalidDisplaySize) {
      try await renderer.render(request)
    }
  }
}

// WebKit page-process termination, bridge JavaScript errors and snapshot timeout require an iOS runtime;
// they are covered by the integration harness after the public image pipeline wires this renderer in.
