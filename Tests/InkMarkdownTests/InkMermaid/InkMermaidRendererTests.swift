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

  @Test @MainActor func inputLimitsFailBeforeWebKitLoads() async {
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

  @Test @MainActor func nonPositiveTimeoutIsClassifiedAsInvalidLimits() async {
    let renderer = InkMermaidImageRenderer(limits: .init(timeout: 0), bundle: InkMarkdownMermaid.bundle)
    let request = InkMermaidRenderRequest(
      source: "graph TD; A-->B",
      display: .init(maxPixelWidth: 100, scale: 2, theme: .light)
    )
    await #expect(throws: InkMermaidRenderError.invalidLimits) {
      try await renderer.render(request)
    }
  }

  @Test @MainActor func subUIKitScaleIsRejectedBeforeWebKitLoads() async {
    let renderer = InkMermaidImageRenderer(limits: .init(), bundle: InkMarkdownMermaid.bundle)
    let request = InkMermaidRenderRequest(
      source: "graph TD; A-->B",
      display: .init(maxPixelWidth: 100, scale: 0.5, theme: .light)
    )
    await #expect(throws: InkMermaidRenderError.invalidDisplaySize) {
      try await renderer.render(request)
    }
  }

  @Test func bridgePollIgnoresStaleRequestID() throws {
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
    // 生产 limits.timeout 提供有界终止；WebKit 冷启动通常 <5s，失败路径 ≤ timeout。
    let limits = InkMermaidRenderLimits(timeout: 15)
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
  @Test @MainActor func wideJourneySnapshotKeepsRightEdgeContent() async throws {
    let limits = InkMermaidRenderLimits(timeout: 30)
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
    let size = result.image.size
    #expect(size.width == 400)
    // 固有约 1500×565；按宽约束后高约 150，允许测量误差。
    #expect(size.height > 120)
    #expect(size.height < 200)

    let cgImage = try #require(result.image.cgImage)
    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ok = pixels.withUnsafeMutableBytes { raw -> Bool in
      guard let ctx = CGContext(
        data: raw.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else { return false }
      ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    #expect(ok)

    // 抽右半偏右区域：未 fit 时右侧 Act section 整段缺失；fit 后应有任务框 / 表情墨迹。
    // 最右侧常是箭头与留白，故避开最后 5%，并放宽近白阈值。
    let xStart = Int(Double(width) * 0.65)
    let xEnd = Int(Double(width) * 0.95)
    var inked = 0
    var sampled = 0
    for y in stride(from: 0, to: height, by: max(height / 40, 1)) {
      for x in stride(from: xStart, to: max(xEnd, xStart + 1), by: max((xEnd - xStart) / 25, 1)) {
        let offset = y * bytesPerRow + x * bytesPerPixel
        let r = Int(pixels[offset])
        let g = Int(pixels[offset + 1])
        let b = Int(pixels[offset + 2])
        let a = Int(pixels[offset + 3])
        sampled += 1
        if a > 8, (r + g + b) < 730 {
          inked += 1
        }
      }
    }
    #expect(sampled > 0)
    #expect(inked > sampled / 30)
  }
}

// WebKit page-process termination, bridge JavaScript errors and snapshot timeout require an iOS runtime;
// they are covered by the integration harness after the public image pipeline wires this renderer in.
