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
  private weak var currentSession: InkMarkdownRenderSession?

  private var lastRenderedMarkdown: String?
  private var lastRenderedConfiguration: InkConfiguration?

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

  /// 驱动流式渲染会话并管理其 `UITextView` attachment。
  func updateStreaming(session: InkMarkdownRenderSession) {
    guard !session.isPromoted else {
      cleanupStreaming()
      containerView?.updateBlocks(session.blocks, configuration: session.configuration)
      return
    }
    guard let container = containerView else { return }

    let textView = makeOrReuseStreamTextView(in: container)

    if currentSession !== session {
      currentSession?.onDisplayUpdate = nil
      currentSession?.unbindTextView()
      currentSession = session
      session.bindTextView(textView)
      session.onDisplayUpdate = { [weak self, weak container] in
        guard let self, let container else { return }
        self.layoutStreamTextView(in: container)
        container.invalidateIntrinsicContentSize()
        container.setNeedsLayout()
      }
    }

    layoutStreamTextView(in: container)
  }

  /// 释放对容器视图及会话的引用并重置内部状态。
  func teardown() {
    cleanupStreaming()
    lastRenderedMarkdown = nil
    lastRenderedConfiguration = nil
    containerView = nil
  }

  // MARK: - Private Helpers

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

  private func layoutStreamTextView(in container: InkMarkdownContainerView) {
    guard let textView = streamTextView, container.bounds.width > 0 else { return }
    let width = container.bounds.width
    let height = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    textView.frame = CGRect(x: 0, y: 0, width: width, height: height)
  }

  private func cleanupStreaming() {
    currentSession?.onDisplayUpdate = nil
    currentSession?.unbindTextView()
    streamTextView?.removeFromSuperview()
    streamTextView = nil
    currentSession = nil
  }
}
