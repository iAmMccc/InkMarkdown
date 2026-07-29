import Foundation
import Testing
@testable import InkMarkdown

struct InkMermaidBridgeResourceTests {
  @Test func bridgeUsesStrictCSPAndOrderedExternalScripts() throws {
    let resourceURL = try #require(Bundle.module.url(
      forResource: "InkMermaidBridge",
      withExtension: "html"
    ))
    let html = try String(contentsOf: resourceURL, encoding: .utf8)

    #expect(html.contains("script-src 'self'"))
    #expect(!html.contains("script-src 'unsafe-inline'"))
    #expect(!html.contains("<script>"))
    #expect(html.components(separatedBy: "<script ").count == 3)
    let eventHandler = try NSRegularExpression(pattern: #"\son[a-zA-Z]+\s*="#)
    #expect(eventHandler.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) == nil)

    let mermaid = try #require(html.range(of: #"<script src="mermaid.min.js"></script>"#))
    let bridge = try #require(html.range(of: #"<script src="InkMermaidBridge.js"></script>"#))
    #expect(mermaid.lowerBound < bridge.lowerBound)

    let bridgeURL = try #require(Bundle.module.url(
      forResource: "InkMermaidBridge",
      withExtension: "js"
    ))
    #expect(FileManager.default.fileExists(atPath: bridgeURL.path))
  }
}
