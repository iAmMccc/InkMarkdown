//
//  InkThoughtPresentationPolicy.swift
//  InkMarkdown
//

import UIKit

/// Thought 块构造策略；语法 SSOT 仍在 ``InkThoughtScanner``。
@MainActor
public enum InkThoughtPresentationPolicy {

  /// 由 scan 结果构造终态或 handler 路由用的 ``InkThoughtBlock``。
  public static func makeBlock(
    from parsed: InkThoughtScanner.Result,
    configuration: InkConfiguration,
    isCollapsed: Bool? = nil
  ) -> InkThoughtBlock {
    InkThoughtBlock(
      thought: parsed.thoughtBody,
      isComplete: parsed.isComplete,
      config: configuration.appearance.thought,
      renderConfiguration: configuration,
      isCollapsed: isCollapsed
    )
  }

}
