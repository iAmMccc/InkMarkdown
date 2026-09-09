import InkMarkdown
import InkMarkdownKingfisher

public enum KingfisherConsumerProbe {
  public static func configuration() -> InkConfiguration {
    var configuration = InkConfiguration.standard
    configuration.appearance.imageRendering.isEnabled = true
    configuration.appearance.imageRendering.backend = InkKingfisherImageBackend()
    return configuration
  }
}
