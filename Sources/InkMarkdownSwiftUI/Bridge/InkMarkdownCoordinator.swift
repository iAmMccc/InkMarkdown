//
//  InkMarkdownCoordinator.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import UIKit

/// `InkMarkdownRepresentable` 的协调器，负责 UIKit 容器、流式文本视图与会话 attachment。
@MainActor
final class InkMarkdownCoordinator {

  weak var containerView: InkMarkdownContainerView?
  private var streamTextView: UITextView?
  private var streamThoughtView: InkThoughtBlockView?
  private weak var currentSession: InkMarkdownRenderSession?

  private var lastRenderedMarkdown: String?
  private var lastRenderedConfiguration: InkConfiguration?
  private var lastContentSizeCategory: UIContentSizeCategory?
  private var lastDocumentEpoch: UInt64?

  private var hostDisplayUpdate: (() -> Void)?

  private lazy var defaultLinkTapHandler: @MainActor @Sendable (URL, UIView) -> Bool = { url, _ in
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }

  func resolvedConfiguration(_ configuration: InkConfiguration) -> InkConfiguration {
    var effective = configuration
    if effective.linkTapHandler == nil {
      effective.linkTapHandler = defaultLinkTapHandler
    }
    return effective
  }

  func updateStatic(markdown: String, configuration: InkConfiguration) {
    cleanupStreamingAttachments()

    let effective = resolvedConfiguration(configuration)
    let currentCategory = effective.renderEnvironment.contentSizeCategory != .unspecified
      ? effective.renderEnvironment.contentSizeCategory
      : UITraitCollection.current.preferredContentSizeCategory
    let epoch = InkDocumentEpoch.hash(markdown)

    if lastRenderedMarkdown == markdown,
       let lastConfig = lastRenderedConfiguration,
       lastConfig.isSemanticallyEqualTo(effective),
       lastContentSizeCategory == currentCategory,
       lastDocumentEpoch == epoch,
       containerView?.hasBlocks == true {
      return
    }

    lastRenderedMarkdown = markdown
    lastRenderedConfiguration = effective
    lastContentSizeCategory = currentCategory
    lastDocumentEpoch = epoch

    let blocks = InkBlockRenderer.render(markdown, configuration: effective)
    containerView?.updateBlocks(blocks, configuration: effective, documentEpoch: epoch)
  }

  func updateBlocks(
    _ blocks: [InkRenderableBlock],
    configuration: InkConfiguration,
    session: InkMarkdownRenderSession? = nil,
    documentEpoch: UInt64? = nil
  ) {
    cleanupStreamingAttachments()

    let effective = resolvedConfiguration(configuration)
    lastRenderedMarkdown = nil
    lastRenderedConfiguration = effective
    lastDocumentEpoch = documentEpoch

    containerView?.updateBlocks(
      blocks,
      configuration: effective,
      documentEpoch: documentEpoch ?? session?.documentEpoch ?? 0,
      onThoughtCollapseChanged: session.map { sess in
        { index, isCollapsed in sess.setPromotedThoughtCollapsed(at: index, isCollapsed: isCollapsed) }
      }
    )
  }

  func updateStreaming(session: InkMarkdownRenderSession) {
    if session.isPromoted {
      let displayedThoughtCollapsed = currentSession === session ? streamThoughtView?.isCollapsed : nil
      session.syncStreamingThoughtCollapseIntoBlocks(streamViewCollapsed: displayedThoughtCollapsed)
      cleanupStreamingAttachments()

      if let thoughtView = streamThoughtView,
         let thoughtBlock = session.blocks.first(where: { $0 is InkThoughtBlock }) as? InkThoughtBlock,
         let identity = thoughtBlock.blockIdentity,
         let container = containerView {
        container.preRegisterView(thoughtView, for: identity)
      }

      updateBlocks(
        session.blocks,
        configuration: session.configuration,
        session: session,
        documentEpoch: session.documentEpoch
      )
      streamThoughtView = nil
      return
    }

    guard let container = containerView else { return }

    let textView = makeOrReuseStreamTextView(in: container)

    if currentSession !== session {
      detachFromCurrentSession()
      container.invalidateAllMeasurementSlots()
      currentSession = session
      session.bindTextView(textView)
      chainDisplayUpdate(for: session)
    }

    applyStreamingThoughtView(for: session, in: container)
    syncStreamingAttachments(for: session)
    syncStreamTextContainerWidth(in: container)
    syncStreamingReservedHeights(for: session, in: container)
    container.setNeedsLayout()
  }

  func teardown() {
    cleanupStreamingAttachments()
    lastRenderedMarkdown = nil
    lastRenderedConfiguration = nil
    lastDocumentEpoch = nil
    containerView = nil
  }

