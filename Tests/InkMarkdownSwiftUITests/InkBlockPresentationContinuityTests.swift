//
//  InkBlockPresentationContinuityTests.swift
//  InkMarkdownSwiftUITests
//

import Testing
import UIKit
import InkMarkdownSemanticCorpus
@testable import InkMarkdownSwiftUI
@_spi(InkMarkdown) import InkMarkdown

@MainActor
private struct TestReusablePresentationBlock: InkReusableBlock {
  let text: String

  func makeView() -> UIView {
    let label = UILabel()
    label.text = text
    return label
  }

  func hasEquivalentContent(to previous: any InkRenderableBlock) -> Bool {
    (previous as? TestReusablePresentationBlock)?.text == text
  }

  func updateExistingView(_ view: UIView) -> Bool {
    guard let label = view as? UILabel else { return false }
    label.text = text
    return true
  }
}

@MainActor
private final class TestSelfReturningPresentationBlock: UIView, InkRenderableBlock {
  private(set) var makeViewCallCount = 0

  func makeView() -> UIView {
    makeViewCallCount += 1
    return self
  }
}

@Suite("Block Presentation Continuity 静态 Thought 关键链")
@MainActor
struct InkBlockPresentationContinuityTests {

  @Test("initial → user mutation → content/environment update → caller override → promotion")
  func blockPresentation_staticThoughtStateChain() throws {
    var configuration = InkConfiguration.standard
    configuration.appearance.thought.isCollapsible = true

    let continuity = InkBlockPresentationContinuity()
    let container = InkMarkdownContainerView()
    let measureWidth: CGFloat = 320
    let promotionEvidence = InkBlockPresentationPromotionLineageEvidence("primary-thought")

    func makePlan(
      thought text: String,
      suppliedCollapsed: Bool,
      suppliedConfiguration: InkConfiguration? = nil,
      trailingText: String = "旁路内容",
      constrainedWidth: CGFloat? = nil,
      environmentSignature: InkBlockPresentationEnvironmentSignature? = nil
    ) -> InkBlockPresentationApplyPlan {
      let effectiveConfiguration = suppliedConfiguration ?? configuration
      let block = InkThoughtBlock(
        thought: text,
        config: effectiveConfiguration.appearance.thought,
        renderConfiguration: effectiveConfiguration,
        isCollapsed: suppliedCollapsed
      )
      let trailingBlock = InkAttributedTextBlock(
        attributedText: NSAttributedString(string: trailingText),
        insets: .zero
      )
      let blocks: [any InkRenderableBlock] = [block, trailingBlock]
      let snapshot = InkBlockPresentationSnapshot(
        cycleID: continuity.cycleID,
        candidates: blocks.enumerated().map { index, block in
          InkBlockPresentationCandidate(
            block: block,
            structuralSlot: index,
            promotionLineageEvidence: block is InkThoughtBlock ? promotionEvidence : nil
          )
        },
        configuration: effectiveConfiguration,
        constrainedWidth: constrainedWidth ?? measureWidth,
        environmentSignature: environmentSignature
          ?? InkBlockPresentationEnvironmentSignature(
            configuration: effectiveConfiguration,
            traitCollection: UITraitCollection.current
          )
      )
      return continuity.reconcile(snapshot)
    }

    let initialPlan = makePlan(thought: "第一步", suppliedCollapsed: false)
    #expect(initialPlan.orderedEntries.first?.presentationState == .thought(isCollapsed: false))
    #expect(initialPlan.orderedEntries.count == 2)
    #expect(initialPlan.orderedEntries.first?.measurementKey.slotRevision == 0)
    #expect(initialPlan.orderedEntries.first?.measurementKey.constrainedWidth == measureWidth)
    #expect(container.apply(initialPlan))
    #expect(initialPlan.isCommitted)

    _ = container.sizeThatFits(CGSize(width: measureWidth, height: .greatestFiniteMagnitude))
    #expect(container.blockMeasurementInvocationCount == 2)
    _ = container.sizeThatFits(CGSize(width: measureWidth, height: .greatestFiniteMagnitude))
    #expect(container.blockMeasurementInvocationCount == 0)

    let equivalentPlan = makePlan(thought: "第一步", suppliedCollapsed: false)
    #expect(!equivalentPlan.invalidatesIntrinsicContentSize)
    #expect(container.apply(equivalentPlan))
    container.frame = CGRect(
      x: 0,
      y: 0,
      width: measureWidth,
      height: container.cachedTotalHeightForTesting
    )
    container.setNeedsLayout()
    container.layoutIfNeeded()
    #expect(container.subviews.first?.frame.height ?? 0 > 0)

    let thoughtView = try #require(
      initialPlan.orderedEntries.first?.view as? InkThoughtBlockView
    )
    thoughtView.handleHeaderTap()
    #expect(thoughtView.isCollapsed)

