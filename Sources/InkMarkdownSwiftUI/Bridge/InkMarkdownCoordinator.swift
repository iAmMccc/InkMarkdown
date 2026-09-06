//
//  InkMarkdownCoordinator.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import UIKit

/// `InkMarkdownRepresentable` 的协调器，负责 UIKit 容器、流式文本视图与会话 attachment。
@MainActor
final class InkMarkdownCoordinator {

  private enum StaticInput {
    case markdown(String)
    case blocks([InkRenderableBlock])
  }

  private let staticContinuity = InkBlockPresentationContinuity()
  private var attachedContinuity: InkBlockPresentationContinuity?
  private var ownedAttachmentToken: InkBlockPresentationAttachmentToken?

  weak var containerView: InkMarkdownContainerView?
  private var streamTextView: InkStreamingTextView?
  private weak var boundStreamTextView: UITextView?
  private weak var currentSession: InkMarkdownRenderSession?
  private var currentSessionCycleID: InkBlockPresentationCycleID?

  private var lastRenderedMarkdown: String?
  private var lastRenderedConfiguration: InkConfiguration?
  private var lastRenderedWidth: CGFloat?
  private var lastRenderedEnvironmentSignature: InkBlockPresentationEnvironmentSignature?
  private var hasRenderedStaticPresentation = false
  private var latestStaticInput: StaticInput?
  private var latestStaticConfiguration: InkConfiguration?
  /// SwiftUI environment observed before this coordinator owns an attachment.
  /// Waiting hosts may stage a value, but only a committed attachment may apply it.
  private var pendingRenderEnvironment: InkRenderEnvironment?
  private var isReconcilingStatic = false
  private var isReconcilingStreaming = false

  private lazy var defaultLinkTapHandler: @MainActor @Sendable (URL, UIView) -> Bool = { url, _ in
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    return true
  }

  func resolvedConfiguration(_ configuration: InkConfiguration) -> InkConfiguration {
    var effective = configuration
    if effective.linkTapHandler == nil {
      effective.setLinkTapHandler(
        defaultLinkTapHandler,
        semanticIdentity: "InkMarkdownSwiftUI.default-link-opening.v1"
      )
    }
    return effective
  }

  func updateStatic(markdown: String, configuration: InkConfiguration) {
    pendingRenderEnvironment = nil
    let effective = resolvedConfiguration(configuration)
    guard let container = containerView else { return }
    guard attach(staticContinuity, session: nil, to: container) else { return }
    installStaticContinuityCallbacks(on: container)
    latestStaticInput = .markdown(markdown)
    latestStaticConfiguration = effective

    let width = container.effectiveMeasureWidth
    let environmentSignature = container.resolvedEnvironmentSignature(for: effective)
    if lastRenderedMarkdown == markdown,
       let lastConfig = lastRenderedConfiguration,
       lastConfig.isSemanticallyEqualTo(effective),
       lastRenderedWidth.map({ abs($0 - width) <= 0.1 }) == true,
       lastRenderedEnvironmentSignature == environmentSignature,
       hasRenderedStaticPresentation {
      return
    }

    _ = reconcileLatestStaticPresentation(
      constrainedWidth: width,
      environmentSignature: environmentSignature
    )
  }

  func updateBlocks(
    _ blocks: [InkRenderableBlock],
    configuration: InkConfiguration
  ) {
    pendingRenderEnvironment = nil
    let effective = resolvedConfiguration(configuration)
    guard let container = containerView else { return }
    guard attach(staticContinuity, session: nil, to: container) else { return }
    installStaticContinuityCallbacks(on: container)
    latestStaticInput = .blocks(blocks)
    latestStaticConfiguration = effective
    _ = reconcileLatestStaticPresentation(
      constrainedWidth: container.effectiveMeasureWidth,
      environmentSignature: container.resolvedEnvironmentSignature(for: effective)
    )
  }

