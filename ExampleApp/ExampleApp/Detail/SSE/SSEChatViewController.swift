import UIKit
import InkMarkdown
import Markdown

/// 演示「服务端 SSE 流式返回 Markdown → UIKit 逐字吐字渲染」全流程。
///
/// 公式与图表：任意回答全局开启 LaTeX + Mermaid（`$...$` 关闭）；
/// 行内随分片露出，块级围栏/公式闭合后立即异步生图，无需等待 `[DONE]`。
final class SSEChatViewController: UIViewController {

    /// 单条消息。
    private struct Message {
        let isUser: Bool
        var content: String
        var isStreaming: Bool
    }

    private var messages: [Message] = []
    private var isLoading = false

    private lazy var tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.backgroundColor = .clear
        t.separatorStyle = .none
        t.delegate = self
        t.dataSource = self
        t.keyboardDismissMode = .onDrag
        t.estimatedRowHeight = 60
        t.rowHeight = UITableView.automaticDimension
        t.register(SSEUserCell.self, forCellReuseIdentifier: SSEUserCell.id)
        t.register(SSEAssistantCell.self, forCellReuseIdentifier: SSEAssistantCell.id)
        return t
    }()

    private let inputContainer = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private var inputBottom: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "SSE 流式吐字"
        setupUI()
        setupKeyboard()
        seedSuggestion()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        // 主题变化：重建非流式 assistant 气泡，使 Mermaid theme 跟随。
        for (row, msg) in messages.enumerated() where !msg.isUser && !msg.isStreaming && !msg.content.isEmpty {
            if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? SSEAssistantCell {
                cell.reapplyTheme(content: msg.content, userInterfaceStyle: traitCollection.userInterfaceStyle)
            }
        }
    }

    // MARK: - UI

    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(inputContainer)

        inputContainer.backgroundColor = .secondarySystemBackground
        inputContainer.addSubview(textField)
        inputContainer.addSubview(sendButton)

        textField.borderStyle = .roundedRect
        textField.backgroundColor = .systemBackground
        textField.placeholder = "问点什么，试试「展示公式与图表」或「展示图文混排」"
        textField.returnKeyType = .send
        textField.delegate = self
        textField.font = .systemFont(ofSize: 16)

        sendButton.setTitle("发送", for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false

        let inputBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        inputBottom = inputBottomConstraint

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),

            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBottomConstraint,
            inputContainer.heightAnchor.constraint(equalToConstant: 56),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 48),

            textField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    /// 预填公式与图表示例问题，降低 demo 上手成本。
    private func seedSuggestion() {
        textField.text = "展示公式与图表"
    }

    private func setupKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - 发送

    @objc private func handleSend() {
        guard !isLoading, let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        textField.text = nil
        sendQuestion(text)
    }

    private func sendQuestion(_ question: String) {
        messages.append(Message(isUser: true, content: question, isStreaming: false))
        messages.append(Message(isUser: false, content: "", isStreaming: true))
        tableView.reloadData()
        scrollToBottom(animated: true)

        isLoading = true
        sendButton.isEnabled = false

        MockSSEService.shared.askStream(
            question: question,
            onChunk: { [weak self] chunk in
                guard let self else { return }
                guard let idx = self.messages.lastIndex(where: { !$0.isUser }) else { return }
                self.messages[idx].content += chunk
                let content = self.messages[idx].content
                if let cell = self.tableView.cellForRow(at: IndexPath(row: idx, section: 0)) as? SSEAssistantCell {
                    cell.applyStreamingContent(
                        content,
                        userInterfaceStyle: self.traitCollection.userInterfaceStyle
                    )
                } else {
                    self.requestCellHeightUpdate()
                }
            },
            onComplete: { [weak self] in
                guard let self else { return }
                self.isLoading = false
                self.sendButton.isEnabled = true
                guard let idx = self.messages.lastIndex(where: { !$0.isUser }) else { return }
                let full = self.messages[idx].content
                if let cell = self.tableView.cellForRow(at: IndexPath(row: idx, section: 0)) as? SSEAssistantCell {
                    cell.finishStreaming(
                        fullContent: full,
                        userInterfaceStyle: self.traitCollection.userInterfaceStyle
                    ) { [weak self] in
                        guard let self, idx < self.messages.count else { return }
                        self.messages[idx].isStreaming = false
                    }
                } else {
                    self.messages[idx].isStreaming = false
                    self.tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
                }
            }
        )
    }

    private var heightUpdateScheduled = false
    /// 重新计算 cell 高度，但不触发 reloadRows（避免流式过程中 cell 重建）。
    private func requestCellHeightUpdate() {
        guard !heightUpdateScheduled else { return }
        heightUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.heightUpdateScheduled = false
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            self.scrollToBottom(animated: false)
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.layoutIfNeeded()
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    // MARK: - 键盘

    @objc private func keyboardWillChange(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let inset = frame.height - view.safeAreaInsets.bottom
        inputBottom?.constant = -max(inset, 0)
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
            if !self.messages.isEmpty { self.scrollToBottom(animated: false) }
        }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        inputBottom?.constant = 0
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    deinit {
        MockSSEService.shared.cancel()
    }
}

