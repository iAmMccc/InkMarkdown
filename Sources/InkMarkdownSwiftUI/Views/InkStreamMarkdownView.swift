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
/// 自动提升为原生块级组件。会话持有从流式到终态共享的唯一 `InkConfiguration` 快照。
///
/// - Important: 本视图不订阅 session 的状态机 `@Published state`，只订阅 `isPromoted`，
///   避免 CADisplayLink / finish 回调触发 SwiftUI 全量 invalidation。
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
    Group {
      if isPromoted {
        InkMarkdownRepresentable(
          mode: .static(markdown: session.currentText),
          configuration: session.configuration
        )
      } else {
        InkMarkdownRepresentable(
          mode: .streaming(session: session),
          configuration: session.configuration
        )
      }
    }
    .onReceive(session.$isPromoted) { isPromoted = $0 }
    .onAppear(perform: updateRenderEnvironment)
    .onChange(of: colorScheme) { _ in
      updateRenderEnvironment()
    }
  }

  private func updateRenderEnvironment() {
    session.updateRenderEnvironment(
      InkRenderEnvironment(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
    )
  }
}
