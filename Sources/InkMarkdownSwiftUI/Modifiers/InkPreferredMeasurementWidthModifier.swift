//
//  InkPreferredMeasurementWidthModifier.swift
//  InkMarkdownSwiftUI
//

import SwiftUI

private struct InkPreferredMeasurementWidthKey: EnvironmentKey {
  static let defaultValue: CGFloat = 0
}

public extension EnvironmentValues {
  /// 宿主在首轮 layout 前提供的 Markdown 内容测量宽度（pt）。
  ///
  /// 大于 0 时供 ``InkMarkdownView`` / ``InkStreamMarkdownView`` 写入底层容器的
  /// `preferredMeasurementWidth`。详见贡献者文档「布局测量契约」。
  var inkPreferredMeasurementWidth: CGFloat {
    get { self[InkPreferredMeasurementWidthKey.self] }
    set { self[InkPreferredMeasurementWidthKey.self] = newValue }
  }
}

public extension View {
  /// 为当前视图层级注入 Markdown 内容测量宽度。
  ///
  /// 用于 chat bubble / table cell 等宿主在 Auto Layout 完成前已知道最终列宽的场景，
  /// 让首轮 `intrinsicContentSize` 按终态宽度测量，避免二次抬高闪烁。
  ///
  /// ```swift
  /// InkStreamMarkdownView(session: session)
  ///   .preferredMeasurementWidth(bubbleContentWidth)
  /// ```
  ///
  /// - Parameter width: 内容可用宽度（pt）。`<= 0` 表示不提供，回退既有宽度解析。
  /// - Returns: 注入了测量宽度的视图。
  func preferredMeasurementWidth(_ width: CGFloat) -> some View {
    environment(\.inkPreferredMeasurementWidth, width)
  }
}
