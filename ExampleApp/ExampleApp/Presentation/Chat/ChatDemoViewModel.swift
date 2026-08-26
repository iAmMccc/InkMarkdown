//
//  ChatDemoViewModel.swift
//  ExampleApp
//

import Combine
import Foundation
import InkMarkdown
import InkMarkdownSwiftUI
import UIKit

/// SwiftUI / UIKit Chat Demo 的 MVVM 状态机：每条 assistant 消息持有独立 `InkMarkdownRenderSession`。
@MainActor
final class ChatDemoViewModel: ObservableObject {

    struct ChatMessage: Identifiable {
        let id = UUID()
        let isUser: Bool
        /// 纯文本快照；错误/取消回退或用户消息正文。
        var content: String
        /// 已完成 assistant 消息的渲染会话（含 promotion 后 blocks 与折叠态 SSOT）。
        var renderSession: InkMarkdownRenderSession?
        var isStreaming: Bool
    }

    @Published private(set) var messages: [ChatMessage] = []
    @Published var inputPrompt: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published var showingConfigSheet: Bool = false
    /// 流式显示尺寸变化时发出，供 UIKit 触发 cell 高度重算 / SwiftUI scrollTo（不修改 messages，不驱动换树）。
    let streamDisplayPulse = PassthroughSubject<Void, Never>()

    /// Chat 滚动策略（SwiftUI / UIKit 共用同一实例）。
    private(set) var scrollPolicy = ChatScrollPolicy()

    /// 当前活跃流式渲染会话；promotion 完成后转移到 `messages[].renderSession`，此处重建供下一条使用。
    private(set) var session: InkMarkdownRenderSession

    /// 与 session 同步的 Chat Demo 配置快照，供无 session 回退路径复用。
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
        bindSessionDisplayCallback()
    }

    // MARK: - Scroll Policy

    func handleScrollDragBegan() {
        scrollPolicy.dragBegan()
        session.isDisplayPaused = scrollPolicy.shouldPauseDisplay
    }

    func handleScrollDragEnded(distanceFromBottom: CGFloat, isDecelerating: Bool) {
        scrollPolicy.dragEnded(distanceFromBottom: distanceFromBottom, isDecelerating: isDecelerating)
        session.isDisplayPaused = scrollPolicy.shouldPauseDisplay
    }

    func handleScrollDecelerationEnded(distanceFromBottom: CGFloat) {
        scrollPolicy.decelerationEnded(distanceFromBottom: distanceFromBottom)
        session.isDisplayPaused = scrollPolicy.shouldPauseDisplay
    }

    func handleScrollOffsetChanged(distanceFromBottom: CGFloat, isDragging: Bool) {
        scrollPolicy.offsetChanged(distanceFromBottom: distanceFromBottom, isDragging: isDragging)
        session.isDisplayPaused = scrollPolicy.shouldPauseDisplay
    }

    func handleContentGrew() {
        scrollPolicy.contentGrew()
    }

    /// 是否应自动滚动到底部（薄 relay，唯一谓词在 `ChatScrollPolicy.shouldAutoScroll`）。
    func shouldAutoScroll() -> Bool {
        scrollPolicy.shouldAutoScroll
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

        messages.append(ChatMessage(isUser: true, content: question, renderSession: nil, isStreaming: false))
        messages.append(ChatMessage(isUser: false, content: "", renderSession: nil, isStreaming: true))
        streamingAssistantIndex = messages.count - 1
        scrollPolicy = ChatScrollPolicy()
        scrollPolicy.messagesCountChanged()

        OpenAISSEService.shared.askStream(
            question: question,
            config: config,
            onChunk: { [weak self] chunk in
                guard let self = self else { return }
                self.session.append(chunk)
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
            // cancel() 清空 streamingThought；无 session 转移，回退 InkMarkdownView 静态渲染。
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

        let environment = InkRenderEnvironment(
            userInterfaceStyle: style == .dark ? .dark : .light
        )

        for index in messages.indices {
            messages[index].renderSession?.updateRenderEnvironment(environment)
        }

        if session.state == .idle || session.state == .cancelled || session.state == .finished {
            recreateSession()
        } else {
            session.updateRenderEnvironment(environment)
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
        bindSessionDisplayCallback()
    }

    private func bindSessionDisplayCallback() {
        session.onDisplayUpdate = { [weak self] in
            guard let self else { return }
            self.handleContentGrew()
            self.streamDisplayPulse.send()
        }
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
        session.syncStreamingThoughtCollapseIntoBlocks()
        messages[idx].content = session.currentText
        messages[idx].renderSession = session
        messages[idx].isStreaming = false
        streamingAssistantIndex = nil
        recreateSession()
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