    let stagedCallerOverridePlan = makePlan(
      thought: "第一步\n未提交 caller",
      suppliedCollapsed: true
    )
    #expect(
      stagedCallerOverridePlan.orderedEntries.first?.presentationState == .thought(isCollapsed: true)
    )

    let contentUpdatePlan = makePlan(thought: "第一步\n第二步", suppliedCollapsed: false)
    #expect(contentUpdatePlan.orderedEntries.first?.presentationState == .thought(isCollapsed: true))
    #expect(contentUpdatePlan.orderedEntries.first?.lineageID == initialPlan.orderedEntries.first?.lineageID)
    #expect(!contentUpdatePlan.invalidatesAllMeasurementSlots)
    #expect(contentUpdatePlan.invalidatedMeasurementLineageIDs.count == 1)
    #expect(container.apply(contentUpdatePlan))
    #expect(
      (contentUpdatePlan.orderedEntries.first?.measurementKey.slotRevision ?? 0)
        > (equivalentPlan.orderedEntries.first?.measurementKey.slotRevision ?? 0)
    )

    _ = container.sizeThatFits(CGSize(width: measureWidth, height: .greatestFiniteMagnitude))
    #expect(container.blockMeasurementInvocationCount == 1)

    let widthUpdatePlan = makePlan(
      thought: "第一步\n第二步",
      suppliedCollapsed: false,
      constrainedWidth: 280
    )
    #expect(widthUpdatePlan.orderedEntries.first?.presentationState == .thought(isCollapsed: true))
    #expect(widthUpdatePlan.orderedEntries.first?.measurementKey.constrainedWidth == 280)
    #expect(widthUpdatePlan.invalidatesIntrinsicContentSize)
    #expect(container.apply(widthUpdatePlan))

    _ = container.sizeThatFits(CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude))
    #expect(container.blockMeasurementInvocationCount == 2)
    #expect(
      container.continuityMeasurementCacheCountForTesting == 2,
      "连续宽度变化后只保留当前宽度的 slot measurement"
    )
    for jitteredWidth in [CGFloat(280.00001), CGFloat(280.00002), CGFloat(280.05)] {
      _ = container.sizeThatFits(
        CGSize(width: jitteredWidth, height: CGFloat.greatestFiniteMagnitude)
      )
      #expect(
        container.blockMeasurementInvocationCount == 0,
        "0.1pt 容差内的宽度抖动必须复用规范宽度的 measurement"
      )
      #expect(
        container.continuityMeasurementCacheCountForTesting == 2,
        "亚像素宽度抖动不得清空或扩张 measurement cache"
      )
    }
    thoughtView.onReservedHeightChanged?()
    #expect(
      container.continuityMeasurementCacheCountForTesting == 2,
      "异步高度回调必须更新最后实际测量宽度，不得复活 committed width 的旧 cache slot"
    )

    #expect(!container.apply(stagedCallerOverridePlan), "过期 staged plan 不得提交")
    #expect(stagedCallerOverridePlan.isAborted)

    var environmentConfiguration = configuration
    environmentConfiguration.appearance.thought.backgroundColor = .secondarySystemBackground
    environmentConfiguration.renderEnvironment = InkRenderEnvironment(
      userInterfaceStyle: .dark,
      contentSizeCategory: .extraExtraLarge
    )
    let environmentPlan = makePlan(
      thought: "第一步\n第二步",
      suppliedCollapsed: false,
      suppliedConfiguration: environmentConfiguration
    )
    #expect(environmentPlan.orderedEntries.first?.presentationState == .thought(isCollapsed: true))
    #expect(
      environmentPlan.orderedEntries.first?.measurementKey.environmentSignature
        != contentUpdatePlan.orderedEntries.first?.measurementKey.environmentSignature
    )
    #expect(environmentPlan.invalidatesAllMeasurementSlots)
    #expect(container.apply(environmentPlan))

    _ = container.sizeThatFits(CGSize(width: measureWidth, height: .greatestFiniteMagnitude))
    #expect(container.blockMeasurementInvocationCount == 2)

    let callerOverridePlan = makePlan(
      thought: "第一步\n第二步",
      suppliedCollapsed: true,
      suppliedConfiguration: environmentConfiguration
    )
    #expect(callerOverridePlan.orderedEntries.first?.presentationState == .thought(isCollapsed: true))
    #expect(!callerOverridePlan.invalidatesAllMeasurementSlots)
    #expect(container.apply(callerOverridePlan))

    let finalPlan = makePlan(
      thought: "第一步\n第二步\n第三步",
      suppliedCollapsed: false,
      suppliedConfiguration: environmentConfiguration
    )
    #expect(finalPlan.orderedEntries.first?.presentationState == .thought(isCollapsed: false))
    #expect(container.apply(finalPlan))

    #expect(!container.apply(finalPlan), "apply plan 只能被 container 消费一次")

    let promotedThought = InkThoughtBlock(
      thought: "第一步\n第二步\n第三步\n第四步",
      config: environmentConfiguration.appearance.thought,
      renderConfiguration: environmentConfiguration,
      isCollapsed: false
    )
    let promotionPlan = continuity.reconcile(
      InkBlockPresentationSnapshot(
        cycleID: continuity.cycleID,
        candidates: [
          InkBlockPresentationCandidate(
            block: InkAttributedTextBlock(
              attributedText: NSAttributedString(string: "终态前置内容"),
              insets: .zero
            ),
            structuralSlot: 0
          ),
          InkBlockPresentationCandidate(
            block: promotedThought,
            structuralSlot: 1,
            promotionLineageEvidence: promotionEvidence
          )
        ],
        configuration: environmentConfiguration,
        constrainedWidth: measureWidth,
        environmentSignature: InkBlockPresentationEnvironmentSignature(
          configuration: environmentConfiguration,
          traitCollection: UITraitCollection.current
        )
      )
    )
    #expect(promotionPlan.orderedEntries[1].lineageID == finalPlan.orderedEntries[0].lineageID)
    #expect(promotionPlan.orderedEntries[1].presentationState == .thought(isCollapsed: false))
    #expect(container.apply(promotionPlan))

    let traitContinuity = InkBlockPresentationContinuity()
    let traitContainer = InkMarkdownContainerView()
    let normalContrastSignature = InkBlockPresentationEnvironmentSignature(
      configuration: configuration,
      traitCollection: UITraitCollection(accessibilityContrast: .normal)
    )
    let highContrastSignature = InkBlockPresentationEnvironmentSignature(
      configuration: configuration,
      traitCollection: UITraitCollection(accessibilityContrast: .high)
    )
    let traitBlock = InkThoughtBlock(
      thought: "trait-only",
      config: configuration.appearance.thought,
      renderConfiguration: configuration,
      isCollapsed: false
    )
    let traitCandidate = InkBlockPresentationCandidate(block: traitBlock, structuralSlot: 0)
    let traitInitialPlan = traitContinuity.reconcile(
      InkBlockPresentationSnapshot(
        cycleID: traitContinuity.cycleID,
        candidates: [traitCandidate],
        configuration: configuration,
        constrainedWidth: measureWidth,
        environmentSignature: normalContrastSignature
      )
    )
    #expect(traitInitialPlan.orderedEntries.first?.measurementKey.environmentSignature != 0)
    #expect(traitContainer.apply(traitInitialPlan))

    let traitUpdatePlan = traitContinuity.reconcile(
      InkBlockPresentationSnapshot(
        cycleID: traitContinuity.cycleID,
        candidates: [traitCandidate],
        configuration: configuration,
        constrainedWidth: measureWidth,
        environmentSignature: highContrastSignature
      )
    )
    #expect(traitUpdatePlan.invalidatesAllMeasurementSlots)
    #expect(
      traitUpdatePlan.orderedEntries.first?.lineageID
        == traitInitialPlan.orderedEntries.first?.lineageID
    )
    #expect(
      traitUpdatePlan.orderedEntries.first?.measurementKey.environmentSignature
        != traitInitialPlan.orderedEntries.first?.measurementKey.environmentSignature
    )
    #expect(traitContainer.apply(traitUpdatePlan))

    let productionContainer = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: measureWidth, height: 0)
    )
    let productionCoordinator = InkMarkdownCoordinator()
    productionCoordinator.containerView = productionContainer
    productionCoordinator.updateStatic(
      markdown: "<think>\nproduction width\n</think>\n\n正文",
      configuration: configuration
    )
    _ = productionContainer.sizeThatFits(
      CGSize(width: measureWidth, height: .greatestFiniteMagnitude)
    )
    let productionInitialKey = try #require(
      productionContainer.continuityMeasurementKeysForTesting.first
    )
    let productionThoughtView = try #require(
      productionContainer.subviews.first(where: { $0 is InkThoughtBlockView }) as? InkThoughtBlockView
    )
    let staleHeightCallback = productionThoughtView.onReservedHeightChanged

    _ = productionContainer.sizeThatFits(
      CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude)
    )
    let productionWidthKey = try #require(
      productionContainer.continuityMeasurementKeysForTesting.first
    )
    #expect(productionWidthKey.constrainedWidth == 280)
    #expect(productionWidthKey.lineageID == productionInitialKey.lineageID)

    let currentWidthHeightCallback = productionThoughtView.onReservedHeightChanged
    let expectedHeightAtCommittedWidth = productionContainer.subviews.reduce(CGFloat.zero) {
      $0 + $1.sizeThatFits(
        CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude)
      ).height
    }
    currentWidthHeightCallback?()
    #expect(
      abs(productionContainer.cachedTotalHeightForTesting - expectedHeightAtCommittedWidth) < 0.5,
      "当前 generation 的高度回调必须使用已提交的 proposed width"
    )

    let revisionBeforeInteraction = productionWidthKey.slotRevision
    let generationBeforeInteraction = productionContainer.continuityAttachmentGenerationForTesting
    productionThoughtView.handleHeaderTap()
    let interactionKey = try #require(
      productionContainer.continuityMeasurementKeysForTesting.first
    )
    #expect(interactionKey.slotRevision == revisionBeforeInteraction + 1)
    #expect(
      productionContainer.continuityAttachmentGenerationForTesting > generationBeforeInteraction
    )

    let reservedUpdatesBeforeStaleCallback = productionContainer.reservedHeightSlotUpdateCount
    staleHeightCallback?()
    #expect(
      productionContainer.reservedHeightSlotUpdateCount == reservedUpdatesBeforeStaleCallback,
      "旧 attachment generation 的高度回调必须被忽略"
    )
    productionThoughtView.onReservedHeightChanged?()
    #expect(
      productionContainer.reservedHeightSlotUpdateCount > reservedUpdatesBeforeStaleCallback,
      "当前 generation 的高度回调应写入新 measurement key"
    )

    let productionTraitCallback = try #require(
      productionContainer.onContinuityLayoutEnvironmentChanged
    )
    var traitReportCount = 0
    productionContainer.onContinuityLayoutEnvironmentChanged = { width, signature in
      traitReportCount += 1
      return productionTraitCallback(width, signature)
    }
    productionContainer.traitCollectionDidChange(
      UITraitCollection(accessibilityContrast: .high)
    )
    let traitProductionKey = try #require(
      productionContainer.continuityMeasurementKeysForTesting.first
    )
    #expect(traitReportCount == 1, "trait-only 变化必须经过 production callback")
    #expect(traitProductionKey.lineageID == interactionKey.lineageID)
    #expect(
      traitProductionKey.environmentSignature == interactionKey.environmentSignature,
      "合成 trait 事件未改变当前环境签名时，不应伪造环境版本"
    )
    let traitUpdatedThoughtView = try #require(
      productionContainer.subviews.first(where: { $0 is InkThoughtBlockView })
        as? InkThoughtBlockView
    )
    #expect(traitUpdatedThoughtView.isCollapsed, "trait 更新不得重置用户折叠态")
  }

  @Test("严格证据 → 歧义降级 → 新周期重置 → custom block 安全重建")
  func blockContinuity_strictEvidenceAmbiguityCycleResetAndCustomFallback() throws {
    var configuration = InkConfiguration.standard
    configuration.appearance.thought.isCollapsible = true

    let continuity = InkBlockPresentationContinuity()
    let container = InkMarkdownContainerView()

    func makeThought(
      _ text: String,
      slot: Int,
      stableIdentity: AnyHashable? = nil,
      promotionEvidence: InkBlockPresentationPromotionLineageEvidence? = nil
    ) -> InkBlockPresentationCandidate {
      InkBlockPresentationCandidate(
        block: InkThoughtBlock(
          thought: text,
          config: configuration.appearance.thought,
          renderConfiguration: configuration,
          isCollapsed: false
        ),
        structuralSlot: slot,
        stableIdentity: stableIdentity,
        promotionLineageEvidence: promotionEvidence
      )
    }

    func makeSnapshot(
      cycleID: InkBlockPresentationCycleID,
      candidates: [InkBlockPresentationCandidate]
    ) -> InkBlockPresentationSnapshot {
      InkBlockPresentationSnapshot(
        cycleID: cycleID,
        candidates: candidates,
        configuration: configuration,
        constrainedWidth: 320,
        environmentSignature: InkBlockPresentationEnvironmentSignature(
          configuration: configuration,
          traitCollection: UITraitCollection.current
        )
      )
    }

    func operationCounts(
      _ plan: InkBlockPresentationApplyPlan
    ) -> (mounts: Int, unmounts: Int, replacements: Int) {
      plan.operations.reduce(into: (mounts: 0, unmounts: 0, replacements: 0)) { counts, operation in
        switch operation {
        case .update:
          break
        case .mount:
          counts.mounts += 1
        case .unmount:
          counts.unmounts += 1
        case .replace:
          counts.replacements += 1
        case .order:
          break
        }
      }
    }

    let promotionEvidence = InkBlockPresentationPromotionLineageEvidence("thought-promotion")
    let initialPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: continuity.cycleID,
        candidates: [
          makeThought(
            "strict",
            slot: 0,
            stableIdentity: "thought",
            promotionEvidence: promotionEvidence
          )
        ]
      )
    )
    #expect(initialPlan.orderedEntries.first?.presentationState == .thought(isCollapsed: false))
    #expect(container.apply(initialPlan))
    let initialLineage = try #require(initialPlan.orderedEntries.first?.lineageID)
    let initialThoughtView = try #require(
      initialPlan.orderedEntries.first?.view as? InkThoughtBlockView
    )
    initialThoughtView.handleHeaderTap()

    let strictPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: continuity.cycleID,
        candidates: [
          makeThought(
            "strict changed",
            slot: 7,
            stableIdentity: "thought",
            promotionEvidence: promotionEvidence
          )
        ]
      )
    )
    #expect(strictPlan.orderedEntries.first?.lineageID == initialLineage)
    #expect(strictPlan.orderedEntries.first?.presentationState == .thought(isCollapsed: true))
    #expect(container.apply(strictPlan))

    let ambiguityPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: continuity.cycleID,
        candidates: [
          makeThought("weaker first", slot: 0, promotionEvidence: promotionEvidence),
          makeThought("stable claimant", slot: 1, stableIdentity: "thought")
        ]
      )
    )
    let ambiguityEntries = ambiguityPlan.orderedEntries
    #expect(ambiguityEntries.count == 2)
    #expect(ambiguityEntries[0].lineageID != ambiguityEntries[1].lineageID)
    #expect(ambiguityEntries[0].presentationState == .thought(isCollapsed: false))
    #expect(ambiguityEntries[1].lineageID == initialLineage)
    #expect(ambiguityEntries[1].presentationState == .thought(isCollapsed: true))
    #expect(container.apply(ambiguityPlan))

    let preResetPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: continuity.cycleID,
        candidates: [makeThought("reset proof", slot: 0, stableIdentity: "reset-proof")]
      )
    )
    #expect(container.apply(preResetPlan))
    let preResetThoughtView = try #require(
      preResetPlan.orderedEntries.first?.view as? InkThoughtBlockView
    )
    preResetThoughtView.handleHeaderTap()
    #expect(preResetThoughtView.isCollapsed)
    let staleCycleHeightCallback = try #require(preResetThoughtView.onReservedHeightChanged)
    let reservedUpdatesBeforeCycleBoundary = container.reservedHeightSlotUpdateCount

    let staleCyclePlan = continuity.reconcile(
      makeSnapshot(
        cycleID: continuity.cycleID,
        candidates: [makeThought("stale cycle", slot: 0, stableIdentity: "reset-proof")]
      )
    )
    continuity.invalidateForCycleBoundary()
    staleCycleHeightCallback()
    #expect(
      container.reservedHeightSlotUpdateCount == reservedUpdatesBeforeCycleBoundary,
      "周期切换必须立即失效旧高度 callback"
    )
    #expect(!container.apply(staleCyclePlan), "周期切换必须立即作废旧 staged plan")

    let newCycle = InkBlockPresentationCycleID()
    let resetPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: newCycle,
        candidates: [makeThought("new cycle", slot: 0, stableIdentity: "reset-proof")]
      )
    )
    #expect(resetPlan.orderedEntries.first?.presentationState == .thought(isCollapsed: false))
    #expect(resetPlan.invalidatesAllMeasurementSlots)
    #expect(operationCounts(resetPlan).mounts == 1)
    #expect(container.apply(resetPlan))

    let multiThoughtCycle = InkBlockPresentationCycleID()
    let multiThoughtInitialPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: multiThoughtCycle,
        candidates: [
          makeThought("first", slot: 0),
          makeThought("second", slot: 1),
        ]
      )
    )
    #expect(container.apply(multiThoughtInitialPlan))
    let firstThoughtLineage = multiThoughtInitialPlan.orderedEntries[0].lineageID
    let secondThoughtLineage = multiThoughtInitialPlan.orderedEntries[1].lineageID
    let firstThoughtView = try #require(
      multiThoughtInitialPlan.orderedEntries[0].view as? InkThoughtBlockView
    )
    firstThoughtView.handleHeaderTap()

    let multiThoughtUpdatePlan = continuity.reconcile(
      makeSnapshot(
        cycleID: multiThoughtCycle,
        candidates: [
          makeThought("first changed", slot: 0),
          makeThought("second changed", slot: 1),
        ]
      )
    )
    #expect(multiThoughtUpdatePlan.orderedEntries[0].lineageID == firstThoughtLineage)
    #expect(multiThoughtUpdatePlan.orderedEntries[1].lineageID == secondThoughtLineage)
    #expect(multiThoughtUpdatePlan.orderedEntries[0].presentationState == .thought(isCollapsed: true))
    #expect(multiThoughtUpdatePlan.orderedEntries[1].presentationState == .thought(isCollapsed: false))
    #expect(container.apply(multiThoughtUpdatePlan))

    let deletionPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: multiThoughtCycle,
        candidates: [makeThought("second changed", slot: 0)]
      )
    )
    let deletionLineage = try #require(deletionPlan.orderedEntries.first?.lineageID)
    #expect(deletionLineage != firstThoughtLineage)
    #expect(deletionLineage != secondThoughtLineage)
    #expect(deletionPlan.orderedEntries.first?.presentationState == .thought(isCollapsed: false))
    #expect(container.apply(deletionPlan))

    let reorderCycle = InkBlockPresentationCycleID()
    let reorderInitialPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: reorderCycle,
        candidates: [
          makeThought("reorder A", slot: 0),
          makeThought("reorder B", slot: 1),
          makeThought("reorder C", slot: 2),
        ]
      )
    )
    #expect(container.apply(reorderInitialPlan))
    let reorderOldLineages = Set(reorderInitialPlan.orderedEntries.map(\.lineageID))
    let reorderThirdLineage = reorderInitialPlan.orderedEntries[2].lineageID
    let reorderFirstView = try #require(
      reorderInitialPlan.orderedEntries.first?.view as? InkThoughtBlockView
    )
    reorderFirstView.handleHeaderTap()
    let reorderThirdView = try #require(
      reorderInitialPlan.orderedEntries[2].view as? InkThoughtBlockView
    )
    reorderThirdView.handleHeaderTap()

    let reorderPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: reorderCycle,
        candidates: [
          makeThought("reorder B", slot: 0),
          makeThought("reorder A", slot: 1),
          makeThought("reorder C", slot: 2),
        ]
      )
    )
    #expect(reorderPlan.orderedEntries.prefix(2).allSatisfy {
      !reorderOldLineages.contains($0.lineageID)
    })
    #expect(reorderPlan.orderedEntries.prefix(2).allSatisfy {
      $0.presentationState == .thought(isCollapsed: false)
    })
    #expect(reorderPlan.orderedEntries[2].lineageID == reorderThirdLineage)
    #expect(reorderPlan.orderedEntries[2].presentationState == .thought(isCollapsed: true))
    #expect(container.apply(reorderPlan))

    let customInitialPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: continuity.cycleID,
        candidates: [
          makeThought("adjacent", slot: 0, stableIdentity: "thought"),
          InkBlockPresentationCandidate(
            block: TestReusablePresentationBlock(text: "custom"),
            structuralSlot: 1,
            stableIdentity: "custom"
          )
        ]
      )
    )
    #expect(container.apply(customInitialPlan))
    let customInitialLineage = customInitialPlan.orderedEntries[1].lineageID
    let adjacentLineage = customInitialPlan.orderedEntries[0].lineageID

    let customRebuildPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: continuity.cycleID,
        candidates: [
          makeThought("adjacent", slot: 0, stableIdentity: "thought"),
          InkBlockPresentationCandidate(
            block: TestReusablePresentationBlock(text: "custom"),
            structuralSlot: 2,
            stableIdentity: "custom"
          )
        ]
      )
    )
    #expect(customRebuildPlan.orderedEntries[0].lineageID == adjacentLineage)
    #expect(customRebuildPlan.orderedEntries[1].lineageID != customInitialLineage)
    #expect(operationCounts(customRebuildPlan).mounts == 1)
    #expect(operationCounts(customRebuildPlan).unmounts == 1)
    #expect(container.apply(customRebuildPlan))

    let selfReturningBlock = TestSelfReturningPresentationBlock()
    let selfReturningCycle = InkBlockPresentationCycleID()
    let selfReturningInitialPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: selfReturningCycle,
        candidates: [
          InkBlockPresentationCandidate(block: selfReturningBlock, structuralSlot: 0)
        ]
      )
    )
    #expect(selfReturningBlock.makeViewCallCount == 0, "reconcile staging 不得调用 makeView")
    #expect(container.apply(selfReturningInitialPlan))
    #expect(selfReturningBlock.makeViewCallCount == 1)
    #expect(selfReturningBlock.superview === container)
    let selfReturningInitialLineage = selfReturningInitialPlan.orderedEntries[0].lineageID

    let selfReturningRebuildPlan = continuity.reconcile(
      makeSnapshot(
        cycleID: selfReturningCycle,
        candidates: [
          InkBlockPresentationCandidate(block: selfReturningBlock, structuralSlot: 0)
        ]
      )
    )
    #expect(selfReturningBlock.makeViewCallCount == 1, "过期前的 staged plan 仍不得触碰 UIView")
    #expect(selfReturningRebuildPlan.orderedEntries[0].lineageID != selfReturningInitialLineage)
    #expect(container.apply(selfReturningRebuildPlan))
    #expect(selfReturningBlock.makeViewCallCount == 2)
    #expect(selfReturningBlock.superview === container, "self-returning custom view 不能先 mount 后 unmount 消失")
  }

  @Test("detach → same-session reattach → stale callbacks ignored → affected Thought slot revision +1")
  func blockContinuity_detachReattachPreservesDurableStateAndScopesRevision() async throws {
    var configuration = InkConfiguration.standard
    configuration.appearance.thought.isCollapsible = true

    let continuity = InkBlockPresentationContinuity()
    let container = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )
    let snapshot = InkBlockPresentationSnapshot(
      cycleID: continuity.cycleID,
      candidates: [
        InkBlockPresentationCandidate(
          block: InkThoughtBlock(
            thought: "可恢复的思考",
            config: configuration.appearance.thought,
            renderConfiguration: configuration,
            isCollapsed: false
          ),
          structuralSlot: 0,
          stableIdentity: "thought"
        ),
        InkBlockPresentationCandidate(
          block: TestReusablePresentationBlock(text: "相邻内容"),
          structuralSlot: 1,
          stableIdentity: "adjacent"
        )
      ],
      configuration: configuration,
      constrainedWidth: 320
    )

    let initialPlan = continuity.reconcile(snapshot)
    #expect(container.apply(initialPlan))
    _ = container.sizeThatFits(
      CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
    )

    let initialThoughtEntry = try #require(initialPlan.orderedEntries.first)
    let initialAdjacentEntry = try #require(initialPlan.orderedEntries.dropFirst().first)
    let initialThoughtView = try #require(
      initialThoughtEntry.view as? InkThoughtBlockView
    )
    let staleInteractionCallback = try #require(initialThoughtView.onToggleCollapse)
    let staleHeightCallback = try #require(initialThoughtView.onReservedHeightChanged)

    initialThoughtView.handleHeaderTap()
    #expect(initialThoughtView.isCollapsed)

    let detachPlan = try #require(continuity.detach())
    #expect(container.apply(detachPlan))
    #expect(continuity.detach() == nil, "重复 detach 必须幂等")

    #expect(snapshot.cycleID == continuity.cycleID)
    let reattachPlan = continuity.reconcile(snapshot)
    let reattachedThoughtEntry = try #require(reattachPlan.orderedEntries.first)
    let reattachedAdjacentEntry = try #require(reattachPlan.orderedEntries.dropFirst().first)
    #expect(reattachedThoughtEntry.lineageID == initialThoughtEntry.lineageID)
    #expect(reattachedAdjacentEntry.lineageID == initialAdjacentEntry.lineageID)
    #expect(
      reattachedThoughtEntry.presentationState == .thought(isCollapsed: true),
      "same cycle reattach 必须恢复 Thought live collapsed state"
    )
    #expect(container.apply(reattachPlan))

    let reattachedThoughtView = try #require(
      reattachedThoughtEntry.view as? InkThoughtBlockView
    )
    #expect(reattachedThoughtView.isCollapsed)
    let reattachedKeys = container.continuityMeasurementKeysForTesting
    #expect(reattachedKeys.count == 2)
    let thoughtKeyBeforeStale = try #require(reattachedKeys.first)
    let adjacentKeyBeforeStale = try #require(reattachedKeys.dropFirst().first)

    let reservedUpdatesBeforeStale = container.reservedHeightSlotUpdateCount
    staleInteractionCallback(false)
    staleHeightCallback()
    #expect(
      container.reservedHeightSlotUpdateCount == reservedUpdatesBeforeStale,
      "旧 attachment 的高度 callback 不得更新 measurement slot"
    )
    #expect(
      container.continuityMeasurementKeysForTesting == reattachedKeys,
      "旧 callback 不得改变当前 measurement key/revision"
    )

    let staleIgnoredPlan = continuity.reconcile(snapshot)
    let staleIgnoredThoughtEntry = try #require(staleIgnoredPlan.orderedEntries.first)
    let staleIgnoredAdjacentEntry = try #require(
      staleIgnoredPlan.orderedEntries.dropFirst().first
    )
    #expect(
      staleIgnoredThoughtEntry.presentationState == .thought(isCollapsed: true),
      "旧 interaction callback 不得改变 live state"
    )
    #expect(staleIgnoredThoughtEntry.measurementKey == thoughtKeyBeforeStale)
    #expect(staleIgnoredAdjacentEntry.measurementKey == adjacentKeyBeforeStale)
    #expect(staleIgnoredPlan.invalidatedMeasurementLineageIDs.isEmpty)
    #expect(container.apply(staleIgnoredPlan))

    let keysBeforeCurrentInteraction = container.continuityMeasurementKeysForTesting
    let thoughtRevisionBeforeCurrentInteraction = try #require(
      keysBeforeCurrentInteraction.first
    ).slotRevision
    let adjacentRevisionBeforeCurrentInteraction = try #require(
      keysBeforeCurrentInteraction.dropFirst().first
    ).slotRevision

    let currentThoughtView = try #require(
      staleIgnoredThoughtEntry.view as? InkThoughtBlockView
    )
    currentThoughtView.handleHeaderTap()
    #expect(!currentThoughtView.isCollapsed)

    let currentInteractionPlan = continuity.reconcile(snapshot)
    let currentThoughtEntry = try #require(currentInteractionPlan.orderedEntries.first)
    let currentAdjacentEntry = try #require(
      currentInteractionPlan.orderedEntries.dropFirst().first
    )
    #expect(
      currentThoughtEntry.measurementKey.slotRevision
        == thoughtRevisionBeforeCurrentInteraction + 1
    )
    #expect(
      currentAdjacentEntry.measurementKey.slotRevision
        == adjacentRevisionBeforeCurrentInteraction,
      "当前 interaction 只能增加 Thought 对应 slot revision"
    )
    #expect(
      currentInteractionPlan.invalidatedMeasurementLineageIDs
        == Set([currentThoughtEntry.lineageID])
    )
    #expect(!currentInteractionPlan.invalidatesAllMeasurementSlots)
    #expect(currentThoughtEntry.presentationState == .thought(isCollapsed: false))
    #expect(container.apply(currentInteractionPlan))

    // 真实 production handoff：新 Coordinator 先登记，旧 host teardown 后同步接管。
    let handoffSession = InkMarkdownRenderSession(configuration: configuration)
    handoffSession.append("<think>\n交叠接管")
    let oldCoordinator = InkMarkdownCoordinator()
    let oldContainer = InkMarkdownContainerView()
    oldCoordinator.containerView = oldContainer
    oldCoordinator.updateStreaming(
      session: handoffSession,
      renderEnvironment: InkRenderEnvironment(userInterfaceStyle: .light)
    )
    #expect(
      handoffSession.configuration.renderEnvironment.userInterfaceStyle == .light,
      "首次提交 attachment 的 host 才能应用自身环境"
    )
    let oldThought = try #require(
      oldContainer.subviews.first(where: { $0 is InkThoughtBlockView })
        as? InkThoughtBlockView
    )

    // 等待者若先销毁，不得解绑、丢弃或清空仍由旧 host 持有的 attachment。
    let abandonedCoordinator = InkMarkdownCoordinator()
    let abandonedContainer = InkMarkdownContainerView()
    abandonedCoordinator.containerView = abandonedContainer
    abandonedCoordinator.updateStreaming(
      session: handoffSession,
      renderEnvironment: InkRenderEnvironment(userInterfaceStyle: .dark)
    )
    #expect(abandonedContainer.subviews.isEmpty)
    #expect(
      handoffSession.configuration.renderEnvironment.userInterfaceStyle == .light,
      "等待 host 在 apply 失败时不得污染活跃 host 环境"
    )
    abandonedCoordinator.teardown(from: abandonedContainer)

    handoffSession.renderer.charactersPerFrame = 100
    handoffSession.append("\n旧 host 仍活跃")
    await InkAsyncTestProbe.wait { oldThought.thought.contains("旧 host 仍活跃") }
    #expect(oldThought.thought.contains("旧 host 仍活跃"))

    let waitingCoordinator = InkMarkdownCoordinator()
    let waitingContainer = InkMarkdownContainerView()
    waitingCoordinator.containerView = waitingContainer
    waitingCoordinator.updateStreaming(
      session: handoffSession,
      renderEnvironment: InkRenderEnvironment(userInterfaceStyle: .dark)
    )
    #expect(waitingContainer.subviews.isEmpty, "旧 attachment 未释放前，新 host 首次 apply 必须等待")
    #expect(
      handoffSession.configuration.renderEnvironment.userInterfaceStyle == .light,
      "等待接管 host 不得在旧 owner 仍活跃时写入环境"
    )

    // 接管等待期间继续到达增量，旧 owner 更新后不得覆盖等待者的登记。
    handoffSession.append("\n接管前增量")
    await InkAsyncTestProbe.wait { oldThought.thought.contains("接管前增量") }
    #expect(waitingContainer.subviews.isEmpty)

    oldCoordinator.teardown(from: oldContainer)
    #expect(oldContainer.subviews.isEmpty)
    #expect(waitingContainer.subviews.contains(where: { $0 is InkThoughtBlockView }))
    #expect(waitingContainer.subviews.contains(where: { $0 is UITextView }))
    #expect(
      handoffSession.configuration.renderEnvironment.userInterfaceStyle == .dark,
      "接管成功后应应用新 host 在 coordinator 中保存的环境快照"
    )

    // 旧 teardown 不得移除新 display observer 或解绑新 renderer text view。
    handoffSession.append("\n</think>\n\n新 host 正文")
    await InkAsyncTestProbe.wait {
      let thought = waitingContainer.subviews.first(where: { $0 is InkThoughtBlockView })
        as? InkThoughtBlockView
      let text = waitingContainer.subviews.first(where: { $0 is UITextView })
        as? UITextView
      return thought?.isComplete == true && text?.text.contains("新 host 正文") == true
    }
    let handedOffThought = try #require(
      waitingContainer.subviews.first(where: { $0 is InkThoughtBlockView })
        as? InkThoughtBlockView
    )
    let handedOffText = try #require(
      waitingContainer.subviews.first(where: { $0 is UITextView })
        as? UITextView
    )
    #expect(handedOffThought.isComplete)
    #expect(handedOffText.text.contains("新 host 正文"))

    // S-05：B 已接管后旧 A 再次 teardown/release 不得解绑 B；B 继续接收正文。
    oldCoordinator.teardown(from: oldContainer)
    handoffSession.append("\n旧 A 二次释放后正文")
    await InkAsyncTestProbe.wait {
      let text = waitingContainer.subviews.first(where: { $0 is UITextView })
        as? UITextView
      return text?.text.contains("旧 A 二次释放后正文") == true
    }
    let afterStaleReleaseText = try #require(
      waitingContainer.subviews.first(where: { $0 is UITextView })
        as? UITextView
    )
    #expect(afterStaleReleaseText.text.contains("旧 A 二次释放后正文"))
    #expect(
      handoffSession.configuration.renderEnvironment.userInterfaceStyle == .dark,
      "旧 A 二次 teardown 不得回滚 B 已应用的环境"
    )

    // 真实 cancel/reset 边界：cancel 后不得重新建立空 remainder，下一周期不得复活旧折叠态。
    let cancelSession = InkMarkdownRenderSession(configuration: configuration)
    let cancelCoordinator = InkMarkdownCoordinator()
    let cancelContainer = InkMarkdownContainerView()
    cancelCoordinator.containerView = cancelContainer
    cancelCoordinator.updateStreaming(session: cancelSession)
    #expect(cancelContainer.subviews.isEmpty, "idle session 不应创建空 remainder attachment")

    cancelSession.append("<think>\n即将取消")
    await InkAsyncTestProbe.wait {
      cancelContainer.subviews.contains(where: { $0 is InkThoughtBlockView })
    }
    let cancellingThought = try #require(
      cancelContainer.subviews.first(where: { $0 is InkThoughtBlockView })
        as? InkThoughtBlockView
    )
    cancellingThought.handleHeaderTap()
    #expect(cancellingThought.isCollapsed)

    cancelSession.cancel()
    await InkAsyncTestProbe.wait { cancelContainer.subviews.isEmpty }
    #expect(cancelSession.state == .cancelled)
    #expect(cancelContainer.subviews.isEmpty, "cancel 必须退休 Thought 与 remainder attachment")

    cancelSession.reset()
    #expect(cancelContainer.subviews.isEmpty)
    cancelSession.append("<think>\n新周期")
    await InkAsyncTestProbe.wait {
      cancelContainer.subviews.contains(where: { $0 is InkThoughtBlockView })
    }
    let resetThought = try #require(
      cancelContainer.subviews.first(where: { $0 is InkThoughtBlockView })
        as? InkThoughtBlockView
    )
    #expect(!resetThought.isCollapsed, "reset 后新周期不得复活 cancel 前的 live state")
  }

  @Test("环境补充 reconcile 排队遇 cancel 后下一 runloop 不复活旧内容")
  func blockContinuity_queuedEnvironmentReconcileInvalidatedByCancel() async throws {
    var configuration = InkConfiguration.standard
    configuration.appearance.thought.isCollapsible = true

    let session = InkMarkdownRenderSession(configuration: configuration)
    session.renderer.charactersPerFrame = 200
    let coordinator = InkMarkdownCoordinator()
    let container = InkMarkdownContainerView(
      frame: CGRect(x: 0, y: 0, width: 320, height: 0)
    )
    coordinator.containerView = container
    coordinator.updateStreaming(
      session: session,
      renderEnvironment: InkRenderEnvironment(userInterfaceStyle: .light)
    )

    session.append("<think>\n排队环境")
    await InkAsyncTestProbe.wait {
      container.subviews.contains(where: { $0 is InkThoughtBlockView })
    }
    let thought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView })
        as? InkThoughtBlockView
    )
    thought.handleHeaderTap()
    #expect(thought.isCollapsed)

    // 触发 applyPending → DispatchQueue.main.async 补充 reconcile。
    coordinator.updateStreaming(
      session: session,
      renderEnvironment: InkRenderEnvironment(userInterfaceStyle: .dark)
    )
    #expect(session.configuration.renderEnvironment.userInterfaceStyle == .dark)

    session.cancel()
    #expect(session.state == .cancelled)

    // 抽干下一 main async turn；旧补充 reconcile 不得把已 cancel 的内容装回。
    await InkAsyncTestProbe.wait(timeoutNanoseconds: 200_000_000) {
      container.subviews.isEmpty
    }
    #expect(container.subviews.isEmpty, "cancel 后排队环境 reconcile 不得复活旧 Thought/remainder")

    session.reset()
    #expect(container.subviews.isEmpty)
    session.append("<think>\ncancel 后新周期")
    await InkAsyncTestProbe.wait {
      container.subviews.contains(where: { $0 is InkThoughtBlockView })
    }
    let nextThought = try #require(
      container.subviews.first(where: { $0 is InkThoughtBlockView })
        as? InkThoughtBlockView
    )
    #expect(!nextThought.isCollapsed)
  }
}
