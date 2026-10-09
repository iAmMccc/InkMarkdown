//
//  ChatScrollPolicyTests.swift
//  ExampleAppPolicyTests
//

import Testing
@testable import ExampleAppChatPolicy

@Suite("ChatScrollPolicy 滚动与吐字暂停策略")
struct ChatScrollPolicyTests {

  @Test("粘底且内容增长时应自动滚动")
  func stickToBottom_contentGrewShouldAutoScroll() {
    var policy = ChatScrollPolicy()
    policy.offsetChanged(distanceFromBottom: 0, isDragging: false)
    policy.contentGrew()
    #expect(policy.shouldAutoScroll == true)
  }

  @Test("上滑超出 120pt 阈值后不再自动滚动")
  func scrollUpBeyondThreshold_disablesAutoScroll() {
    var policy = ChatScrollPolicy()
    policy.dragBegan()
    policy.dragEnded(distanceFromBottom: 200, isDecelerating: false)
    #expect(policy.shouldAutoScroll == false)
    #expect(policy.stickToBottom == false)
  }

  @Test("新消息发送重置粘底")
  func messagesCountChanged_resetsStickToBottom() {
    var policy = ChatScrollPolicy()
    policy.dragEnded(distanceFromBottom: 200, isDecelerating: false)
    #expect(policy.stickToBottom == false)
    policy.messagesCountChanged()
    #expect(policy.stickToBottom == true)
  }

  @Test("offsetChanged 在非拖拽时刷新粘底 latch")
  func offsetChanged_updatesStickToBottomWhileNotDragging() {
    var policy = ChatScrollPolicy()
    policy.offsetChanged(distanceFromBottom: 200, isDragging: false)
    #expect(policy.stickToBottom == false)
    #expect(policy.shouldAutoScroll == false)

    policy.offsetChanged(distanceFromBottom: 40, isDragging: false)
    #expect(policy.stickToBottom == true)
    #expect(policy.shouldAutoScroll == true)
  }

  @Test("shouldPauseDisplay 仅在拖拽/减速期间为 true")
  func displayPause_shouldPauseOnlyWhileActivelyScrolling() {
    var policy = ChatScrollPolicy()
    #expect(policy.shouldPauseDisplay == false)

    policy.dragBegan()
    #expect(policy.shouldPauseDisplay == true)

    policy.dragEnded(distanceFromBottom: 0, isDecelerating: true)
    #expect(policy.shouldPauseDisplay == true)

    policy.decelerationEnded(distanceFromBottom: 0)
    #expect(policy.shouldPauseDisplay == false)
  }
}
