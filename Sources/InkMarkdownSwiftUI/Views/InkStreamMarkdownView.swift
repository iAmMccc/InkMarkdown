//
//  InkStreamMarkdownView.swift
//  InkMarkdownSwiftUI
//

import Combine
import SwiftUI
import InkMarkdown

/// 流式 Markdown 渲染视图。
///
/// 绑定 `InkMarkdownRenderSession` 流式会话，支持打字机式逐字渲染，并在显示完成后
/// 自动提升为原生块级组件。会话持有从流式到终态共享的唯一 `InkConfiguration` 快照
/// 与思考块折叠态 SSOT；promotion 后仍绑定同一会话，由 Coordinator 在内部切换布局。
///
/// - Important: 本视图始终通过 `.streaming(session:)` 驱动 Representable，不在 body 中
///   切换为无 session 写回的 `.blocks` 模式，以免丢失 `isCollapsed` 等交互状态。
/// - Important: 宿主勿 `@ObservedObject` 整份 session；仅 `isPromoted` 会驱动 SwiftUI 换树。
///
/// ### 使用示例
/// ```swift
/// struct StreamingContentView: View {
///   @StateObject private var session = InkMarkdownRenderSession(configuration: .standard)
///
///   var body: some View {
///     VStack {
///       InkStreamMarkdownView(session: session)
///
///       Button("追加分片") {
///         session.append("## 实时标题\n这是流式内容...")
///       }
///       Button("完成输入") {
///         session.finish()
///       }
///     }
///   }
/// }
/// ```
public struct InkStreamMarkdownView: View {

  private let session: InkMarkdownRenderSession
  @State private var isPromoted: Bool
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.sizeCategory) private var sizeCategory

  /// 创建一个流式 Markdown 渲染视图。
  ///
  /// 配置由 `session` 在创建时确定，以保证流式阶段和终态 Block Promotion 使用同一份
  /// `InkConfiguration`。如需切换业务配置，请创建并绑定新的 render session。
  /// - Parameter session: 驱动流式渲染的会话状态机对象。
  public init(session: InkMarkdownRenderSession) {
    self.session = session
    _isPromoted = State(initialValue: session.isPromoted)
  }

  /// 创建一个流式 Markdown 渲染视图（省略参数名）。
  /// - Parameter session: 驱动流式渲染的会话状态机对象。
  public init(_ session: InkMarkdownRenderSession) {
    self.session = session
    _isPromoted = State(initialValue: session.isPromoted)
  }

  public var body: some View {
    InkMarkdownRepresentable(
      mode: .streaming(session: session),
      configuration: session.configuration,
      promotionGeneration: isPromoted
    )
    .onReceive(session.$isPromoted) { isPromoted = $0 }
    .onAppear(perform: updateRenderEnvironment)
    .onChange(of: colorScheme) { _ in updateRenderEnvironment() }
    .onChange(of: sizeCategory) { _ in updateRenderEnvironment() }
  }

  private func updateRenderEnvironment() {
    session.updateRenderEnvironment(
      InkRenderEnvironment(
        userInterfaceStyle: colorScheme == .dark ? .dark : .light,
        contentSizeCategory: uiContentSizeCategory(from: sizeCategory)
      )
    )
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
