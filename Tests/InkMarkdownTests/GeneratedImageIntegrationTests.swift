import Testing
import UIKit
@testable import InkMarkdown

@Test func latexEnableUsesCurrentAppearanceAtRenderTime() {
  var configuration = InkConfiguration()
  configuration.enableLaTeXRendering()
  configuration.appearance.latexRendering.inlineStyle.fontSize = 31

  let rendered = InkAttributedRenderer.render("$x$", configuration: configuration)
  let attachment = rendered.attribute(.attachment, at: 0, effectiveRange: nil) as? InkImageAttachment

  #expect(configuration.inlineSyntaxes.isEmpty)
  #expect(attachment?.source.generatedRequest?.styleIdentity == "inline:" + configuration.appearance.latexRendering.inlineStyle.stableID)
}

@Test func latexAppearanceFlagEnablesInlineSyntaxWithoutRegistration() {
  var appearance = InkAppearance()
  appearance.latexRendering.isEnabled = true
  let rendered = InkAttributedRenderer.render("$x$", configuration: InkConfiguration(appearance: appearance))
  #expect(rendered.attribute(.attachment, at: 0, effectiveRange: nil) is InkImageAttachment)
}
