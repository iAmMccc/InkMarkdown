//
//  DemoCatalog.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import Foundation

/// 一级分类：UIKit 渲染引擎 vs SwiftUI 适配器。
public enum MainCategory: CaseIterable {
  case uikitEngine
  case swiftUIAdapter

  public var title: String {
    switch self {
    case .uikitEngine: return "📱 UIKit 渲染引擎"
    case .swiftUIAdapter: return "⚡ SwiftUI 适配器"
    }
  }

  public var subtitle: String {
    switch self {
    case .uikitEngine: return "Core UIKit 富文本与 Block 视图渲染、组件扩展、配置与流式引擎"
    case .swiftUIAdapter: return "InkMarkdownView、Environment 注入与流式会话管理"
    }
  }
}

/// 二级对齐测试集（UIKit 与 SwiftUI 1:1 对称）。
public enum DemoScenario: CaseIterable {
  case standardStatic
  case customComponents
  case configuration
  case streamingDocument
  case aiChat
  case longTextPerformance

  public var title: String {
    switch self {
    case .standardStatic: return "1. 基础 Markdown 静态渲染"
    case .customComponents: return "2. 自定义组件与富媒体"
    case .configuration: return "3. 样式配置与动态主题"
    case .streamingDocument: return "4. 流式 Markdown 渲染 (单文档)"
    case .aiChat: return "5. AI SSE 对话问答"
    case .longTextPerformance: return "6. 综合长文与性能基线"
    }
  }

  public var subtitle: String {
    switch self {
    case .standardStatic: return "标题、正文、加粗斜体、删除线、列表、引用、代码块与链接"
    case .customComponents: return "表格滑动与复制、图片预览、LaTeX 公式与 Mermaid 流程图"
    case .configuration: return "动态字号缩放、段落间距调整、主题色与 Dark Mode"
    case .streamingDocument: return "逐字吐字、表格实时流式展示、真实大模型提问与状态机"
    case .aiChat: return "历史消息列表、流式逐字追加与多端点选择"
    case .longTextPerformance: return "超长 Markdown 综合文档解析渲染速度与滚动流畅度"
    }
  }
}