// MARK: - UITextFieldDelegate

extension SSEChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        handleSend()
        return true
    }
}

// MARK: - UITableView

extension SSEChatViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = messages[indexPath.row]
        if msg.isUser {
            let cell = tableView.dequeueReusableCell(withIdentifier: SSEUserCell.id, for: indexPath) as! SSEUserCell
            cell.configure(content: msg.content)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: SSEAssistantCell.id, for: indexPath) as! SSEAssistantCell
            cell.presentingViewController = self
            cell.onHeightChange = { [weak self] in
                self?.requestCellHeightUpdate()
            }
            cell.configure(
                content: msg.content,
                isStreaming: msg.isStreaming,
                userInterfaceStyle: traitCollection.userInterfaceStyle
            )
            return cell
        }
    }
}

// MARK: - 用户消息气泡

private final class SSEUserCell: UITableViewCell {
    static let id = "SSEUserCell"
    private let bubbleView = UIView()
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        bubbleView.backgroundColor = .systemBlue
        bubbleView.layer.cornerRadius = 12
        bubbleView.layer.cornerCurve = .continuous
        bubbleView.layer.masksToBounds = true
        label.textColor = .white
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(label)
        NSLayoutConstraint.activate([
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 40),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(content: String) {
        label.text = content
    }
}

// MARK: - AI 消息气泡（流式增量 + 单块闭合即渲染）
//
// Demo 层流式策略（对齐 ADR-007）：未闭合 Mermaid 围栏或块级 `$$` / `\\[...\\]` 的尾部
// 不参与 generated 生图，仅作源码/代码块展示；围栏真正闭合后才立即 flush 并复用 canonicalID。
private final class SSEAssistantCell: UITableViewCell {
    static let id = "SSEAssistantCell"

    weak var presentingViewController: UIViewController?

    private let bubbleView = UIView()
    private let stackView = UIStackView()
    private let thinkingLabel = UILabel()
    private var isShowingThinking = false

    private var segments: [SSETypewriterSegment] = []
    /// 按 ImageSource.canonicalID 复用生成图 / 网络图宿主，避免 chunk 重建时销毁 WebKit / 重载。
    private var reusableGeneratedHosts: [String: GeneratedContentImageHostView] = [:]
    private var reusableNetworkImages: [String: SSEImageSegmentView] = [:]
    /// 按 ImageSource.canonicalID 复用行内公式，避免 chunk 刷新时重新生成。
    private var reusableInlineAttachments: [String: InkImageAttachment] = [:]
    /// 按顺序复用文本段，避免流式 rebuild 销毁已 materialize 的行内 attachment（D1）。
    private var reusableTextSegments: [SSETextSegmentView] = []
    private var failureObserver = GeneratedContentFailureObserver()

    var onHeightChange: (() -> Void)?
    private var lastAppliedMarkdown: String = ""
    private var rebuildWorkItem: DispatchWorkItem?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        bubbleView.backgroundColor = .secondarySystemBackground
        bubbleView.layer.cornerRadius = 12
        bubbleView.layer.cornerCurve = .continuous
        bubbleView.layer.masksToBounds = true

        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.alignment = .fill

        thinkingLabel.text = "思考中…"
        thinkingLabel.font = .systemFont(ofSize: 16)
        thinkingLabel.textColor = .secondaryLabel

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(stackView)
        stackView.addArrangedSubview(thinkingLabel)

