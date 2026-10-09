import Testing
import UIKit
@testable import InkMarkdown

@MainActor private func latexConfiguration(
  allowsInlineDollar: Bool = false,
  textColor: UIColor = .label,
  userInterfaceStyle: UIUserInterfaceStyle = .unspecified
) -> InkConfiguration {
  var appearance = InkAppearance()
  appearance.latexRendering.isEnabled = true
  appearance.latexRendering.allowsInlineDollarDelimiter = allowsInlineDollar
  appearance.text.color = textColor
  var configuration = InkConfiguration(appearance: appearance)
  let style = userInterfaceStyle == .unspecified
    ? (Thread.isMainThread ? UITraitCollection.current.userInterfaceStyle : UIUserInterfaceStyle.light)
    : userInterfaceStyle
  configuration.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: style)
  return configuration
}

@Test @MainActor func latex_labelColorDiffersBetweenLightAndDarkSnapshots() {
  let light = InkLaTeXColor(resolving: .label, environment: InkRenderEnvironment(userInterfaceStyle: .light))
  let dark = InkLaTeXColor(resolving: .label, environment: InkRenderEnvironment(userInterfaceStyle: .dark))
  #expect(light != dark)
}

@Test @MainActor func latex_explicitColorOverridesDynamicLabelInStableIdentity() {
  var appearance = InkAppearance()
  appearance.latexRendering.isEnabled = true
  appearance.latexRendering.allowsInlineDollarDelimiter = true
  appearance.latexRendering.inlineStyle.color = .init(red: 255, green: 0, blue: 0)
  appearance.text.color = .label
  var configuration = InkConfiguration(appearance: appearance)
  configuration.renderEnvironment = InkRenderEnvironment(userInterfaceStyle: .dark)

  let rendered = InkAttributedRenderer.render("$x$", configuration: configuration)
  let attachment = rendered.attribute(.attachment, at: 0, effectiveRange: nil) as? InkImageAttachment
  let explicitColor = InkLaTeXColor(red: 255, green: 0, blue: 0)
  let contextualLabelDark = InkLaTeXColor(resolving: .label, environment: InkRenderEnvironment(userInterfaceStyle: .dark))

  #expect(
    attachment?.source.generatedRequest?.styleIdentity
      == "inline:" + appearance.latexRendering.inlineStyle.stableID(resolvedColor: explicitColor)
  )
  #expect(
    attachment?.source.generatedRequest?.styleIdentity
      != "inline:" + InkLaTeXStyle(fontSize: 18).stableID(resolvedColor: contextualLabelDark)
  )
}

@Test @MainActor func latexEnableUsesCurrentAppearanceAtRenderTime() {
  var configuration = latexConfiguration(allowsInlineDollar: true)
  configuration.appearance.latexRendering.inlineStyle.fontSize = 31

  let rendered = InkAttributedRenderer.render("$x$", configuration: configuration)
  let attachment = rendered.attribute(.attachment, at: 0, effectiveRange: nil) as? InkImageAttachment
  let resolvedColor = InkLaTeXColor(
    resolving: configuration.appearance.text.color,
    environment: configuration.renderEnvironment
  )
  let resolvedStyle = configuration.appearance.latexRendering.inlineStyle.resolved(with: resolvedColor)

  #expect(configuration.inlineSyntaxes.isEmpty)
  #expect(
    attachment?.source.generatedRequest?.styleIdentity
      == "inline:" + resolvedStyle.stableID(resolvedColor: resolvedColor)
  )
}

@Test @MainActor func latex_appearanceFlagEnablesInlineSyntaxWithoutRegistration() {
  let rendered = InkAttributedRenderer.render(
    "\\(x\\)",
    configuration: latexConfiguration()
  )
  #expect(rendered.attribute(.attachment, at: 0, effectiveRange: nil) is InkImageAttachment)
}

@Test @MainActor func latex_defaultLeavesDollarDelimitedTextUntouched() {
  let rendered = InkAttributedRenderer.render(
    "价格是 $5",
    configuration: latexConfiguration()
  )
  #expect(rendered.attribute(.attachment, at: 0, effectiveRange: nil) == nil)
  #expect(rendered.string.contains("$5"))
}

@Test @MainActor func latex_dollarOptInRendersAttachment() {
  let rendered = InkAttributedRenderer.render(
    "$x$",
    configuration: latexConfiguration(allowsInlineDollar: true)
  )
  #expect(rendered.attribute(.attachment, at: 0, effectiveRange: nil) is InkImageAttachment)
}

