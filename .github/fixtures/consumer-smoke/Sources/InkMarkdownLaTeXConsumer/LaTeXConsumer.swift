import InkMarkdownLaTeX

public enum LaTeXConsumerProbe {
  public static func register() -> Bool {
    InkMarkdownLaTeX.register()
  }
}
