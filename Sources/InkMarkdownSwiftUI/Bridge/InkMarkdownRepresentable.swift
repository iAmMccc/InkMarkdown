//
//  InkMarkdownRepresentable.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import SwiftUI

/// 渲染模式定义。
enum RenderMode {
  /// 静态渲染模式，接收完整的 Markdown 纯文本。
  case `static`(markdown: String)
  /// 静态块级模式，直接消费已解析 blocks（避免重复解析丢失折叠态等 UI 状态）。
  case blocks([InkRenderableBlock])
  /// 流式渲染模式，绑定活跃的流式渲染会话。
  case streaming(session: InkMarkdownRenderSession)
}

/// 将 `InkMarkdownContainerView` 桥接至 SwiftUI 视图层次结构的 `UIViewRepresentable` 实现。
/// 支持静态 Markdown 渲染与流式 Markdown 实时渲染双模式。
struct InkMarkdownRepresentable: UIViewRepresentable {

  let mode: RenderMode
  let configuration: InkConfiguration
  /// promotion 代际；仅用于在 `isPromoted` 翻转时触发 `updateUIView`，不参与渲染语义。
  var promotionGeneration: Bool = false

  @Environment(\.sizeCategory) private var sizeCategory
  @Environment(\.colorScheme) private var colorScheme

  /// 便捷静态初始化器。
  init(markdown: String, configuration: InkConfiguration) {
    self.mode = .static(markdown: markdown)
    self.configuration = configuration
  }

  /// 指定渲染模式的初始化器。
  init(mode: RenderMode, configuration: InkConfiguration, promotionGeneration: Bool = false) {
    self.mode = mode
    self.configuration = configuration
    self.promotionGeneration = promotionGeneration
  }

  func makeUIView(context: Context) -> InkMarkdownContainerView {
    let container = InkMarkdownContainerView()
    context.coordinator.containerView = container
    return container
  }

  func updateUIView(_ uiView: InkMarkdownContainerView, context: Context) {
    let effectiveConfig = context.coordinator.resolvedConfiguration(
      configurationWithEnvironmentSnapshot(configuration)
    )

    switch mode {
    case .static(let markdown):
      context.coordinator.updateStatic(markdown: markdown, configuration: effectiveConfig)
    case .blocks(let blocks):
      context.coordinator.updateBlocks(blocks, configuration: effectiveConfig)
    case .streaming(let session):
      context.coordinator.updateStreaming(session: session)
    }
  }

  func makeCoordinator() -> InkMarkdownCoordinator {
    InkMarkdownCoordinator()
  }

  @available(iOS 16.0, *)
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: InkMarkdownContainerView, context: Context) -> CGSize? {
    guard let width = proposal.width else { return nil }
    return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
  }

  static func dismantleUIView(_ uiView: InkMarkdownContainerView, coordinator: InkMarkdownCoordinator) {
    coordinator.teardown(from: uiView)
  }

  private func configurationWithEnvironmentSnapshot(_ base: InkConfiguration) -> InkConfiguration {
    var snapshot = base
    snapshot.renderEnvironment = InkRenderEnvironment(
      userInterfaceStyle: colorScheme == .dark ? .dark : .light,
      contentSizeCategory: uiContentSizeCategory(from: sizeCategory)
    )
    return snapshot
  }

  private func uiContentSizeCategory(from swiftUICategory: ContentSizeCategory) -> UIContentSizeCategory {
    switch swiftUICategory {
    case .extraSmall: return .extraSmall
    case .small: return .small
    case .medium: return .medium
    case .large: return .large
    case .extraLarge: return .extraLarge
    case .extraExtraLarge: return .extraExtraLarge
    case .extraExtraExtraLarge: return .extraExtraExtraLarge
    case .accessibilityMedium: return .accessibilityMedium
    case .accessibilityLarge: return .accessibilityLarge
    case .accessibilityExtraLarge: return .accessibilityExtraLarge
    case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
    case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
    @unknown default: return .large
    }
  }
}
