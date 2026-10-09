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

  /// 内容事件生成语义块；布局和交互只消费这份呈现输入。
  private struct StaticPresentation {
    let markdown: String?
    let blocks: [InkRenderableBlock]
    let configuration: InkConfiguration
  }

  private let staticContinuity = InkBlockPresentationContinuity()
  private var ownedStaticAttachmentToken: InkBlockPresentationAttachmentToken?

  weak var containerView: InkMarkdownContainerView?
  private let streamingHost = InkStreamingPresentationHost()

  private var staticPresentation: StaticPresentation?
  private var appliedLayout: (width: CGFloat, signature: InkBlockPresentationEnvironmentSignature)?
  private var isReconcilingStatic = false

  func resolvedConfiguration(_ configuration: InkConfiguration) -> InkConfiguration {
    InkMarkdownSwiftUILinkConfiguration.applyingDefaultLinkHandler(to: configuration)
  }

  func updateStatic(markdown: String, configuration: InkConfiguration) {
    streamingHost.teardown(from: containerView)
    let effective = resolvedConfiguration(configuration)
    guard let container = containerView else { return }
    installStaticContinuityCallbacks(on: container)
    let width = container.effectiveMeasureWidth
    let environmentSignature = container.resolvedEnvironmentSignature(for: effective)
    if let presentation = staticPresentation,
       presentation.markdown == markdown,
       presentation.configuration.isSemanticallyEqualTo(effective) {
      if let layout = appliedLayout,
         abs(layout.width - width) <= 0.1,
         layout.signature == environmentSignature {
        return
      }
    } else {
      staticPresentation = StaticPresentation(
        markdown: markdown,
        blocks: InkBlockRenderer.render(markdown, configuration: effective),
        configuration: effective
      )
      appliedLayout = nil
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
    streamingHost.teardown(from: containerView)
    let effective = resolvedConfiguration(configuration)
    guard let container = containerView else { return }
    installStaticContinuityCallbacks(on: container)
    staticPresentation = StaticPresentation(markdown: nil, blocks: blocks, configuration: effective)
    appliedLayout = nil
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
    if staticPresentation != nil {
      detachStatic(from: containerView)
      staticContinuity.endCycle()
      staticPresentation = nil
      appliedLayout = nil
    }
    guard let container = containerView else { return }

    _ = streamingHost.update(
      session: session,
      container: container,
      renderEnvironment: renderEnvironment
    )
  }

  func teardown(from dismantledContainer: InkMarkdownContainerView? = nil) {
    streamingHost.teardown(from: dismantledContainer)

    let container = dismantledContainer ?? containerView
    detachStatic(from: container)
    clearStaticContinuityCallbacks()
    dismantledContainer?.onContinuityHeightChanged = nil
    staticContinuity.endCycle()
    staticPresentation = nil
    appliedLayout = nil
    containerView = nil
  }

  // MARK: - Static Helpers

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

  private func detachStatic(from container: InkMarkdownContainerView?) {
    if staticContinuity.ownsAttachment(ownedStaticAttachmentToken),
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
    ownedStaticAttachmentToken = nil
  }

  @discardableResult
  private func reconcileLatestStaticPresentation(
    constrainedWidth: CGFloat? = nil,
    environmentSignature: InkBlockPresentationEnvironmentSignature? = nil
  ) -> Bool {
    guard !isReconcilingStatic,
          let container = containerView,
          let presentation = staticPresentation else {
      return false
    }

    isReconcilingStatic = true
    defer { isReconcilingStatic = false }

    let configuration = presentation.configuration
    let width = constrainedWidth ?? container.effectiveMeasureWidth
    let signature = environmentSignature
      ?? container.resolvedEnvironmentSignature(for: configuration)
    let snapshot = InkBlockPresentationSnapshot(
      cycleID: staticContinuity.cycleID,
      candidates: presentation.blocks.enumerated().map { index, block in
        InkBlockPresentationCandidate(block: block, structuralSlot: index)
      },
      configuration: configuration,
      constrainedWidth: width,
      environmentSignature: signature
    )
    let plan = staticContinuity.reconcile(snapshot)
    guard container.apply(plan) else { return false }

    ownedStaticAttachmentToken = plan.attachmentToken
    appliedLayout = (width, signature)
    return true
  }
}
