import Foundation
import Testing
import SwiftUI
import UIKit
import InkMarkdown
import InkMarkdownSemanticCorpus
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

// MARK: - Canonical corpus SwiftUI integration 通道
//
// 与核心通道套件共享同一份 corpus fixture；本套件证明 SwiftUI adapter
// 在静态渲染与 streaming promotion 后给出相同链接语义（不是第二套语义实现）。

@Suite("Canonical Corpus SwiftUI 集成通道")
@MainActor
struct InkCorpusSwiftUIIntegrationTests {

  // MARK: - 静态集成通道

  /// SwiftUI 静态路径（Coordinator → UIKit 容器）的链接语义满足 corpus 预期。
  @Test("SwiftUI 静态集成链接语义满足 corpus 预期", arguments: InkSemanticCorpus.all)
  func staticIntegration_matchesLinkExpectations(fixture: InkSemanticCorpusFixture) throws {
    guard fixture.channels.contains(.swiftUI) else { return }

    var configuration = InkConfiguration.standard
    // 集成通道注入 handler spy：验证视图产物与回调入口在静态路径同时可用
    //（handler 契约本身的 true/false 行为属于 ticket 04 的套件）。
    var handledURLs: [URL] = []
    configuration.linkTapHandler = { url, _ in
      handledURLs.append(url)
      return true
    }

    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    defer { coordinator.teardown(from: container) }

    coordinator.updateStatic(markdown: fixture.markdown, configuration: configuration)

    let attributed = try Self.concatenatedTextViewContent(in: container)
    InkCorpusAssertions.assertLinkSemantics(of: attributed, fixture: fixture, channel: "swiftui-static")
  }

  // MARK: - streaming promotion 通道

  /// SwiftUI streaming 会话 finish → promotion 后的 blocks 与静态语义投影等价。
  @Test("SwiftUI streaming promotion 链接语义与静态等价", arguments: InkSemanticCorpus.all)
  func streamingPromotion_matchesStaticProjection(fixture: InkSemanticCorpusFixture) async throws {
    guard fixture.channels.contains(.swiftUI) else { return }

    var configuration = InkConfiguration.standard
    var handledURLs: [URL] = []
    configuration.linkTapHandler = { url, _ in
      handledURLs.append(url)
      return true
    }

    let session = InkMarkdownRenderSession(configuration: configuration)
    for chunk in fixture.streamingChunks() {
      session.append(chunk)
    }
    session.finish()
    await Self.waitForPromotion(session)

    let attributed = NSMutableAttributedString()
    for block in session.blocks {
      if let textBlock = block as? InkAttributedTextBlock {
        attributed.append(textBlock.attributedText)
      }
    }

    // 基线选择：promotion 使用 `InkBlockRenderer` 组合（块分隔符 + 尾部哨兵），
    // 因此等价基线是**静态 block 通道**，而非 document 直渲——两者组合路径不同，
    // plainText 必然不同，属于组合产物差异而非语义差异。
    let blockChannelProjection = InkLinkSemanticProjection(
      InkChannelProjection.blockAttributedSource(fixture, configuration: configuration)
    )
    InkCorpusAssertions.assertLinkSemantics(of: attributed, fixture: fixture, channel: "swiftui-promotion")
    InkCorpusAssertions.assertProjectionsEqual(
      blockChannelProjection,
      InkLinkSemanticProjection(attributed),
      fixture: fixture,
      channels: (lhs: "block", rhs: "swiftui-promotion")
    )
  }

  // MARK: - Helpers

  private static func concatenatedTextViewContent(in container: InkMarkdownContainerView) throws -> NSAttributedString {
    let textViews = Self.allTextViews(in: container)
    try #require(!textViews.isEmpty, "SwiftUI 集成容器未产出任何 UITextView")
    let result = NSMutableAttributedString()
    for textView in textViews {
      result.append(textView.attributedText)
    }
    return result
  }

  private static func allTextViews(in view: UIView) -> [UITextView] {
    var result: [UITextView] = []
    if let textView = view as? UITextView {
      result.append(textView)
    }
    for subview in view.subviews {
      result.append(contentsOf: allTextViews(in: subview))
    }
    return result
  }

  /// 与 InkMarkdownRenderSessionTests.waitForRunLoop 相同的既定轮询模式。
  private static func waitForPromotion(
    _ session: InkMarkdownRenderSession,
    timeoutNanoseconds: UInt64 = 3_000_000_000
  ) async {
    var elapsed: UInt64 = 0
    let stepNanoseconds: UInt64 = 10_000_000
    while !session.isPromoted, elapsed < timeoutNanoseconds {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async {
          RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
          continuation.resume()
        }
      }
      elapsed += stepNanoseconds
    }
  }
}
