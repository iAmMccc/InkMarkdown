import Testing
import UIKit
@testable import InkMarkdown

/// 仅用于测试的私有行内语法：与内置语法类型区分，验证按动态类型比较。
private struct TestTagSyntax: InkInlineSyntax {
  func render(text: String, context: InkInlineContext) -> NSAttributedString? { nil }
}

@Suite("InkConfiguration 语义等价与渲染环境注入测试")
@MainActor struct InkConfigurationSemanticsTests {

  @Test("capturingRenderEnvironmentForBackgroundParse 保留已注入环境，仅未注入时自动捕获")
  @MainActor
  func capturingPreservesInjectedRenderEnvironment() {
    // 用户已注入 .dark：必须原样保留，不能被主线程当前 trait 覆盖。
    var injected = InkConfiguration.standard
    injected.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: .dark)
    let preserved = injected.capturingRenderEnvironmentForBackgroundParse()
    #expect(preserved.renderEnvironment.userInterfaceStyle == .dark)

    // 未注入（默认 .unspecified）：主线程捕获当前 trait 快照。
    let notInjected = InkConfiguration.standard
    let filled = notInjected.capturingRenderEnvironmentForBackgroundParse()
    #expect(filled.renderEnvironment.userInterfaceStyle == UITraitCollection.current.userInterfaceStyle)
  }

  @Test("isSemanticallyEqualTo 按内容比较语法与处理器，而非仅数量")
  func semanticEqualityComparesContentNotJustCount() {
    let base = InkConfiguration.standard

    // 同类型、同顺序 → 语义等价（保持 Coordinator 幂等）。
    var sameHandlers = base
    sameHandlers.blockHandlers = [
      InkThoughtBlockHandler(),
      InkCodeBlockHandler(),
      InkTableBlockHandler(),
      InkThematicBreakHandler(),
    ]
    #expect(base.isSemanticallyEqualTo(sameHandlers))

    // 语法类型不同（数量同为 1）→ 不等价；旧实现仅比数量会误判相等。
    var latexSyntax = base
    latexSyntax.inlineSyntaxes = [InkLaTeXInlineSyntax(rendering: .init())]
    var tagSyntax = base
    tagSyntax.inlineSyntaxes = [TestTagSyntax()]
    #expect(!latexSyntax.isSemanticallyEqualTo(tagSyntax))

    // 语法顺序不同 → 不等价（渲染按顺序询问，顺序影响输出）。
    var reordered = base
    reordered.inlineSyntaxes = [TestTagSyntax(), InkLaTeXInlineSyntax(rendering: .init())]
    var latexFirst = base
    latexFirst.inlineSyntaxes = [InkLaTeXInlineSyntax(rendering: .init()), TestTagSyntax()]
    #expect(!latexFirst.isSemanticallyEqualTo(reordered))

    // 处理器类型不同（数量同为 4）→ 不等价；验证动态类型比对生效，而非仅比较 count。
    var imageHandlerFirst = base
    imageHandlerFirst.blockHandlers = [
      InkImageBlockHandler(),
      InkCodeBlockHandler(),
      InkTableBlockHandler(),
      InkThematicBreakHandler(),
    ]
    #expect(!base.isSemanticallyEqualTo(imageHandlerFirst))
  }

  @Test("isSemanticallyEqualTo 严格识别 appearance、renderEnvironment 与 closure 注入差异")
  func semanticEqualityDetectsAppearanceAndEnvironmentChanges() {
    let base = InkConfiguration.standard

    // 1. Appearance 属性变化
    var differentFontSize = base
    differentFontSize.appearance.text.fontSize = 25
    #expect(!base.isSemanticallyEqualTo(differentFontSize))

    // 2. RenderEnvironment 变化
    var darkConfig = base
    darkConfig.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: .dark)
    var lightConfig = base
    lightConfig.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: .light)
    #expect(!darkConfig.isSemanticallyEqualTo(lightConfig))

    // 3. sourceFilter 从无到有
    var filtered = base
    filtered.sourceFilter = { $0 }
    #expect(!base.isSemanticallyEqualTo(filtered))

    // 4. linkTapHandler 从无到有
    var withLinkHandler = base
    withLinkHandler.linkTapHandler = { _, _ in true }
    #expect(!base.isSemanticallyEqualTo(withLinkHandler))
  }
}