  func updateStreaming(
    session: InkMarkdownRenderSession,
    renderEnvironment: InkRenderEnvironment? = nil
  ) {
    let sessionChanged = currentSession !== session
    if sessionChanged {
      // A new session must not inherit a staged environment from the previous one.
      pendingRenderEnvironment = renderEnvironment
    } else if let renderEnvironment {
      pendingRenderEnvironment = renderEnvironment
    }

    clearStaticContinuityCallbacks()
    let wasShowingStaticPresentation = hasRenderedStaticPresentation
    if wasShowingStaticPresentation {
      hasRenderedStaticPresentation = false
    }
    latestStaticInput = nil
    latestStaticConfiguration = nil
    guard let container = containerView else { return }
    let presentationCycleChanged = !sessionChanged
      && currentSessionCycleID != session.presentationCycleID
    guard attach(session.presentationContinuity, session: session, to: container) else { return }
    if presentationCycleChanged {
      session.unbindTextView(owner: self)
      streamTextView = nil
    }
    currentSessionCycleID = session.presentationCycleID
    if wasShowingStaticPresentation {
      staticContinuity.endCycle()
    }

    if session.requiresStreamingTextAttachment {
      _ = makeOrReuseStreamTextView()
    } else {
      if boundStreamTextView != nil {
        session.unbindTextView(owner: self)
        boundStreamTextView = nil
      }
      streamTextView = nil
    }

    installStreamingContinuityCallbacks(for: session, on: container)
    _ = reconcileStreamingPresentation(session: session, in: container)
  }

  func teardown(from dismantledContainer: InkMarkdownContainerView? = nil) {
    let continuityToRelease = attachedContinuity
    if let continuity = continuityToRelease,
       continuity.ownsAttachment(ownedAttachmentToken),
       let ownedAttachmentToken,
       let detachPlan = continuity.detach() {
      if let container = dismantledContainer ?? containerView {
        if !container.apply(detachPlan) {
          continuity.discardAttachment(ownedBy: ownedAttachmentToken)
        }
      } else {
        _ = detachPlan.abort()
        continuity.discardAttachment(ownedBy: ownedAttachmentToken)
      }
    }
    continuityToRelease?.removeReconcileObserver(owner: self)
    containerView?.onContinuityLayoutEnvironmentChanged = nil
    detachFromCurrentSession()
    currentSession = nil
    currentSessionCycleID = nil
    attachedContinuity = nil
    ownedAttachmentToken = nil
    streamTextView = nil
    boundStreamTextView = nil
    staticContinuity.endCycle()
    lastRenderedMarkdown = nil
    lastRenderedConfiguration = nil
    lastRenderedWidth = nil
    lastRenderedEnvironmentSignature = nil
    hasRenderedStaticPresentation = false
    latestStaticInput = nil
    latestStaticConfiguration = nil
    pendingRenderEnvironment = nil
    containerView = nil

    // Remove the old session observer before synchronously waking a waiting owner.
    // Its first environment apply may flush an update immediately; the dismantled
    // coordinator must not re-enter presentation reconciliation during teardown.
    continuityToRelease?.requestReconcileForWaitingOwner(excluding: self)
  }

  // MARK: - Private Helpers

  private func installStaticContinuityCallbacks(on container: InkMarkdownContainerView) {
    container.onContinuityLayoutEnvironmentChanged = { [weak self] width, signature in
      self?.reconcileLatestStaticPresentation(
        constrainedWidth: width,
        environmentSignature: signature
      ) ?? false
    }
    staticContinuity.installReconcileObserver(owner: self) { [weak self] in
      _ = self?.reconcileLatestStaticPresentation()
    }
  }

  private func clearStaticContinuityCallbacks() {
    containerView?.onContinuityLayoutEnvironmentChanged = nil
    staticContinuity.removeReconcileObserver(owner: self)
  }

  @discardableResult
  private func attach(
    _ continuity: InkBlockPresentationContinuity,
    session: InkMarkdownRenderSession?,
    to container: InkMarkdownContainerView
  ) -> Bool {
    if attachedContinuity !== continuity {
      if let currentContinuity = attachedContinuity,
         currentContinuity.ownsAttachment(ownedAttachmentToken),
         let detachPlan = currentContinuity.detach() {
        guard container.apply(detachPlan) else { return false }
      }
      attachedContinuity?.removeReconcileObserver(owner: self)
      attachedContinuity?.requestReconcileForWaitingOwner(excluding: self)
      attachedContinuity = continuity
      ownedAttachmentToken = nil
    }

    if currentSession !== session {
      detachFromCurrentSession()
      currentSession = session
      currentSessionCycleID = session?.presentationCycleID
      streamTextView = nil
      boundStreamTextView = nil
    }
    return true
  }