@Test @MainActor func latex_parenthesesAndBareDollarDoNotCrossContaminate() {
  let rendered = InkAttributedRenderer.render(
    "已知 \\(a\\) 与 $5",
    configuration: latexConfiguration()
  )
  var foundAttachment = false
  rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length), options: []) { value, _, _ in
    if value is InkImageAttachment { foundAttachment = true }
  }
  #expect(foundAttachment)
  #expect(rendered.string.contains("$5"))
}

@Test @MainActor func latex_escapedParenthesesAreNotPromotedThroughMarkupPath() {
  let rendered = InkAttributedRenderer.render(
    "路径 \\\\(not math\\\\) 结束",
    configuration: latexConfiguration()
  )
  rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length), options: []) { value, _, stop in
    if value is InkImageAttachment {
      Issue.record("Escaped \\( should not render as LaTeX")
      stop.pointee = true
    }
  }
  // cmark 保留转义后的 `\(` / `\)` 字面量，闭合括号前仍有反斜杠，故不能断言裸 `(not math)`。
  #expect(rendered.string.contains("not math"))
  #expect(rendered.string.contains("\\("))
}

@Test @MainActor func latex_plainParenthesesAreNotPromotedThroughMarkupPath() {
  let rendered = InkAttributedRenderer.render(
    "普通 (x) 括号",
    configuration: latexConfiguration()
  )
  rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length), options: []) { value, _, stop in
    if value is InkImageAttachment {
      Issue.record("Plain parentheses should not render as LaTeX")
      stop.pointee = true
    }
  }
  #expect(rendered.string.contains("(x)"))
}

@Test @MainActor func latexBlockHandlerPromotesBracketBlockParagraph() {
  let blocks = InkBlockRenderer.render(
    "\\[E = mc^2\\]",
    configuration: latexConfiguration()
  )
  #expect(blocks.count == 1)
  #expect(blocks[0] is InkImageBlock)
}

@Test @MainActor func latexBlockHandlerDoesNotPromoteMixedBracketParagraph() {
  let blocks = InkBlockRenderer.render(
    "前缀 \\[E = mc^2\\] 后缀",
    configuration: latexConfiguration()
  )
  #expect(blocks.count == 1)
  #expect(!(blocks[0] is InkImageBlock))
}

@Test @MainActor func latex_inlineStyleIdentityFollowsDarkContextColor() {
  let configuration = latexConfiguration(allowsInlineDollar: true, textColor: .white)
  let appearance = configuration.appearance

  let rendered = InkAttributedRenderer.render("$x$", configuration: configuration)
  let attachment = rendered.attribute(.attachment, at: 0, effectiveRange: nil) as? InkImageAttachment
  let resolvedColor = InkLaTeXColor(resolving: .white, environment: configuration.renderEnvironment)
  let resolvedStyle = appearance.latexRendering.inlineStyle.resolved(with: resolvedColor)
  let labelLight = InkLaTeXColor(resolving: .label, environment: InkRenderEnvironment(userInterfaceStyle: .light))

  #expect(
    attachment?.source.generatedRequest?.styleIdentity
      == "inline:" + resolvedStyle.stableID(resolvedColor: resolvedColor)
  )
  #expect(
    attachment?.source.generatedRequest?.styleIdentity
      != "inline:" + appearance.latexRendering.inlineStyle.resolved(with: labelLight).stableID(resolvedColor: labelLight)
  )
}

@Test @MainActor func latex_explicitColorOverridesContextInStableIdentity() {
  var appearance = InkAppearance()
  appearance.latexRendering.isEnabled = true
  appearance.latexRendering.allowsInlineDollarDelimiter = true
  appearance.latexRendering.inlineStyle.color = .init(red: 255, green: 0, blue: 0)
  appearance.text.color = .white
  let configuration = InkConfiguration(appearance: appearance)

  let rendered = InkAttributedRenderer.render("$x$", configuration: configuration)
  let attachment = rendered.attribute(.attachment, at: 0, effectiveRange: nil) as? InkImageAttachment
  let explicitColor = InkLaTeXColor(red: 255, green: 0, blue: 0)

  #expect(
    attachment?.source.generatedRequest?.styleIdentity
      == "inline:" + appearance.latexRendering.inlineStyle.stableID(resolvedColor: explicitColor)
  )
}
