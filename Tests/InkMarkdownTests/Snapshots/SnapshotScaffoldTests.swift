import Testing
import UIKit
@testable import InkMarkdown

// MARK: - 快照基建冒烟测试（T1.1）
//
// 目的：证明 RenderSnapshot 基建可用、断言助手行为正确（正例与反例）。
// 这是 T1.2/T1.3（CommonMark + GFM 全集契约快照）的地基。

@Suite @MainActor struct SnapshotScaffoldTests {

  /// 基建可渲染 + 可抽快照，纯文本不被属性抽取破坏。
  @Test func scaffold_rendersAndExtractsPlainText() {
    let snap = RenderSnapshotting.snapshot("## 标题 `code` [link](https://x.com)")
    #expect(snap.plainText.contains("标题"))
    #expect(snap.plainText.contains("code"))
    #expect(snap.plainText.contains("link"))
    #expect(!snap.runs.isEmpty)
  }

  /// `someRun` 正例：混合文本里应能找到等宽 run（行内代码）。
  @Test func someRun_findsMonospaceRun() {
    let snap = RenderSnapshotting.snapshot("正文含 `code` 片段")
    RenderContractAssertions.someRun(
      snap,
      where: { $0.isMonospace },
      description: "行内代码等宽"
    )
  }

  /// `noRun` 正例：普通正文里不应出现链接 run。
  @Test func noRun_confirmsNoLinkInPlainParagraph() {
    let snap = RenderSnapshotting.snapshot("纯文本，没有链接")
    RenderContractAssertions.noRun(
      snap,
      where: { $0.hasLink },
      description: "无链接"
    )
  }

  /// `allRunsLockLineHeight` 正例：整段正文锁 28。
  @Test func allRunsLockLineHeight_paragraph() {
    let snap = RenderSnapshotting.snapshot("一段**加粗**与`代码`混排")
    RenderContractAssertions.allRunsLockLineHeight(snap, expected: 28)
  }

  /// `colorKey` 等价性：链接 run 的颜色应被识别为 .link，而非记录浮点分量。
  @Test func colorKey_identifiesLinkColor() {
    let snap = RenderSnapshotting.snapshot("点这个 [链接](https://example.com) 跳转")
    let linkRun = snap.runs.first(where: { $0.attrs.hasLink })
    #expect(linkRun != nil)
    #expect(linkRun?.attrs.colorKey == .link)
  }
}
