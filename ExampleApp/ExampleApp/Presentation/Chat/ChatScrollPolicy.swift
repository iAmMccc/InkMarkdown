//
//  ChatScrollPolicy.swift
//  ExampleApp
//

import CoreGraphics

/// Chat 列表滚动与流式吐字暂停策略（SwiftUI / UIKit Chat Demo 共用）。
public struct ChatScrollPolicy {

  /// 是否粘底（用户上滑超出阈值后变为 false，回到底部附近恢复 true）。
  public var stickToBottom: Bool = true

  /// 用户是否正在拖拽或减速中。
  private(set) var isUserActivelyScrolling: Bool = false

  /// 最近一次距底部距离（pt），供 `contentGrew` 等事件刷新 latch。
  private var lastDistanceFromBottom: CGFloat = 0

  /// 距底部距离阈值（pt），与 `SSEChatViewController` 历史行为一致。
  public static let bottomThreshold: CGFloat = 120

  public init() {}

  /// 用户开始拖拽。
  public mutating func dragBegan() {
    isUserActivelyScrolling = true
  }

  /// 用户结束拖拽。
  public mutating func dragEnded(distanceFromBottom: CGFloat, isDecelerating: Bool) {
    lastDistanceFromBottom = distanceFromBottom
    updateStickToBottom(distanceFromBottom: distanceFromBottom)
    if !isDecelerating {
      isUserActivelyScrolling = false
    }
  }

  /// 减速结束。
  public mutating func decelerationEnded(distanceFromBottom: CGFloat) {
    lastDistanceFromBottom = distanceFromBottom
    updateStickToBottom(distanceFromBottom: distanceFromBottom)
    isUserActivelyScrolling = false
  }

  /// 滚动偏移变化（SwiftUI preference 或 UIKit scrollViewDidScroll 均可驱动）。
  ///
  /// - Parameters:
  ///   - distanceFromBottom: 内容底缘距可视区域底部的距离。
  ///   - isDragging: 手指是否仍在屏幕上；`false` 时仅刷新粘底 latch，不延长 pause。
  public mutating func offsetChanged(distanceFromBottom: CGFloat, isDragging: Bool) {
    lastDistanceFromBottom = distanceFromBottom
    updateStickToBottom(distanceFromBottom: distanceFromBottom)
    if isDragging {
      isUserActivelyScrolling = true
    }
  }

  /// 内容高度增长（流式 append / cell 高度变化）。
  public mutating func contentGrew() {
    updateStickToBottom(distanceFromBottom: lastDistanceFromBottom)
  }

  /// 消息条数变化（新发送重置粘底）。
  public mutating func messagesCountChanged() {
    stickToBottom = true
  }

  /// 是否应自动滚动到底部（唯一谓词；宿主不得二次 distance 判定）。
  public var shouldAutoScroll: Bool {
    stickToBottom && !isUserActivelyScrolling
  }

  /// 是否应暂停流式吐字（仅拖拽/减速期间）。
  public var shouldPauseDisplay: Bool {
    isUserActivelyScrolling
  }

  private mutating func updateStickToBottom(distanceFromBottom: CGFloat) {
    stickToBottom = distanceFromBottom <= Self.bottomThreshold
  }
}
