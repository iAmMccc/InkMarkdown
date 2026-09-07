//
//  InkStreamingPresentationHost.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import UIKit

/// 稳定语义身份的默认链接配置解析；静态与流式路径共用，避免每次生成新 identity。
enum InkMarkdownSwiftUILinkConfiguration {
  static let defaultSemanticIdentity = "InkMarkdownSwiftUI.default-link-opening.v1"

  @MainActor
  static func applyingDefaultLinkHandler(to configuration: InkConfiguration) -> InkConfiguration {
    var effective = configuration
    if effective.linkTapHandler == nil {
      effective.setLinkTapHandler(
        { url, _ in
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
          return true
        },
        semanticIdentity: InkSemanticIdentity(defaultSemanticIdentity)
      )
    }
    return effective
  }
}

/// 流式呈现宿主：集中 Session/container 接管、snapshot 应用、环境暂存与有序释放。
///
/// 不拥有 Thought live state / lineage / PublishHopper；continuity.ownsAttachment 是权限真相。
@MainActor
final class InkStreamingPresentationHost {

  private weak var session: InkMarkdownRenderSession?
  private weak var container: InkMarkdownContainerView?
  private var streamTextView: InkStreamingTextView?
  private var boundStreamTextView: UITextView?
  private var attachedContinuity: InkBlockPresentationContinuity?
  private var ownedAttachmentToken: InkBlockPresentationAttachmentToken?
  private var sessionCycleID: InkBlockPresentationCycleID?
  private var bindingGrant: InkSessionPresentationBindingGrant?
  private var pendingRenderEnvironment: InkRenderEnvironment?
  private var isReconciling = false
  private var hostGeneration = UUID()
  private var isReleasing = false

  /// - Returns: 本次是否成功应用呈现（不等于会话结束）。
  @discardableResult
  func update(
    session: InkMarkdownRenderSession,
    container: InkMarkdownContainerView,
    renderEnvironment: InkRenderEnvironment? = nil,
    constrainedWidth: CGFloat? = nil,
    environmentSignature: InkBlockPresentationEnvironmentSignature? = nil
  ) -> Bool {
    isReleasing = false
    let sessionChanged = self.session !== session
    let containerChanged = self.container != nil && self.container !== container
    if sessionChanged || containerChanged {
      if self.session != nil || self.container != nil || self.attachedContinuity != nil || self.ownedAttachmentToken != nil {
        teardownInternal(wakeWaitingOwner: sessionChanged, dismantledContainer: self.container)
      }
      if sessionChanged {
        pendingRenderEnvironment = renderEnvironment
      } else if let renderEnvironment {
        pendingRenderEnvironment = renderEnvironment
      }
    } else if let renderEnvironment {
      pendingRenderEnvironment = renderEnvironment
    }

    self.session = session
    self.container = container

    let presentationCycleChanged = !sessionChanged
      && sessionCycleID != session.presentationCycleID
    if presentationCycleChanged {
      releaseBindingKeepingSession()
      streamTextView = nil
    }
    sessionCycleID = session.presentationCycleID

    if session.requiresStreamingTextAttachment {
      _ = makeOrReuseStreamTextView()
    } else {
      if boundStreamTextView != nil {
        releaseTextViewOnly()
      }
      streamTextView = nil
    }

    installContinuityCallbacks(for: session, on: container)
    return reconcile(
      session: session,
      in: container,
      constrainedWidth: constrainedWidth,
      environmentSignature: environmentSignature
    )
  }

  var isTornDown: Bool {
    session == nil && attachedContinuity == nil && ownedAttachmentToken == nil && container == nil
  }

  var currentHostGeneration: UUID {
    hostGeneration
  }

  /// 幂等释放；旧 host 再次 teardown 不得影响新 owner。
  func teardown(from dismantledContainer: InkMarkdownContainerView? = nil) {
    teardownInternal(wakeWaitingOwner: true, dismantledContainer: dismantledContainer)
  }

  private func teardownInternal(
    wakeWaitingOwner: Bool,
    dismantledContainer: InkMarkdownContainerView?
  ) {
    guard !isReleasing, session != nil || attachedContinuity != nil || ownedAttachmentToken != nil || container != nil else { return }
    isReleasing = true
    hostGeneration = UUID()

    let continuity = attachedContinuity ?? session?.presentationContinuity
    let token = ownedAttachmentToken
    if let continuity,
       continuity.ownsAttachment(token),
       let token,
       let detachPlan = continuity.detach() {
      if let container = dismantledContainer ?? container {
        if !container.apply(detachPlan) {
          continuity.discardAttachment(ownedBy: token)
        }
      } else {
        _ = detachPlan.abort()
        continuity.discardAttachment(ownedBy: token)
      }
    }

    continuity?.removeReconcileObserver(owner: self)
    dismantledContainer?.onContinuityLayoutEnvironmentChanged = nil
    container?.onContinuityLayoutEnvironmentChanged = nil
    releaseBindingKeepingSession()
    session = nil
    attachedContinuity = nil
    sessionCycleID = nil
    ownedAttachmentToken = nil
    streamTextView = nil
    boundStreamTextView = nil
    pendingRenderEnvironment = nil
    container = nil
    isReconciling = false

    if wakeWaitingOwner {
      continuity?.requestReconcileForWaitingOwner(excluding: self)
    }
    isReleasing = false
  }

