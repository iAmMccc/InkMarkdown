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

  @Test @MainActor func rendersWideJourneyWithoutRightEdgeClipping() async throws {
    // Fresh hosted runner 的 WebContent 首次启动实测可超过 60 秒；单次预算设为 120 秒，
    // renderer 仍只保留 production 的一次有界冷启动重试，默认值与调用方配置不受影响。
    let limits = InkMermaidRenderLimits(timeout: 120)
    let renderer = InkMermaidImageRenderer(limits: limits)
    let request = InkMermaidRenderRequest(
      source: """
      journey
          title Sample User Journey
          section Discover
            Open App: 5: User
            Enter keyword: 4: User
          section Understand
            View overview: 5: User
            Expand details: 3: User
          section Act
            Save item: 4: User
            Export report: 3: User
      """,
      display: .init(maxPixelWidth: 400, scale: 1, theme: .light)
    )

    let result = try await renderer.render(request)

    #expect(result.image.size.width == 400)
    #expect(result.image.size.height > 120)
    #expect(result.image.size.height < 200)
    #expect(result.pngData.isEmpty == false)
    #expect(result.cacheIdentity == request.cacheIdentity())

    let cgImage = try #require(result.image.cgImage)
    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    let rendered = pixels.withUnsafeMutableBytes { rawBuffer -> Bool in
      guard let context = CGContext(
        data: rawBuffer.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { return false }
      context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    #expect(rendered)

    // Act section 位于图表右侧。若 bridge 只缩放 viewport 而未 fit SVG，该区域会被裁掉。
    let xStart = Int(Double(width) * 0.65)
    let xEnd = Int(Double(width) * 0.95)
    var inkedPixelCount = 0
    var sampledPixelCount = 0
    for y in stride(from: 0, to: height, by: max(height / 40, 1)) {
      for x in stride(
        from: xStart,
        to: max(xEnd, xStart + 1),
        by: max((xEnd - xStart) / 25, 1)
      ) {
        let offset = y * bytesPerRow + x * bytesPerPixel
        let red = Int(pixels[offset])
        let green = Int(pixels[offset + 1])
        let blue = Int(pixels[offset + 2])
        let alpha = Int(pixels[offset + 3])
        sampledPixelCount += 1
        if alpha > 8, red + green + blue < 730 {
          inkedPixelCount += 1
        }
      }
    }
    #expect(sampledPixelCount > 0)
    #expect(inkedPixelCount > sampledPixelCount / 30)
  }
}