  // MARK: - Private Helpers

  private func chainDisplayUpdate(for session: InkMarkdownRenderSession) {
    hostDisplayUpdate = session.onDisplayUpdate
    session.onDisplayUpdate = { [weak self] in
      guard let self, let container = self.containerView else { return }

      guard let streamingSession = self.currentSession else {
        self.hostDisplayUpdate?()
        return
      }

      switch streamingSession.lastDisplayUpdateTarget {
      case .streamingThought:
        if streamingSession.streamingThought != nil {
          self.applyStreamingThoughtView(for: streamingSession, in: container)
          if let thoughtView = self.streamThoughtView,
             let identity = streamingSession.streamingThought?.blockIdentity {
            container.updateReservedHeightSlot(identity: identity, view: thoughtView)
          }
        }
      case .streamText:
        if let textView = self.streamTextView {
          self.syncStreamTextContainerWidth(in: container)
          let identity = self.streamTextIdentity(for: streamingSession)
          container.updateReservedHeightSlot(identity: identity, view: textView)
        }
      }

      self.hostDisplayUpdate?()
    }
  }

  private func detachFromCurrentSession() {
    guard let session = currentSession else { return }
    session.onDisplayUpdate = hostDisplayUpdate
    hostDisplayUpdate = nil
    session.unbindTextView()
  }

  private func applyStreamingThoughtView(for session: InkMarkdownRenderSession, in container: InkMarkdownContainerView) {
    guard let thoughtBlock = session.streamingThought else {
      if streamThoughtView != nil {
        streamThoughtView?.removeFromSuperview()
        streamThoughtView = nil
      }
      return
    }

    guard let identity = thoughtBlock.blockIdentity else { return }

    if let existing = streamThoughtView {
      thoughtBlock.updateExistingView(existing)
    } else {
      let view = thoughtBlock.makeView() as! InkThoughtBlockView
      view.onToggleCollapse = { [weak session, weak container, weak view] collapsed in
        session?.setStreamingThoughtCollapsed(collapsed)
        guard let container, let view, let identity = session?.streamingThought?.blockIdentity else { return }
        container.updateReservedHeightSlot(identity: identity, view: view)
      }
      view.onReservedHeightChanged = { [weak session, weak container, weak view] in
        guard let container, let view, let identity = session?.streamingThought?.blockIdentity else { return }
        container.updateReservedHeightSlot(identity: identity, view: view)
      }
      streamThoughtView = view
      container.preRegisterView(view, for: identity)
      container.insertSubview(view, at: 0)
    }
  }

  private func syncStreamingAttachments(for session: InkMarkdownRenderSession) {
    guard let container = containerView else { return }

    var thoughtPair: (InkBlockIdentity, UIView)?
    if let thought = session.streamingThought, let view = streamThoughtView, let identity = thought.blockIdentity {
      thoughtPair = (identity, view)
    }

    var textPair: (InkBlockIdentity, UIView)?
    if let textView = streamTextView {
      textPair = (streamTextIdentity(for: session), textView)
    }

    container.configureStreamingAttachments(
      thought: thoughtPair.map { ($0.0, $0.1) },
      text: textPair.map { ($0.0, $0.1) }
    )
  }

  private func streamTextIdentity(for session: InkMarkdownRenderSession) -> InkBlockIdentity {
    InkBlockIdentity(
      documentEpoch: session.streamingSlotEpoch,
      blockIndex: -1,
      kind: InkStreamingSlotKind.streamText
    )
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
      newTextView.adjustsFontForContentSizeCategory = true
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

  private func syncStreamTextContainerWidth(in container: InkMarkdownContainerView) {
    guard let textView = streamTextView else { return }
    let width = container.effectiveMeasureWidth
    guard width > 0 else { return }
    textView.textContainer.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
  }

  private func syncStreamingReservedHeights(
    for session: InkMarkdownRenderSession,
    in container: InkMarkdownContainerView
  ) {
    guard session.state == .streaming, container.effectiveMeasureWidth > 0 else { return }
    if let thought = session.streamingThought,
       let view = streamThoughtView,
       let identity = thought.blockIdentity {
      container.updateReservedHeightSlot(identity: identity, view: view)
    }
    if let textView = streamTextView {
      container.updateReservedHeightSlot(
        identity: streamTextIdentity(for: session),
        view: textView
      )
    }
  }

  private func cleanupStreamingAttachments() {
    detachFromCurrentSession()
    currentSession = nil
    streamTextView?.removeFromSuperview()
    streamTextView = nil
    containerView?.clearStreamingAttachments()
  }
}