  private func installStreamingContinuityCallbacks(
    for session: InkMarkdownRenderSession,
    on container: InkMarkdownContainerView
  ) {
    session.presentationContinuity.installReconcileObserver(owner: self) { [weak self, weak session] in
      guard let self, let session, let container = self.containerView,
            self.currentSession === session else { return }
      if self.reconcileStreamingPresentation(session: session, in: container) {
        session.notifyHostPresentationSizeChanged()
      }
    }
    container.onContinuityLayoutEnvironmentChanged = { [weak self, weak session] width, signature in
      guard let self, let session, let container = self.containerView,
            self.currentSession === session else { return false }
      return self.reconcileStreamingPresentation(
        session: session,
        in: container,
        constrainedWidth: width,
        environmentSignature: signature
      )
    }
  }

  @discardableResult
  private func reconcileStreamingPresentation(
    session: InkMarkdownRenderSession,
    in container: InkMarkdownContainerView,
    constrainedWidth: CGFloat? = nil,
    environmentSignature: InkBlockPresentationEnvironmentSignature? = nil
  ) -> Bool {
    guard !isReconcilingStreaming,
          currentSession === session,
          attachedContinuity === session.presentationContinuity else {
      return false
    }

    isReconcilingStreaming = true
    defer { isReconcilingStreaming = false }

    let configuration = resolvedConfiguration(session.configuration)
    // 流式未 finish 阶段与终态块使用同一 `linkTapHandler` 契约：每次 reconcile 用当前
    // configuration 的 handler 覆写，保证 promotion 前后与 configuration 更新后不留陈旧 callback。
    streamTextView?.linkTapHandler = configuration.linkTapHandler
    let candidates: [InkBlockPresentationCandidate]
    if session.isPromoted {
      var assignedThoughtEvidence = false
      candidates = session.blocks.enumerated().map { index, block in
        let evidence: InkBlockPresentationPromotionLineageEvidence?
        if !assignedThoughtEvidence, block is InkThoughtBlock {
          assignedThoughtEvidence = true
          evidence = session.thoughtPromotionEvidence
        } else {
          evidence = nil
        }
        return InkBlockPresentationCandidate(
          block: block,
          structuralSlot: index,
          promotionLineageEvidence: evidence
        )
      }
    } else if session.requiresStreamingTextAttachment {
      var streamingCandidates: [InkBlockPresentationCandidate] = []
      if let thought = session.streamingThought {
        streamingCandidates.append(
          InkBlockPresentationCandidate(
            block: thought,
            structuralSlot: 0,
            promotionLineageEvidence: session.thoughtPromotionEvidence
          )
        )
      }
      if let textView = streamTextView {
        streamingCandidates.append(
          InkBlockPresentationCandidate(
            block: InkStreamingRemainderBlock(
              textView: textView,
              contentRevision: session.streamTextPresentationRevision
            ),
            structuralSlot: 1,
            stableIdentity: session.streamRemainderStableIdentity
          )
        )
      }
      candidates = streamingCandidates
    } else {
      candidates = []
    }

    let width = constrainedWidth ?? container.effectiveMeasureWidth
    let signature = environmentSignature
      ?? container.resolvedEnvironmentSignature(for: configuration)
    let plan = session.presentationContinuity.reconcile(
      InkBlockPresentationSnapshot(
        cycleID: session.presentationCycleID,
        candidates: candidates,
        configuration: configuration,
        constrainedWidth: width,
        environmentSignature: signature
      )
    )
    guard container.apply(plan) else { return false }
    ownedAttachmentToken = plan.attachmentToken
    applyPendingRenderEnvironmentIfOwned(for: session)
    installDisplayUpdateObserver(for: session)

    if session.requiresStreamingTextAttachment, let textView = streamTextView {
      if boundStreamTextView !== textView {
        session.bindTextView(textView, owner: self)
        boundStreamTextView = textView
      }
    } else if boundStreamTextView != nil {
      session.unbindTextView(owner: self)
      boundStreamTextView = nil
    }
    if session.isPromoted {
      streamTextView = nil
    }

    lastRenderedMarkdown = nil
    lastRenderedConfiguration = configuration
    lastRenderedWidth = width
    lastRenderedEnvironmentSignature = signature
    return true
  }

