import Testing
import UIKit
@testable import InkMarkdown

/// 仅用于测试的私有行内语法：与内置语法类型区分，验证按动态类型比较。
private struct TestTagSyntax: InkInlineSyntax {
  func render(text: String, context: InkInlineContext) -> NSAttributedString? { nil }
}

private struct TestSemanticImageLoader: InkImageLoading {
  let variant: Int

  func loadImage(source: ImageSource, display: DisplayContext) async throws -> UIImage {
    UIImage()
  }
}

@Suite("InkConfiguration 语义等价与渲染环境注入测试")
@MainActor struct InkConfigurationSemanticsTests {

  @Test("capturingRenderEnvironmentForBackgroundParse 保留已注入环境，仅未注入时自动捕获")
  @MainActor
  func renderEnvironment_capturingPreservesInjectedRenderEnvironment() {
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

  @Test("withResolvedRenderEnvironmentIfNeeded 仅补全 unspecified 字段，不覆盖已注入 category")
  @MainActor
  func renderEnvironment_resolvedPreservesInjectedContentSizeCategory() {
    var config = InkConfiguration.standard
    config.renderEnvironment = InkRenderEnvironment(
      userInterfaceStyle: .unspecified,
      contentSizeCategory: .accessibilityLarge
    )
    let resolved = config.withResolvedRenderEnvironmentIfNeeded()
    #expect(resolved.renderEnvironment.contentSizeCategory == .accessibilityLarge)
    #expect(resolved.renderEnvironment.userInterfaceStyle == UITraitCollection.current.userInterfaceStyle)
  }

  @Test("isSemanticallyEqualTo 按内容比较语法与处理器，而非仅数量")
  func configuration_semanticEqualityComparesContentNotJustCount() {
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

    var scrollTable = base
    scrollTable.blockHandlers = [InkTableBlockHandler(layoutMode: .scroll)]
    var wrapTable = base
    wrapTable.blockHandlers = [InkTableBlockHandler(layoutMode: .wrap)]
    #expect(!scrollTable.isSemanticallyEqualTo(wrapTable))
  }

  @Test("isSemanticallyEqualTo 严格识别 appearance、renderEnvironment 与 closure 注入差异")
  func configuration_semanticEqualityDetectsAppearanceAndEnvironmentChanges() {
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

  @Test("不透明闭包默认保守刷新，显式语义身份可安全复用")
  func configuration_opaqueClosuresUseExplicitSemanticIdentity() {
    let base = InkConfiguration.standard

    var first = base
    first.setSourceFilter({ "prefix:" + $0 }, semanticIdentity: "filter.prefix.v1")
    first.setLinkTapHandler({ _, _ in true }, semanticIdentity: "links.open.v1")

    var equivalent = base
    equivalent.setSourceFilter({ "prefix:" + $0 }, semanticIdentity: "filter.prefix.v1")
    equivalent.setLinkTapHandler({ _, _ in true }, semanticIdentity: "links.open.v1")
    #expect(first.isSemanticallyEqualTo(equivalent))

    var copied = first
    #expect(first.isSemanticallyEqualTo(copied))
    copied.sourceFilter = { "prefix:" + $0 }
    #expect(!first.isSemanticallyEqualTo(copied))

    equivalent.setLinkTapHandler({ _, _ in false }, semanticIdentity: "links.open.v2")
    #expect(!first.isSemanticallyEqualTo(equivalent))
  }

  @Test("表格回调与图片加载配置参与完整语义比较")
  func configuration_appearanceAndImageRenderingCompareOpaqueSemantics() {
    var firstTable = InkAppearance.Table()
    firstTable.setCopyFeedback({ _ in }, semanticIdentity: "table.copy.v1")
    var equivalentTable = InkAppearance.Table()
    equivalentTable.setCopyFeedback({ _ in }, semanticIdentity: "table.copy.v1")
    #expect(firstTable == equivalentTable)
    equivalentTable.onCopyFeedback = { _ in }
    #expect(firstTable != equivalentTable)

    var first = InkImageRendering()
    first.isEnabled = true
    first.setLoader(TestSemanticImageLoader(variant: 1), semanticIdentity: "images.loader.v1")
    first.setImageTapHandler({ _, _ in }, semanticIdentity: "images.tap.v1")
    first.setLoadFinishedHandler({ _, _ in }, semanticIdentity: "images.finished.v1")

    var equivalent = InkImageRendering()
    equivalent.isEnabled = true
    equivalent.setLoader(TestSemanticImageLoader(variant: 1), semanticIdentity: "images.loader.v1")
    equivalent.setImageTapHandler({ _, _ in }, semanticIdentity: "images.tap.v1")
    equivalent.setLoadFinishedHandler({ _, _ in }, semanticIdentity: "images.finished.v1")
    #expect(first == equivalent)

    equivalent.storeConfiguration.countLimit += 1
    #expect(first != equivalent)
    equivalent = first
    equivalent.securityPolicy.stripsQuery.toggle()
    #expect(first != equivalent)
    equivalent = first
    equivalent.loader = TestSemanticImageLoader(variant: 1)
    #expect(first != equivalent)
  }

  @Test("内置生成图 loader 以值状态比较而非实例身份")
  func generatedLoader_providesStableSemantics() {
    var latexA = InkImageRendering()
    latexA.generatedLoader = InkLaTeXGeneratedImageLoader(mode: .inline, style: .init(fontSize: 18))
    var latexB = InkImageRendering()
    latexB.generatedLoader = InkLaTeXGeneratedImageLoader(mode: .inline, style: .init(fontSize: 18))
    #expect(latexA == latexB)

    latexB.generatedLoader = InkLaTeXGeneratedImageLoader(mode: .block, style: .init(fontSize: 18))
    #expect(latexA != latexB)

    var mermaidA = InkImageRendering()
    mermaidA.generatedLoader = InkMermaidGeneratedImageLoader(limits: .init(timeout: 5))
    var mermaidB = InkImageRendering()
    mermaidB.generatedLoader = InkMermaidGeneratedImageLoader(limits: .init(timeout: 5))
    #expect(mermaidA == mermaidB)
    mermaidB.generatedLoader = InkMermaidGeneratedImageLoader(limits: .init(timeout: 6))
    #expect(mermaidA != mermaidB)
  }

  @Test("表格复用语义包含 alignment、行边界与 layout mode")
  func tableReuse_comparesAllLayoutSemantics() {
    let base = InkTableBlock(
      headers: ["A", "B"],
      rows: [["1", "2"], ["3", "4"]],
      alignments: [.left, .right],
      layoutMode: .wrap
    )
    let changedAlignment = InkTableBlock(
      headers: ["A", "B"],
      rows: [["1", "2"], ["3", "4"]],
      alignments: [.center, .right],
      layoutMode: .wrap
    )
    let changedRowBoundary = InkTableBlock(
      headers: ["A", "B"],
      rows: [["1", "2", "3", "4"]],
      alignments: [.left, .right],
      layoutMode: .wrap
    )
    let changedLayoutMode = InkTableBlock(
      headers: ["A", "B"],
      rows: [["1", "2"], ["3", "4"]],
      alignments: [.left, .right],
      layoutMode: .scroll
    )

    #expect(!changedAlignment.hasEquivalentContent(to: base))
    #expect(!changedRowBoundary.hasEquivalentContent(to: base))
    #expect(!changedLayoutMode.hasEquivalentContent(to: base))
  }

  @Test("内置块的复用比较包含样式与完整渲染配置")
  func reusableBlock_comparesConfigurationSemantics() {
    var baseConfiguration = InkConfiguration.standard
    baseConfiguration.setLinkTapHandler({ _, _ in true }, semanticIdentity: "links.v1")
    var changedConfiguration = baseConfiguration
    changedConfiguration.setLinkTapHandler({ _, _ in false }, semanticIdentity: "links.v2")

    let baseCode = InkCodeBlock(
      code: "let value = 1",
      config: baseConfiguration.appearance.codeBlock,
      renderConfiguration: baseConfiguration
    )
    let changedCode = InkCodeBlock(
      code: "let value = 1",
      config: changedConfiguration.appearance.codeBlock,
      renderConfiguration: changedConfiguration
    )
    #expect(!changedCode.hasEquivalentContent(to: baseCode))

    let baseThought = InkThoughtBlock(
      thought: "same",
      config: baseConfiguration.appearance.thought,
      renderConfiguration: baseConfiguration
    )
    let changedThought = InkThoughtBlock(
      thought: "same",
      config: changedConfiguration.appearance.thought,
      renderConfiguration: changedConfiguration
    )
    #expect(!changedThought.hasEquivalentContent(to: baseThought))

    var changedBreakStyle = baseConfiguration.appearance.thematicBreak
    changedBreakStyle.lineThickness += 1
    #expect(!InkThematicBreakBlock(config: changedBreakStyle).hasEquivalentContent(
      to: InkThematicBreakBlock(config: baseConfiguration.appearance.thematicBreak)
    ))
  }
}
