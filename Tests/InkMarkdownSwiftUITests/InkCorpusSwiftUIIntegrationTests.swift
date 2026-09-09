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
// 在静态渲染与 streaming promotion 后给出相同链接、inline、段落和表格语义
//（不是第二套语义实现）。

@Suite("Canonical Corpus SwiftUI 集成通道")
@MainActor
struct InkCorpusSwiftUIIntegrationTests {

  // MARK: - 静态集成通道

  /// SwiftUI 静态路径（Coordinator → UIKit 容器）的共享语义满足 corpus 预期。
  @Test("SwiftUI 静态集成满足 corpus 语义", arguments: InkSemanticCorpus.all)
  func staticIntegration_matchesCorpusSemantics(fixture: InkSemanticCorpusFixture) throws {
    guard fixture.channels.contains(.swiftUI) else { return }

    let configuration = Self.deterministicConfiguration()

    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    defer { coordinator.teardown(from: container) }

    coordinator.updateStatic(markdown: fixture.markdown, configuration: configuration)
    container.layoutIfNeeded()

    let attributed = try Self.attributedContent(in: container)
    let blockBaseline = InkChannelProjection.blockAttributedSource(
      fixture,
      configuration: configuration
    )
    InkCorpusAssertions.assertLinkSemantics(of: attributed, fixture: fixture, channel: "swiftui-static")
    InkCorpusAssertions.assertInlineSemantics(of: attributed, fixture: fixture, channel: "swiftui-static")
    InkCorpusAssertions.assertParagraphSemantics(of: attributed, fixture: fixture, channel: "swiftui-static")
    InkCorpusAssertions.assertParagraphProjectionsEqual(
      blockBaseline,
      attributed,
      fixture: fixture,
      channels: (lhs: "block", rhs: "swiftui-static")
    )
  }

  // MARK: - streaming promotion 通道

  /// SwiftUI streaming 会话 finish → promotion 后的呈现与 canonical block 投影等价。
  @Test("SwiftUI streaming promotion 满足完整 corpus 语义", arguments: InkSemanticCorpus.all)
  func streamingPromotion_matchesCorpusSemantics(fixture: InkSemanticCorpusFixture) async throws {
    guard fixture.channels.contains(.swiftUI) else { return }

    let configuration = Self.deterministicConfiguration()

    let session = InkMarkdownRenderSession(configuration: configuration)
    let container = InkMarkdownContainerView()
    let coordinator = InkMarkdownCoordinator()
    coordinator.containerView = container
    coordinator.updateStreaming(session: session)
    defer { coordinator.teardown(from: container) }

    for chunk in fixture.streamingChunks() {
      session.append(chunk)
    }
    session.finish()
    try #require(
      await InkAsyncTestProbe.wait(timeoutNanoseconds: 3_000_000_000) {
        session.isPromoted
      },
      "fixture \(fixture.id) 未在超时前 promotion"
    )

    // promotion 更新与会话状态可能分属相邻 main-queue turn；重入同一 adapter seam 收敛呈现。
    coordinator.updateStreaming(session: session)
    container.layoutIfNeeded()

    let attributed = try Self.attributedContent(in: container)

    // promotion 使用 InkBlockRenderer 组合，因此基线是 canonical block 呈现投影。
    let blockChannelProjection = InkLinkSemanticProjection(
      InkChannelProjection.blockAttributedSource(fixture, configuration: configuration)
    )
    InkCorpusAssertions.assertLinkSemantics(of: attributed, fixture: fixture, channel: "swiftui-promotion")
    InkCorpusAssertions.assertInlineSemantics(of: attributed, fixture: fixture, channel: "swiftui-promotion")
    InkCorpusAssertions.assertParagraphSemantics(of: attributed, fixture: fixture, channel: "swiftui-promotion")
    InkCorpusAssertions.assertProjectionsEqual(
      blockChannelProjection,
      InkLinkSemanticProjection(attributed),
      fixture: fixture,
      channels: (lhs: "block", rhs: "swiftui-promotion")
    )
    InkCorpusAssertions.assertParagraphProjectionsEqual(
      InkChannelProjection.blockAttributedSource(fixture, configuration: configuration),
      attributed,
      fixture: fixture,
      channels: (lhs: "block", rhs: "swiftui-promotion")
    )
    InkCorpusAssertions.assertBlockTypes(
      InkChannelProjection.blockTypeNames(of: session.blocks),
      fixture: fixture
    )
    InkCorpusAssertions.assertTableSemantics(
      InkChannelProjection.tableStructures(of: session.blocks),
      fixture: fixture,
      channel: "swiftui-promotion"
    )
    InkCorpusAssertions.assertTablePresentationsEqual(
      InkChannelProjection.tablePresentationStructures(of: session.blocks),
      container.subviews.compactMap(
        InkTablePresentationProjectionExtractor.projection(in:)
      ),
      fixture: fixture,
      channels: (lhs: "block-view", rhs: "swiftui-promotion")
    )
  }

  // MARK: - Helpers

  private static func deterministicConfiguration() -> InkConfiguration {
    var appearance = InkAppearance()
    appearance.supportsDynamicType = false
    return InkConfiguration(appearance: appearance)
  }

  private static func attributedContent(in container: InkMarkdownContainerView) throws -> NSAttributedString {
    let textViews = InkViewProjectionExtractor.textViews(in: container)
    try #require(!textViews.isEmpty, "SwiftUI 集成容器未产出任何 UITextView")
    return InkViewProjectionExtractor.attributedContent(in: container)
  }
}