  @discardableResult
  private func reconcileLatestStaticPresentation(
    constrainedWidth: CGFloat? = nil,
    environmentSignature: InkBlockPresentationEnvironmentSignature? = nil
  ) -> Bool {
    guard !isReconcilingStatic,
          let container = containerView,
          let input = latestStaticInput,
          let configuration = latestStaticConfiguration else {
      return false
    }

    isReconcilingStatic = true
    defer { isReconcilingStatic = false }

    let blocks: [InkRenderableBlock]
    let markdown: String?
    switch input {
    case .markdown(let source):
      markdown = source
      blocks = InkBlockRenderer.render(source, configuration: configuration)
    case .blocks(let suppliedBlocks):
      markdown = nil
      blocks = suppliedBlocks
    }

    let width = constrainedWidth ?? container.effectiveMeasureWidth
    let signature = environmentSignature
      ?? container.resolvedEnvironmentSignature(for: configuration)
    let snapshot = InkBlockPresentationSnapshot(
      cycleID: staticContinuity.cycleID,
      candidates: InkBlockPresentationCandidate.staticBlocks(blocks),
      configuration: configuration,
      constrainedWidth: width,
      environmentSignature: signature
    )
    let plan = staticContinuity.reconcile(snapshot)
    guard container.apply(plan) else { return false }
    ownedAttachmentToken = plan.attachmentToken

    lastRenderedMarkdown = markdown
    lastRenderedConfiguration = configuration
    lastRenderedWidth = width
    lastRenderedEnvironmentSignature = signature
    hasRenderedStaticPresentation = true
    return true
  }

  private func installDisplayUpdateObserver(for session: InkMarkdownRenderSession) {
    session.installPresentationDisplayUpdateObserver(owner: self) { [weak self, weak session] in
      guard let self, let session, self.containerView != nil else { return }
      guard let streamingSession = self.currentSession,
            streamingSession === session else { return }

      // cancel/reset invalidates the old continuity token before notifying the
      // current owner; the changed cycle is the legitimate path that removes
      // stale Thought/remainder views from the still-mounted container.
      let ownsAttachment: Bool
      if let ownedAttachmentToken = self.ownedAttachmentToken {
        ownsAttachment = session.presentationContinuity.ownsAttachment(ownedAttachmentToken)
      } else {
        ownsAttachment = false
      }
      guard ownsAttachment || self.currentSessionCycleID != session.presentationCycleID else {
        return
      }
      self.updateStreaming(session: streamingSession)
    }
  }

  /// Apply SwiftUI's staged trait snapshot only after this coordinator's UIKit
  /// attachment plan has committed. A waiting or abandoned host cannot mutate
  /// the session environment owned by another host.
  private func applyPendingRenderEnvironmentIfOwned(for session: InkMarkdownRenderSession) {
    guard let pendingRenderEnvironment,
          attachedContinuity === session.presentationContinuity,
          let ownedAttachmentToken,
          session.presentationContinuity.ownsAttachment(ownedAttachmentToken) else {
      return
    }

    self.pendingRenderEnvironment = nil
    guard session.configuration.renderEnvironment != pendingRenderEnvironment else { return }

    session.updateRenderEnvironment(pendingRenderEnvironment)

    // updateRenderEnvironment notifies the current observer synchronously. When
    // called from reconcile, that callback is guarded by isReconcilingStreaming;
    // schedule one follow-up pass after the plan returns.
    DispatchQueue.main.async { [weak self, weak session] in
      guard let self, let session,
            self.currentSession === session,
            self.containerView != nil,
            self.attachedContinuity === session.presentationContinuity,
            let ownedAttachmentToken = self.ownedAttachmentToken,
            session.presentationContinuity.ownsAttachment(ownedAttachmentToken) else { return }
      self.updateStreaming(session: session)
    }
  }

  private func detachFromCurrentSession() {
    guard let session = currentSession else { return }
    session.removePresentationDisplayUpdateObserver(owner: self)
    session.unbindTextView(owner: self)
    boundStreamTextView = nil
  }

  private func makeOrReuseStreamTextView() -> InkStreamingTextView {
    let textView: InkStreamingTextView
    if let existing = streamTextView {
      textView = existing
    } else {
      let created = InkStreamingTextView()
      streamTextView = created
      textView = created
    }

    textView.onDisplayContextChange = { [weak self, weak textView] in
      guard let self, let textView else { return }
      self.refreshStreamingImageAttachments(for: textView)
    }

    return textView
  }

  private func refreshStreamingImageAttachments(for textView: InkStreamingTextView) {
    guard boundStreamTextView === textView,
          let session = currentSession,
          attachedContinuity === session.presentationContinuity,
          let ownedAttachmentToken,
          session.presentationContinuity.ownsAttachment(ownedAttachmentToken) else {
      return
    }

    // InkStreamRenderer delegates width/scale resolution to the shared
    // InkImageAttachment text-view helper, so every host uses the same display
    // context and rebinding semantics.
    session.renderer.refreshImageAttachments()
  }

}
