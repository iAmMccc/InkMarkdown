import InkMarkdownMermaid

public enum MermaidConsumerProbe {
  public static func register() -> Bool {
    InkMarkdownMermaid.register()
  }
}