        NSLayoutConstraint.activate([
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -40),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            stackView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 14),
            stackView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -14),
            stackView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(content: String, isStreaming: Bool, userInterfaceStyle: UIUserInterfaceStyle) {
        rebuildWorkItem?.cancel()
        if content.isEmpty && isStreaming {
            clearSegmentsKeepingReuseCaches(false)
            showThinking()
            lastAppliedMarkdown = ""
        } else if content.isEmpty {
            hideThinking()
            clearSegmentsKeepingReuseCaches(false)
            lastAppliedMarkdown = ""
        } else {
            hideThinking()
            rebuildSegments(from: content, userInterfaceStyle: userInterfaceStyle, revealAll: true)
            lastAppliedMarkdown = content
        }
    }

    /// 流式分片到达：增量重建；已闭合的 generated 块复用宿主并保持异步渲染。
    func applyStreamingContent(
        _ markdown: String,
        userInterfaceStyle: UIUserInterfaceStyle
    ) {
        hideThinking()

        // 节流：避免每个 2 字符 chunk 全量重解析；围栏闭合字符触发立即刷新。
        let shouldFlushImmediately = Self.looksLikeBlockJustClosed(previous: lastAppliedMarkdown, current: markdown)
        rebuildWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.rebuildSegments(from: markdown, userInterfaceStyle: userInterfaceStyle, revealAll: true)
            self.lastAppliedMarkdown = markdown
            self.onHeightChange?()
        }
        rebuildWorkItem = work
        if shouldFlushImmediately {
            DispatchQueue.main.async(execute: work)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }
    }

    /// 流结束：最终全量对齐一次。
    func finishStreaming(
        fullContent: String,
        userInterfaceStyle: UIUserInterfaceStyle,
        completion: @escaping () -> Void
    ) {
        rebuildWorkItem?.cancel()
        hideThinking()
        rebuildSegments(from: fullContent, userInterfaceStyle: userInterfaceStyle, revealAll: true)
        lastAppliedMarkdown = fullContent
        onHeightChange?()
        completion()
    }

    func reapplyTheme(content: String, userInterfaceStyle: UIUserInterfaceStyle) {
        // 主题切换需重建 generated 宿主（theme 进入 identity）。
        clearSegmentsKeepingReuseCaches(false)
        rebuildSegments(from: content, userInterfaceStyle: userInterfaceStyle, revealAll: true)
        lastAppliedMarkdown = content
    }

    private func rebuildSegments(
        from markdown: String,
        userInterfaceStyle: UIUserInterfaceStyle,
        revealAll: Bool
    ) {
        for seg in segments {
            stackView.removeArrangedSubview(seg)
            seg.removeFromSuperview()
        }
        segments = []

        guard !markdown.isEmpty else { return }

        let built = Self.buildSegments(
            from: markdown,
            userInterfaceStyle: userInterfaceStyle,
            presentingViewController: { [weak self] in self?.presentingViewController },
            failureObserver: failureObserver,
            reusableGenerated: &reusableGeneratedHosts,
            reusableNetwork: &reusableNetworkImages,
            reusableInline: &reusableInlineAttachments,
            reusableText: &reusableTextSegments
        )
        segments = built
        for seg in segments {
            wireHeightChange(for: seg)
            stackView.addArrangedSubview(seg)
            if revealAll {
                seg.setVisibleLength(seg.typewriterLength)
            }
        }
    }

    private func wireHeightChange(for seg: SSETypewriterSegment) {
        let callback: () -> Void = { [weak self] in self?.onHeightChange?() }
        if let textSeg = seg as? SSETextSegmentView {
            textSeg.onHeightChange = callback
        } else if let host = seg as? GeneratedContentImageHostView {
            host.onHeightChange = callback
        } else if let imgSeg = seg as? SSEImageSegmentView {
            imgSeg.onHeightChange = callback
        }
    }

    private func clearSegmentsKeepingReuseCaches(_ keep: Bool) {
        for seg in segments {
            stackView.removeArrangedSubview(seg)
            seg.removeFromSuperview()
        }
        segments = []
        if !keep {
            reusableGeneratedHosts.removeAll()
            reusableNetworkImages.removeAll()
            reusableInlineAttachments.removeAll()
            reusableTextSegments.removeAll()
            failureObserver = GeneratedContentFailureObserver()
        }
    }

    /// Markdown → 片段：全局开启公式与图表；generated 块按 canonicalID 增量复用。
    private static func buildSegments(
        from markdown: String,
        userInterfaceStyle: UIUserInterfaceStyle,
        presentingViewController: @escaping () -> UIViewController?,
        failureObserver: GeneratedContentFailureObserver,
        reusableGenerated: inout [String: GeneratedContentImageHostView],
        reusableNetwork: inout [String: SSEImageSegmentView],
        reusableInline: inout [String: InkImageAttachment],
        reusableText: inout [SSETextSegmentView]
    ) -> [SSETypewriterSegment] {
        var config = InkConfiguration.demoGeneratedContent(
            mode: .diagrams,
            userInterfaceStyle: userInterfaceStyle,
            allowsInlineDollarDelimiter: false
        )
        // 图文混排路径仍开启网络图。
        config.appearance.imageRendering.isEnabled = true
        config.appearance.imageRendering.promotesToBlock = true
        config.appearance.imageRendering.securityPolicy.emptyHostPolicy = .allowAll
        config.appearance.enableDemoBlockImageTap(presentingViewController: presentingViewController)
        failureObserver.attach(to: &config.appearance)

        config.blockHandlers = [SSECodeBlockHandler(), SSETableBlockHandler()]

        let (stableMarkdown, trailingMarkdown) = Self.partitionForStreamingRender(markdown)
        var result: [SSETypewriterSegment] = []
        var nextGenerated: [String: GeneratedContentImageHostView] = [:]
        var nextNetwork: [String: SSEImageSegmentView] = [:]
        var nextText: [SSETextSegmentView] = []

        appendBlocks(
            from: stableMarkdown,
            configuration: config,
            failureObserver: failureObserver,
            reusableGenerated: &reusableGenerated,
            reusableNetwork: &reusableNetwork,
            reusableInline: &reusableInline,
            reusableText: &reusableText,
            nextGenerated: &nextGenerated,
            nextNetwork: &nextNetwork,
            nextText: &nextText,
            into: &result
        )

        if !trailingMarkdown.isEmpty {
            var trailingConfig = InkConfiguration.demoGeneratedContent(
                mode: .disabled,
                userInterfaceStyle: userInterfaceStyle
            )
            trailingConfig.appearance.imageRendering = config.appearance.imageRendering
            trailingConfig.appearance.enableDemoBlockImageTap(presentingViewController: presentingViewController)
            trailingConfig.blockHandlers = config.blockHandlers
            appendBlocks(
                from: trailingMarkdown,
                configuration: trailingConfig,
                failureObserver: failureObserver,
                reusableGenerated: &reusableGenerated,
                reusableNetwork: &reusableNetwork,
                reusableInline: &reusableInline,
                reusableText: &reusableText,
                nextGenerated: &nextGenerated,
                nextNetwork: &nextNetwork,
                nextText: &nextText,
                into: &result
            )
        }

        reusableGenerated = nextGenerated
        reusableNetwork = nextNetwork
        reusableText = nextText
        return result
    }

    private static func appendBlocks(
        from markdown: String,
        configuration: InkConfiguration,
        failureObserver: GeneratedContentFailureObserver,
        reusableGenerated: inout [String: GeneratedContentImageHostView],
        reusableNetwork: inout [String: SSEImageSegmentView],
        reusableInline: inout [String: InkImageAttachment],
        reusableText: inout [SSETextSegmentView],
        nextGenerated: inout [String: GeneratedContentImageHostView],
        nextNetwork: inout [String: SSEImageSegmentView],
        nextText: inout [SSETextSegmentView],
        into result: inout [SSETypewriterSegment]
    ) {
        let blocks = InkBlockRenderer.render(markdown, configuration: configuration)
        var textIndex = 0
        for block in blocks {
            if let imageBlock = block as? InkImageBlock, imageBlock.source.scheme == .generated {
                let id = imageBlock.source.canonicalID
                if let existing = reusableGenerated[id] {
                    failureObserver.register(existing)
                    result.append(existing)
                    nextGenerated[id] = existing
                } else if let host = failureObserver.makeSegment(for: block) as? GeneratedContentImageHostView {
                    result.append(host)
                    nextGenerated[id] = host
                }
            } else if let imageBlock = block as? InkImageBlock {
                let id = imageBlock.source.canonicalID
                if let existing = reusableNetwork[id] {
                    result.append(existing)
                    nextNetwork[id] = existing
                } else {
                    let seg = SSEImageSegmentView(imageBlock: imageBlock)
                    result.append(seg)
                    nextNetwork[id] = seg
                }
            } else if let textBlock = block as? InkAttributedTextBlock {
                let mutableAttr = NSMutableAttributedString(attributedString: textBlock.attributedText)
                mutableAttr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: mutableAttr.length), options: []) { value, range, _ in
                    if let attachment = value as? InkImageAttachment {
                        let id = attachment.source.canonicalID
                        if let existing = reusableInline[id] {
                            mutableAttr.addAttribute(.attachment, value: existing, range: range)
                        } else {
                            reusableInline[id] = attachment
                        }
                    }
                }
                
                let seg: SSETextSegmentView
                if textIndex < reusableText.count {
                    seg = reusableText[textIndex]
                    seg.updateFullText(mutableAttr)
                } else {
                    seg = SSETextSegmentView(attributedText: mutableAttr)
                }
                result.append(seg)
                nextText.append(seg)
                textIndex += 1
            } else if let seg = block.makeView() as? SSETypewriterSegment {
                result.append(seg)
            }
        }
    }

    /// 未闭合 generated 块（Mermaid 围栏 / 块级 `$$` / `\\[...\\]`）之前的稳定前缀可立即生图；尾部降级为普通块。
    private static func partitionForStreamingRender(_ markdown: String) -> (stable: String, trailing: String) {
        if let fenceStart = startOfUnclosedMermaidFence(in: markdown) {
            return (String(markdown[..<fenceStart]), String(markdown[fenceStart...]))
        }
        if let dollarStart = startOfUnclosedBlockDollar(in: markdown) {
            return (String(markdown[..<dollarStart]), String(markdown[dollarStart...]))
        }
        if let bracketStart = startOfUnclosedBlockBrackets(in: markdown) {
            return (String(markdown[..<bracketStart]), String(markdown[bracketStart...]))
        }
        return (markdown, "")
    }

    /// 仅当本次增量使未闭合 generated 块归零时才立即 flush；单纯打开围栏不算闭合。
    private static func looksLikeBlockJustClosed(previous: String, current: String) -> Bool {
        guard current.count > previous.count else { return false }
        if hasUnclosedMermaidFence(previous) && !hasUnclosedMermaidFence(current) { return true }
        if hasUnclosedBlockDollar(previous) && !hasUnclosedBlockDollar(current) { return true }
        if hasUnclosedBlockBrackets(previous) && !hasUnclosedBlockBrackets(current) { return true }
        return false
    }

    private struct FenceMarker {
        let character: Character
        let count: Int
    }

    private static func hasUnclosedMermaidFence(_ source: String) -> Bool {
        startOfUnclosedMermaidFence(in: source) != nil
    }

    private static func startOfUnclosedMermaidFence(in source: String) -> String.Index? {
        var fence: FenceMarker?
        var openingLineStart: String.Index?
        var lineStart = source.startIndex

        while lineStart < source.endIndex {
            let lineEnd = source[lineStart...].firstIndex(of: "\n") ?? source.endIndex
            let line = source[lineStart..<lineEnd]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if let open = fence {
                if let closing = closingCodeFenceMarker(in: trimmed),
                   closing.character == open.character,
                   closing.count >= open.count {
                    fence = nil
                    openingLineStart = nil
                }
            } else if let opening = openingCodeFenceMarker(in: trimmed) {
                let language = trimmed.dropFirst(opening.count).trimmingCharacters(in: .whitespacesAndNewlines)
                if InkMermaidFence.isMermaid(language: String(language)) {
                    fence = opening
                    openingLineStart = lineStart
                }
            }

            if lineEnd < source.endIndex {
                lineStart = source.index(after: lineEnd)
            } else {
                break
            }
        }

        return fence != nil ? openingLineStart : nil
    }

    private static func hasUnclosedBlockDollar(_ source: String) -> Bool {
        startOfUnclosedBlockDollar(in: source) != nil
    }

    private static func startOfUnclosedBlockDollar(in source: String) -> String.Index? {
        var open = false
        var openingIndex: String.Index?
        var index = source.startIndex
        while index < source.endIndex {
            if source[index...].hasPrefix("$$"), !isEscaped(source, at: index) {
                if open {
                    open = false
                    openingIndex = nil
                } else {
                    open = true
                    openingIndex = index
                }
                index = source.index(index, offsetBy: 2)
                continue
            }
            index = source.index(after: index)
        }
        return open ? openingIndex : nil
    }

    private static func hasUnclosedBlockBrackets(_ source: String) -> Bool {
        startOfUnclosedBlockBrackets(in: source) != nil
    }

    private static func startOfUnclosedBlockBrackets(in source: String) -> String.Index? {
        var open = false
        var openingIndex: String.Index?
        var index = source.startIndex
        while index < source.endIndex {
            if source[index...].hasPrefix("\\["), !isEscaped(source, at: index) {
                open = true
                openingIndex = index
                index = source.index(index, offsetBy: 2)
                continue
            }
            if source[index...].hasPrefix("\\]"), !isEscaped(source, at: index), open {
                open = false
                openingIndex = nil
                index = source.index(index, offsetBy: 2)
                continue
            }
            index = source.index(after: index)
        }
        return open ? openingIndex : nil
    }

    private static func openingCodeFenceMarker(in trimmedLine: String) -> FenceMarker? {
        guard let first = trimmedLine.first, first == "`" || first == "~" else { return nil }
        let count = trimmedLine.prefix(while: { $0 == first }).count
        guard count >= 3 else { return nil }
        return FenceMarker(character: first, count: count)
    }

    private static func closingCodeFenceMarker(in trimmedLine: String) -> FenceMarker? {
        guard let marker = openingCodeFenceMarker(in: trimmedLine) else { return nil }
        guard trimmedLine.dropFirst(marker.count).isEmpty else { return nil }
        return marker
    }

    private static func isEscaped(_ source: String, at index: String.Index) -> Bool {
        var slashCount = 0
        var cursor = index
        while cursor > source.startIndex {
            let previous = source.index(before: cursor)
            guard source[previous] == "\\" else { break }
            slashCount += 1
            cursor = previous
        }
        return !slashCount.isMultiple(of: 2)
    }

    // MARK: - 思考中动画

    private func showThinking() {
        thinkingLabel.isHidden = false
        guard !isShowingThinking else { return }
        isShowingThinking = true
        thinkingLabel.alpha = 0
        UIView.animate(withDuration: 0.3) { self.thinkingLabel.alpha = 1 }
        UIView.animate(withDuration: 0.8, delay: 0.2, options: [.autoreverse, .repeat, .curveEaseInOut]) {
            self.thinkingLabel.alpha = 0.3
        }
    }

    private func hideThinking() {
        if isShowingThinking {
            isShowingThinking = false
            thinkingLabel.layer.removeAllAnimations()
        }
        thinkingLabel.alpha = 1
        thinkingLabel.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rebuildWorkItem?.cancel()
        onHeightChange = nil
        thinkingLabel.layer.removeAllAnimations()
        isShowingThinking = false
        thinkingLabel.isHidden = true
        thinkingLabel.alpha = 1
        clearSegmentsKeepingReuseCaches(false)
        lastAppliedMarkdown = ""
    }
}