  @discardableResult
  private func reconcile(
    session: InkMarkdownRenderSession,
    in container: InkMarkdownContainerView,
    constrainedWidth: CGFloat? = nil,
    environmentSignature: InkBlockPresentationEnvironmentSignature? = nil
  ) -> Bool {
    guard !isReconciling,
          !isReleasing,
          self.session === session,
          self.container === container else {
      return false
    }

    isReconciling = true
    defer { isReconciling = false }

    let configuration = InkMarkdownSwiftUILinkConfiguration.applyingDefaultLinkHandler(
      to: session.configuration
    )
    streamTextView?.linkTapHandler = configuration.linkTapHandler

    let candidates = makeCandidates(for: session)
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

    attachedContinuity = session.presentationContinuity
    ownedAttachmentToken = plan.attachmentToken
    installSessionBinding(for: session)
    applyPendingRenderEnvironmentIfOwned(for: session)
    return true
  }

  private func makeCandidates(
    for session: InkMarkdownRenderSession
  ) -> [InkBlockPresentationCandidate] {
    if session.isPromoted {
      var assignedThoughtEvidence = false
      return session.blocks.enumerated().map { index, block in
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
    }

    guard session.requiresStreamingTextAttachment else { return [] }

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
    return streamingCandidates
  }

  private func installSessionBinding(for session: InkMarkdownRenderSession) {
    let observer: () -> Void = { [weak self, weak session] in
      guard let self, let session, let container = self.container else { return }
      guard self.session === session else { return }

      let ownsAttachment: Bool
      if let token = self.ownedAttachmentToken {
        ownsAttachment = session.presentationContinuity.ownsAttachment(token)
      } else {
        ownsAttachment = false
      }
      guard ownsAttachment || self.sessionCycleID != session.presentationCycleID else {
        return
      }
      _ = self.update(session: session, container: container)
    }

    let textView: UITextView? = session.requiresStreamingTextAttachment ? streamTextView : nil
    if let grant = bindingGrant {
      session.updatePresentationBinding(grant, textView: textView, observer: observer)
    } else {
      bindingGrant = session.installPresentationBinding(
        owner: self,
        textView: textView,
        observer: observer
      )
    }

    if let textView {
      boundStreamTextView = textView
    } else {
      boundStreamTextView = nil
      if session.isPromoted {
        streamTextView = nil
      }
    }
  }

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

    let generation = hostGeneration
    let cycleID = session.presentationCycleID
    DispatchQueue.main.async { [weak self, weak session] in
      guard let self, let session,
            self.hostGeneration == generation,
            self.session === session,
            self.sessionCycleID == cycleID,
            let container = self.container,
            self.attachedContinuity === session.presentationContinuity,
            let token = self.ownedAttachmentToken,
            session.presentationContinuity.ownsAttachment(token) else { return }
      _ = self.update(session: session, container: container)
    }
  }

  private func installContinuityCallbacks(
    for session: InkMarkdownRenderSession,
    on container: InkMarkdownContainerView
  ) {
    session.presentationContinuity.installReconcileObserver(owner: self) { [weak self, weak session] in
      guard let self, let session, let container = self.container,
            self.session === session else { return }
      if self.reconcile(session: session, in: container) {
        session.notifyHostPresentationSizeChanged()
      }
    }
    container.onContinuityLayoutEnvironmentChanged = { [weak self, weak session] width, signature in
      guard let self, let session, let container = self.container,
            self.session === session else { return false }
      return self.reconcile(
        session: session,
        in: container,
        constrainedWidth: width,
        environmentSignature: signature
      )
    }
  }

  private func releaseBindingKeepingSession() {
    if let grant = bindingGrant, let session {
      session.releasePresentationBinding(grant)
    }
    bindingGrant = nil
    boundStreamTextView = nil
  }

  private func releaseTextViewOnly() {
    if let grant = bindingGrant, let session {
      session.unbindTextView(for: grant)
    }
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
          let session,
          attachedContinuity === session.presentationContinuity,
          let ownedAttachmentToken,
          session.presentationContinuity.ownsAttachment(ownedAttachmentToken) else {
      return
    }
    session.renderer.refreshImageAttachments()
  }
}
