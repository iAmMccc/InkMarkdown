//
//  InkMarkdownRepresentable.swift
//  InkMarkdownSwiftUI
//
//  Created by InkMarkdown on 2026/8/18.
//

import SwiftUI
import InkMarkdown

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
    var effectiveConfig = configuration
    // 在 SwiftUI 环境中，若未设置自定义 linkTapHandler，提供安全的默认跳转逻辑，
    // 避免底层 UITextView 在 UIHostingController 中触发原生预览而造成 AttributeGraph 依赖循环。
    if effectiveConfig.linkTapHandler == nil {
      effectiveConfig.linkTapHandler = { url, _ in
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
      }
    }

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
    coordinator.teardown()
  }
}
