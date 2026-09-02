import Foundation
import Testing
import UIKit
import InkMarkdown
import InkMarkdownSemanticCorpus

// MARK: - Canonical corpus 链接 tracer（attributed / block / streaming finish）
//
// ticket 01 的跨通道证据：同一批 fixture 在三个核心通道中保持相同链接文本与
// destination。SwiftUI integration 通道见 InkMarkdownSwiftUITests 的对应套件；
// 两个套件共享同一份 corpus，不复制 fixture。

@Suite("Canonical Corpus 链接 Tracer（核心通道）")
@MainActor
struct InkCorpusLinkTracerTests {

  private let configuration = InkConfiguration.standard

  /// attributed 通道：每个适用 fixture 的链接语义满足预期。
  @Test("attributed 通道链接语义满足 corpus 预期", arguments: InkSemanticCorpus.all)
  func attributedChannel_matchesLinkExpectations(fixture: InkSemanticCorpusFixture) {
    guard fixture.channels.contains(.attributed) else { return }
    let attributed = InkChannelProjection.attributedSource(fixture, configuration: configuration)
    InkCorpusAssertions.assertLinkSemantics(of: attributed, fixture: fixture, channel: "attributed")
    InkCorpusAssertions.assertInlineSemantics(of: attributed, fixture: fixture, channel: "attributed")
  }

  /// block 通道：富文本 fallback 块携带与 attributed 相同的链接语义。
  @Test("block 通道链接语义满足 corpus 预期", arguments: InkSemanticCorpus.all)
  func blockChannel_matchesLinkExpectations(fixture: InkSemanticCorpusFixture) {
    guard fixture.channels.contains(.block) else { return }
    let attributed = InkChannelProjection.blockAttributedSource(fixture, configuration: configuration)
    InkCorpusAssertions.assertLinkSemantics(of: attributed, fixture: fixture, channel: "block")
    InkCorpusAssertions.assertInlineSemantics(of: attributed, fixture: fixture, channel: "block")
  }

  /// streaming finish 通道：终态投影与 attributed 静态投影**完全相等**。
  ///
  /// finish() 走同一份全量渲染路径，因此除序列化表示外的用户可观察语义必须一致；
  /// 分片策略使用 fixture 声明的 token 边界。
  @Test("streaming finish 通道与静态语义投影等价", arguments: InkSemanticCorpus.all)
  func streamingFinishChannel_matchesStaticProjection(fixture: InkSemanticCorpusFixture) async {
    guard fixture.channels.contains(.streamingFinish) else { return }

    let staticAttributed = InkChannelProjection.attributedSource(fixture, configuration: configuration)
    let streamingAttributed = await InkChannelProjection.streamingFinishSource(
      fixture,
      configuration: configuration
    )

    InkCorpusAssertions.assertLinkSemantics(
      of: streamingAttributed,
      fixture: fixture,
      channel: "streaming-finish"
    )
    InkCorpusAssertions.assertInlineSemantics(
      of: streamingAttributed,
      fixture: fixture,
      channel: "streaming-finish"
    )
    InkCorpusAssertions.assertProjectionsEqual(
      InkLinkSemanticProjection(staticAttributed),
      InkLinkSemanticProjection(streamingAttributed),
      fixture: fixture,
      channels: (lhs: "attributed", rhs: "streaming-finish")
    )
  }
}
