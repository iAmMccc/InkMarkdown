//
//  InkMarkdownCoordinator.swift
//  InkMarkdownSwiftUI
//

@_spi(InkMarkdown) import InkMarkdown
import UIKit

/// `InkMarkdownRepresentable` 的协调器，负责 UIKit 容器与呈现模式切换。
///
/// 流式接管顺序由 ``InkStreamingPresentationHost`` 拥有；本类型保留静态/blocks 路径
/// 与模式切换入口。
@MainActor
final class InkMarkdownCoordinator {

  private enum StaticInput {
    case markdown(String)
    case blocks([InkRenderableBlock])
  }

  private let staticContinuity = InkBlockPresentationContinuity()
  private var attachedStaticContinuity = false
  private var ownedStaticAttachmentToken: InkBlockPresentationAttachmentToken?

  weak var containerView: InkMarkdownContainerView?
  private let streamingHost = InkStreamingPresentationHost()

  private var lastRenderedMarkdown: String?
  private var lastRenderedConfiguration: InkConfiguration?
  private var lastRenderedWidth: CGFloat?
  private var lastRenderedEnvironmentSignature: InkBlockPresentationEnvironmentSignature?
  private var hasRenderedStaticPresentation = false
  private var latestStaticInput: StaticInput?
  private var latestStaticConfiguration: InkConfiguration?
  private var isReconcilingStatic = false

  func resolvedConfiguration(_ configuration: InkConfiguration) -> InkConfiguration {
    InkMarkdownSwiftUILinkConfiguration.applyingDefaultLinkHandler(to: configuration)
  }

  func updateStatic(markdown: String, configuration: InkConfiguration) {
    releaseStreamingHostForStaticSwitch()
    let effective = resolvedConfiguration(configuration)
    guard let container = containerView else { return }
    guard attachStatic(to: container) else { return }
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
    releaseStreamingHostForStaticSwitch()
    let effective = resolvedConfiguration(configuration)
    guard let container = containerView else { return }
    guard attachStatic(to: container) else { return }
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
    clearStaticContinuityCallbacks()
    let wasShowingStaticPresentation = hasRenderedStaticPresentation
    if wasShowingStaticPresentation {
      hasRenderedStaticPresentation = false
    }
    latestStaticInput = nil
    latestStaticConfiguration = nil
    guard let container = containerView else { return }

    if attachedStaticContinuity {
      detachStatic(from: container)
    }
    if wasShowingStaticPresentation {
      staticContinuity.endCycle()
    }

    _ = streamingHost.update(
      session: session,
      container: container,
      renderEnvironment: renderEnvironment
    )
  }

  func teardown(from dismantledContainer: InkMarkdownContainerView? = nil) {
    streamingHost.teardown(from: dismantledContainer)

    let container = dismantledContainer ?? containerView
    if attachedStaticContinuity {
      detachStatic(from: container)
    }
    clearStaticContinuityCallbacks()
    dismantledContainer?.onContinuityHeightChanged = nil
    staticContinuity.endCycle()
    lastRenderedMarkdown = nil
    lastRenderedConfiguration = nil
    lastRenderedWidth = nil
    lastRenderedEnvironmentSignature = nil
    hasRenderedStaticPresentation = false
    latestStaticInput = nil
    latestStaticConfiguration = nil
    containerView = nil
  }

  // MARK: - Static Helpers

  private func releaseStreamingHostForStaticSwitch() {
    streamingHost.teardown(from: containerView)
  }

  private func installStaticContinuityCallbacks(on container: InkMarkdownContainerView) {
    container.onContinuityLayoutEnvironmentChanged = { [weak self] width, signature in
      self?.reconcileLatestStaticPresentation(
        constrainedWidth: width,
        environmentSignature: signature
      ) ?? false
    }
    container.onContinuityHeightChanged = { [weak container] in
      container?.invalidateIntrinsicContentSize()
      container?.superview?.setNeedsLayout()
    }
    staticContinuity.installReconcileObserver(owner: self) { [weak self] in
      _ = self?.reconcileLatestStaticPresentation()
    }
  }

  private func clearStaticContinuityCallbacks() {
    containerView?.onContinuityLayoutEnvironmentChanged = nil
    containerView?.onContinuityHeightChanged = nil
    staticContinuity.removeReconcileObserver(owner: self)
  }

  @discardableResult
  private func attachStatic(to container: InkMarkdownContainerView) -> Bool {
    if !attachedStaticContinuity {
      attachedStaticContinuity = true
      ownedStaticAttachmentToken = nil
    }
    return true
  }

  private func detachStatic(from container: InkMarkdownContainerView?) {
    if attachedStaticContinuity,
       staticContinuity.ownsAttachment(ownedStaticAttachmentToken),
       let token = ownedStaticAttachmentToken,
       let detachPlan = staticContinuity.detach() {
      if let container {
        if !container.apply(detachPlan) {
          staticContinuity.discardAttachment(ownedBy: token)
        }
      } else {
        _ = detachPlan.abort()
        staticContinuity.discardAttachment(ownedBy: token)
      }
    }
    staticContinuity.removeReconcileObserver(owner: self)
    attachedStaticContinuity = false
    ownedStaticAttachmentToken = nil
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

    let blocks: [any InkRenderableBlock]
    switch input {
    case .markdown(let markdown):
      blocks = InkBlockRenderer.render(markdown, configuration: configuration)
    case .blocks(let value):
      blocks = value
    }

    let width = constrainedWidth ?? container.effectiveMeasureWidth
    let signature = environmentSignature
      ?? container.resolvedEnvironmentSignature(for: configuration)
    let snapshot = InkBlockPresentationSnapshot(
      cycleID: staticContinuity.cycleID,
      candidates: blocks.enumerated().map { index, block in
        InkBlockPresentationCandidate(block: block, structuralSlot: index)
      },
      configuration: configuration,
      constrainedWidth: width,
      environmentSignature: signature
    )
    let plan = staticContinuity.reconcile(snapshot)
    guard container.apply(plan) else { return false }

    ownedStaticAttachmentToken = plan.attachmentToken
    lastRenderedMarkdown = {
      if case .markdown(let markdown) = input { return markdown }
      return nil
    }()
    lastRenderedConfiguration = configuration
    lastRenderedWidth = width
    lastRenderedEnvironmentSignature = signature
    hasRenderedStaticPresentation = true
    return true
  }
}
