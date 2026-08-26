//
//  InkMarkdownCoordinator.swift
//  InkMarkdownSwiftUI
//

import UIKit
import InkMarkdown

/// `InkMarkdownRepresentable` 的协调器，负责 UIKit 容器、流式文本视图与会话 attachment。
final class InkMarkdownCoordinator {

  weak var containerView: InkMarkdownContainerView?
  private var streamTextView: UITextView?
  private var streamThoughtView: InkThoughtBlockView?
  private weak var currentSession: InkMarkdownRenderSession?

  private var lastRenderedMarkdown: String?
  private var lastRenderedConfiguration: InkConfiguration?

  /// attach 前宿主已注册的 `onDisplayUpdate`；detach 时还原，避免 dismantle 杀死 Chat pulse。
  private var hostDisplayUpdate: (() -> Void)?

  /// 使用当前完整输入和配置生成静态块级视图。
  ///
  /// 仅当 Markdown 源码或渲染配置（外观/环境/扩展）发生语义变化，或容器尚未有渲染块时重新生成；
  /// 避免 SwiftUI 布局和更新传递中无意义的重复解析与 TextKit 对象分配。
  func updateStatic(markdown: String, configuration: InkConfiguration) {
    cleanupStreaming()

    if lastRenderedMarkdown == markdown,
       let lastConfig = lastRenderedConfiguration,
       lastConfig.isSemanticallyEqualTo(configuration),
       containerView?.hasBlocks == true {
      return
    }

    lastRenderedMarkdown = markdown
    lastRenderedConfiguration = configuration

    let blocks = InkBlockRenderer.render(markdown, configuration: configuration)
    containerView?.updateBlocks(blocks, configuration: configuration)
  }

  /// 直接更新已解析块列表（promotion 快照 / Chat 终态，不重新 parse Markdown）。
  func updateBlocks(
    _ blocks: [InkRenderableBlock],
    configuration: InkConfiguration,
    session: InkMarkdownRenderSession? = nil
  ) {
    cleanupStreaming()

    lastRenderedMarkdown = nil
    lastRenderedConfiguration = configuration

    containerView?.updateBlocks(
      blocks,
      configuration: configuration,
      onThoughtCollapseChanged: session.map { sess in
        { index, isCollapsed in sess.setPromotedThoughtCollapsed(at: index, isCollapsed: isCollapsed) }
      }
    )
  }

  /// 驱动流式渲染会话并管理其 `UITextView` attachment。
  func updateStreaming(session: InkMarkdownRenderSession) {
    guard !session.isPromoted else {
      let displayedThoughtCollapsed = currentSession === session ? streamThoughtView?.isCollapsed : nil
      session.syncStreamingThoughtCollapseIntoBlocks(streamViewCollapsed: displayedThoughtCollapsed)
      updateBlocks(session.blocks, configuration: session.configuration, session: session)
      return
    }
    guard let container = containerView else { return }

    let textView = makeOrReuseStreamTextView(in: container)

    if currentSession !== session {
      detachFromCurrentSession()
      currentSession = session
      session.bindTextView(textView)
      chainDisplayUpdate(for: session)
    }

    updateStreamingThoughtView(for: session, in: container)
    container.setNeedsLayout()
    container.invalidateIntrinsicContentSize()
  }

  /// 释放对容器视图及会话的引用并重置内部状态。
  func teardown() {
    cleanupStreaming()
    lastRenderedMarkdown = nil
    lastRenderedConfiguration = nil
    containerView = nil
  }

  // MARK: - Private Helpers

  private func chainDisplayUpdate(for session: InkMarkdownRenderSession) {
    hostDisplayUpdate = session.onDisplayUpdate
    session.onDisplayUpdate = { [weak self] in
      guard let self, let container = self.containerView else { return }
      container.setNeedsLayout()
      container.invalidateIntrinsicContentSize()
      self.hostDisplayUpdate?()
    }
  }

  private func detachFromCurrentSession() {
    guard let session = currentSession else { return }
    session.onDisplayUpdate = hostDisplayUpdate
    hostDisplayUpdate = nil
    session.unbindTextView()
  }

  private func updateStreamingThoughtView(for session: InkMarkdownRenderSession, in container: InkMarkdownContainerView) {
    if let thoughtBlock = session.streamingThought {
      if let existing = streamThoughtView {
        existing.apply(
          thought: thoughtBlock.thought,
          isComplete: thoughtBlock.isComplete,
          isCollapsed: thoughtBlock.isCollapsed,
          config: thoughtBlock.config,
          renderConfiguration: thoughtBlock.renderConfiguration
        )
      } else {
        let view = InkThoughtBlockView(
          thought: thoughtBlock.thought,
          isComplete: thoughtBlock.isComplete,
          config: thoughtBlock.config,
          renderConfiguration: thoughtBlock.renderConfiguration,
          isCollapsed: thoughtBlock.isCollapsed
        )
        view.onToggleCollapse = { [weak session, weak container] collapsed in
          session?.setStreamingThoughtCollapsed(collapsed)
          container?.setNeedsLayout()
          container?.invalidateIntrinsicContentSize()
        }
        streamThoughtView = view
        container.insertSubview(view, at: 0)
      }
    } else {
      streamThoughtView?.removeFromSuperview()
      streamThoughtView = nil
    }
  }

  private func makeOrReuseStreamTextView(in container: InkMarkdownContainerView) -> UITextView {
    let textView: UITextView
    if let existing = streamTextView {
      textView = existing
    } else {
      let newTextView = UITextView()
      newTextView.isEditable = false
      newTextView.isSelectable = true
      newTextView.isScrollEnabled = false
      newTextView.backgroundColor = .clear
      newTextView.textContainerInset = .zero
      newTextView.textContainer.lineFragmentPadding = 0
      streamTextView = newTextView
      textView = newTextView
    }

    if textView.superview !== container {
      container.addSubview(textView)
    }
    return textView
  }

  private func cleanupStreaming() {
    detachFromCurrentSession()
    currentSession = nil
    streamThoughtView?.removeFromSuperview()
    streamThoughtView = nil
    streamTextView?.removeFromSuperview()
    streamTextView = nil
  }
}
