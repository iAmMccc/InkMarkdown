import CoreGraphics
import Testing
import UIKit

@testable import ExampleApp
@testable import InkMarkdown
import InkMarkdownMermaid

@Suite(.serialized)
struct MermaidRenderingIntegrationTests {

  @Test @MainActor func rendersWideJourneyWithoutRightEdgeClipping() async throws {
    let renderer = InkMermaidImageRenderer()
    let request = InkMermaidRenderRequest(
      source: DemoMermaidSamples.wideJourney.source,
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
