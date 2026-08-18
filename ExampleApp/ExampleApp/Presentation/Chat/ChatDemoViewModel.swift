//
//  ChatDemoViewModel.swift
//  ExampleApp
//

import Combine
import Foundation
import InkMarkdown
import InkMarkdownSwiftUI
import UIKit

/// SwiftUI / UIKit Chat Demo 的 MVVM 状态机：单条 `InkMarkdownRenderSession` 驱动流式气泡。
@MainActor
final class ChatDemoViewModel: ObservableObject {

    struct ChatMessage: Identifiable {
        let id = UUID()
        let isUser: Bool
        var content: String
        var isStreaming: Bool
    }

    @Published private(set) var messages: [ChatMessage] = []
    @Published var inputPrompt: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published var showingConfigSheet: Bool = false
    /// 流式 append 时发出，供 UIKit 触发 cell 高度重算（不修改 messages，SwiftUI 不订阅）。
    let streamDisplayPulse = PassthroughSubject<Void, Never>()

    /// 当前活跃流式渲染会话（全局唯一）；每次发送前按 trait 重建。
    private(set) var session: InkMarkdownRenderSession

    /// 与 session 同步的 Chat Demo 配置快照，供终态 `InkMarkdownView` 复用。
    var chatConfiguration: InkConfiguration {
        session.configuration
    }

    private var streamingAssistantIndex: Int?
    private var promotionCancellable: AnyCancellable?
    private var userInterfaceStyle: UIUserInterfaceStyle

    init(userInterfaceStyle: UIUserInterfaceStyle = UITraitCollection.current.userInterfaceStyle) {
        self.userInterfaceStyle = userInterfaceStyle
        self.session = InkMarkdownRenderSession(
            configuration: DemoInkConfigurationBuilder.makeChatConfiguration(userInterfaceStyle: userInterfaceStyle)
        )
    }

    // MARK: - Actions

    func sendMessage(_ prompt: String, config: LLMConfiguration) {
        let question = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        inputPrompt = ""

        if !config.isMock && config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showingConfigSheet = true
            return
        }

        cancelActiveStream()
        recreateSession()
        isLoading = true

        messages.append(ChatMessage(isUser: true, content: question, isStreaming: false))
        messages.append(ChatMessage(isUser: false, content: "", isStreaming: true))
        streamingAssistantIndex = messages.count - 1

        OpenAISSEService.shared.askStream(
            question: question,
            config: config,
            onChunk: { [weak self] chunk in
                self?.session.append(chunk)
                self?.streamDisplayPulse.send()
            },
            onComplete: { [weak self] in
                self?.handleStreamComplete()
            },
            onError: { [weak self] error in
                self?.handleStreamError(error)
            }
        )
    }

    func cancelActiveStream() {
        promotionCancellable?.cancel()
        promotionCancellable = nil

        OpenAISSEService.shared.cancel()
        session.cancel()
        isLoading = false

        if let idx = streamingAssistantIndex, idx < messages.count, messages[idx].isStreaming {
            let partial = session.currentText
            if !partial.isEmpty {
                messages[idx].content = partial
            }
            messages[idx].isStreaming = false
        }
        streamingAssistantIndex = nil
    }

    func onDisappear() {
        cancelActiveStream()
    }

    func updateUserInterfaceStyle(_ style: UIUserInterfaceStyle) {
        guard style != userInterfaceStyle else { return }
        userInterfaceStyle = style

        // 流式阶段由 `InkStreamMarkdownView` 通过 SwiftUI colorScheme 更新 renderEnvironment。
        if session.state == .idle || session.state == .cancelled || session.state == .finished {
            recreateSession()
        }
    }

    /// 当前正在流式输出的 assistant 消息 id（供 View 绑定 `InkStreamMarkdownView`）。
    var activeStreamingMessageID: UUID? {
        guard let idx = streamingAssistantIndex, idx < messages.count else { return nil }
        let msg = messages[idx]
        return msg.isStreaming ? msg.id : nil
    }

    // MARK: - Private

    private func recreateSession() {
        promotionCancellable?.cancel()
        promotionCancellable = nil
        session = InkMarkdownRenderSession(
            configuration: DemoInkConfigurationBuilder.makeChatConfiguration(userInterfaceStyle: userInterfaceStyle)
        )
    }

    private func handleStreamComplete() {
        session.finish()
        isLoading = false

        guard let idx = streamingAssistantIndex, idx < messages.count else { return }

        if session.isPromoted {
            finalizePromotedMessage(at: idx)
            return
        }

        promotionCancellable?.cancel()
        promotionCancellable = session.$isPromoted
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.finalizePromotedMessage(at: idx)
            }
    }

    private func finalizePromotedMessage(at idx: Int) {
        promotionCancellable?.cancel()
        promotionCancellable = nil

        guard idx < messages.count, messages[idx].isStreaming else { return }
        messages[idx].content = session.currentText
        messages[idx].isStreaming = false
        streamingAssistantIndex = nil
    }

    private func handleStreamError(_ error: LLMStreamError) {
        promotionCancellable?.cancel()
        promotionCancellable = nil

        session.cancel()
        isLoading = false

        guard let idx = streamingAssistantIndex, idx < messages.count else { return }
        messages[idx].content = "⚠️ **请求失败**\n\n\(error.localizedDescription)"
        messages[idx].isStreaming = false
        streamingAssistantIndex = nil
    }
}
