//
//  StreamingDemoViewModel.swift
//  ExampleApp
//

import Combine
import Foundation
import InkMarkdown
import InkMarkdownSwiftUI
import UIKit

/// 流式 Markdown Demo 共享 ViewModel（SwiftUI / UIKit 宿主共用）。
@MainActor
final class StreamingDemoViewModel: ObservableObject {

  let session: InkMarkdownRenderSession

  @Published var inputPrompt: String
  @Published private(set) var isLoading = false
  @Published var errorMessage: String?
  @Published var showingConfigSheet = false
  @Published private(set) var nextChunkIndex = 0

  /// 默认 prompt 与 Mock 路由样本标题对齐。
  static let defaultPrompt = "请用 Markdown 写一份 Swift 结构体与类的对比，包含代码块与表格"

  private let localMockChunks = [
    "# Swift 流式渲染\n\n",
    "宿主收到 SSE/WebSocket 分片后，逐个调用 `session.append(...)`。\n\n",
    "流式阶段使用增量富文本；**finish 后**才提升为块级组件（如 `InkTableBlockView`）。\n\n",
    "- 流式期表格以管道字符富文本显示，非交互式真表\n",
    "- `finish()` 只表示输入结束\n",
    "- 终态 promotion 完成后表格才可滑动与复制\n\n",
    "| 状态 | 语义 |\n| --- | --- |\n| streaming | 富文本增量 |\n| finished | 块级终态 |\n\n",
    "```swift\nsession.finish()\n```\n"
  ]

  init(userInterfaceStyle: UIUserInterfaceStyle = UITraitCollection.current.userInterfaceStyle) {
    inputPrompt = Self.defaultPrompt
    session = InkMarkdownRenderSession(
      configuration: DemoInkConfigurationBuilder.makeStaticConfiguration(
        userInterfaceStyle: userInterfaceStyle
      )
    )
  }

  var canAppendMock: Bool {
    switch session.state {
    case .idle, .streaming:
      return !isLoading && nextChunkIndex < localMockChunks.count
    case .finishing, .displayingFinalContent, .finished, .cancelled:
      return false
    }
  }

  var canFinish: Bool {
    session.state == .streaming && !isLoading
  }

  var canCancel: Bool {
    switch session.state {
    case .streaming, .finishing, .displayingFinalContent:
      return true
    case .idle, .finished, .cancelled:
      return isLoading
    }
  }

  var stateDescription: String {
    switch session.state {
    case .idle:
      return "idle：等待宿主追加分片或发起提问"
    case .streaming:
      return isLoading
        ? "streaming：正在接收大模型流式输出..."
        : "streaming：正在增量显示（已追加 \(nextChunkIndex)/\(localMockChunks.count)）"
    case .finishing:
      return "finishing：输入结束，等待最终解析"
    case .displayingFinalContent:
      return "displayingFinalContent：等待显示追赶最终内容"
    case .finished:
      return "finished：已提升为终态块级视图"
    case .cancelled:
      return "cancelled：会话已取消"
    }
  }

  // MARK: - Actions

  func sendRealPrompt(config: LLMConfiguration) {
    let prompt = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !prompt.isEmpty else { return }

    if !config.isMock && config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      showingConfigSheet = true
      return
    }

    cancelStreaming()
    session.reset()
    errorMessage = nil
    isLoading = true
    nextChunkIndex = 0

    OpenAISSEService.shared.askStream(
      question: prompt,
      config: config,
      onChunk: { [weak self] chunk in
        self?.session.append(chunk)
      },
      onComplete: { [weak self] in
        self?.isLoading = false
        self?.session.finish()
      },
      onError: { [weak self] error in
        self?.isLoading = false
        self?.errorMessage = error.localizedDescription
        self?.session.cancel()
      }
    )
  }

  func finishStreaming() {
    guard canFinish else { return }
    session.finish()
  }

  func appendNextMockChunk() {
    guard canAppendMock else { return }
    errorMessage = nil
    session.append(localMockChunks[nextChunkIndex])
    nextChunkIndex += 1
  }

  func cancelStreaming() {
    OpenAISSEService.shared.cancel()
    isLoading = false
    session.cancel()
  }

  func resetSession() {
    cancelStreaming()
    errorMessage = nil
    session.reset()
    nextChunkIndex = 0
  }

  func onDisappear() {
    cancelStreaming()
  }
}