// MARK: - SSE Block Handlers

private struct SSECodeBlockHandler: InkBlockHandler {
    func canHandle(_ markup: Markup) -> Bool {
        guard let code = markup as? Markdown.CodeBlock else { return false }
        // Mermaid 由库侧 InkMermaidBlockHandler 优先接管；此处只处理普通代码块。
        return !InkMermaidFence.isMermaid(language: code.language)
    }

    func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
        guard let codeBlock = markup as? Markdown.CodeBlock else { return nil }
        return CodeBlockCardBlock(code: codeBlock.code, language: codeBlock.language)
    }
}

private struct SSETableBlockHandler: InkBlockHandler {
    func canHandle(_ markup: Markup) -> Bool {
        markup is Markdown.Table
    }

    func makeBlock(from markup: Markup, configuration: InkConfiguration) -> InkRenderableBlock? {
        guard let table = markup as? Markdown.Table else { return nil }
        let headCells = Array(table.head.cells)
        let headers = headCells.map { $0.plainText }
        let bodyRows = Array(table.body.rows)
        let rows = bodyRows.map { row in Array(row.cells).map { $0.plainText } }
        return SSETableBlock(headers: headers, rows: rows, alignments: table.columnAlignments, layoutMode: .scroll, configuration: configuration)
    }
}
