import Combine
import UIKit
import SwiftUI
import InkMarkdown
import InkMarkdownSwiftUI

/// 演示「服务端 SSE 流式返回 Markdown → UIKit 逐字吐字渲染」全流程。
///
/// 与 SwiftUI Chat 共用 `ChatDemoViewModel` 作为状态机 SSOT；assistant 气泡由
/// `UIHostingController` 承载 `InkStreamMarkdownView` / `InkMarkdownView`。
final class SSEChatViewController: UIViewController {

    private let viewModel = ChatDemoViewModel()
    private var cancellables = Set<AnyCancellable>()

    private lazy var tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.backgroundColor = .clear
        t.separatorStyle = .none
        t.delegate = self
        t.dataSource = self
        t.keyboardDismissMode = .onDrag
        t.estimatedRowHeight = 200
        t.rowHeight = UITableView.automaticDimension
        t.register(SSEUserCell.self, forCellReuseIdentifier: SSEUserCell.id)
        t.register(SSEAssistantCell.self, forCellReuseIdentifier: SSEAssistantCell.id)
        return t
    }()

    private let inputContainer = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private var inputBottom: NSLayoutConstraint?

    private let suggestionsScrollView = UIScrollView()
    private let suggestionsStackView = UIStackView()

    private var heightUpdateScheduled = false
    private var lastHeightUpdateTime: CFTimeInterval = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupKeyboard()
        setupBindings()
        seedSuggestion()
        setupNavButtons()
        updateNavTitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavTitle()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            viewModel.onDisappear()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        viewModel.updateUserInterfaceStyle(traitCollection.userInterfaceStyle)
        tableView.reloadData()
    }

    private func setupNavButtons() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openConfigSettings)
        )
    }

    private func updateNavTitle() {
        let config = LLMConfigurationStore.shared.activeConfig
        title = "SSE: \(config.name)"
    }

    @objc private func openConfigSettings() {
        let hosting = UIHostingController(rootView: LLMConfigView())
        present(hosting, animated: true)
    }

    private func setupBindings() {
        viewModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.tableView.reloadData()
                self.scrollToBottom(animated: true)
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                self?.sendButton.isEnabled = !loading
            }
            .store(in: &cancellables)

        viewModel.$showingConfigSheet
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.viewModel.showingConfigSheet = false
                self.openConfigSettings()
            }
            .store(in: &cancellables)

        viewModel.streamDisplayPulse
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.requestCellHeightUpdate()
            }
            .store(in: &cancellables)
    }

    // MARK: - UI

    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(suggestionsScrollView)
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

        suggestionsScrollView.showsHorizontalScrollIndicator = false
        suggestionsScrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        suggestionsScrollView.addSubview(suggestionsStackView)

        suggestionsStackView.axis = .horizontal
        suggestionsStackView.spacing = 8
        suggestionsStackView.alignment = .center

        let suggestions = ["公式图表", "图文混排", "复杂表格", "代码示例", "列表说明"]
        for title in suggestions {
            var config = UIButton.Configuration.tinted()
            config.title = title
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            config.cornerStyle = .capsule
            let btn = UIButton(configuration: config)
            btn.addTarget(self, action: #selector(handleSuggestionTap(_:)), for: .touchUpInside)
            suggestionsStackView.addArrangedSubview(btn)
        }

        tableView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        suggestionsStackView.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false

        let inputBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        inputBottom = inputBottomConstraint

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: suggestionsScrollView.topAnchor, constant: -8),

            suggestionsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionsScrollView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor, constant: -8),
            suggestionsScrollView.heightAnchor.constraint(equalToConstant: 32),

            suggestionsStackView.topAnchor.constraint(equalTo: suggestionsScrollView.contentLayoutGuide.topAnchor),
            suggestionsStackView.bottomAnchor.constraint(equalTo: suggestionsScrollView.contentLayoutGuide.bottomAnchor),
            suggestionsStackView.leadingAnchor.constraint(equalTo: suggestionsScrollView.contentLayoutGuide.leadingAnchor),
            suggestionsStackView.trailingAnchor.constraint(equalTo: suggestionsScrollView.contentLayoutGuide.trailingAnchor),
            suggestionsStackView.heightAnchor.constraint(equalTo: suggestionsScrollView.frameLayoutGuide.heightAnchor),

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

    private func seedSuggestion() {
        textField.text = ""
    }

    private func setupKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - 发送

    @objc private func handleSend() {
        guard !viewModel.isLoading, let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        textField.text = nil
        sendQuestion(text)
    }

    @objc private func handleSuggestionTap(_ sender: UIButton) {
        guard !viewModel.isLoading, let title = sender.titleLabel?.text else { return }
        textField.text = nil
        sendQuestion(title)
    }

    private func sendQuestion(_ question: String) {
        viewModel.sendMessage(question, config: LLMConfigurationStore.shared.activeConfig)
    }

    private func requestCellHeightUpdate() {
        guard !heightUpdateScheduled else { return }
        heightUpdateScheduled = true

        let now = CACurrentMediaTime()
        let interval = now - lastHeightUpdateTime
        let minInterval: CFTimeInterval = 0.05

        if interval >= minInterval {
            lastHeightUpdateTime = now
            heightUpdateScheduled = false
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            tableView.beginUpdates()
            tableView.endUpdates()
            CATransaction.commit()
            scrollToBottom(animated: false)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + (minInterval - interval)) { [weak self] in
                guard let self else { return }
                self.lastHeightUpdateTime = CACurrentMediaTime()
                self.heightUpdateScheduled = false
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
                CATransaction.commit()
                self.scrollToBottom(animated: false)
            }
        }
    }

    private func scrollToBottom(animated: Bool) {
        let messages = viewModel.messages
        guard !messages.isEmpty else { return }
        let ip = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: ip, at: .bottom, animated: animated)
    }

    // MARK: - 键盘

    @objc private func keyboardWillChange(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let inset = frame.height - view.safeAreaInsets.bottom
        inputBottom?.constant = -max(inset, 0)
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
            if !self.viewModel.messages.isEmpty { self.scrollToBottom(animated: false) }
        }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        inputBottom?.constant = 0
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    deinit {
        OpenAISSEService.shared.cancel()
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
        viewModel.messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = viewModel.messages[indexPath.row]
        if msg.isUser {
            let cell = tableView.dequeueReusableCell(withIdentifier: SSEUserCell.id, for: indexPath) as! SSEUserCell
            cell.configure(content: msg.content)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: SSEAssistantCell.id, for: indexPath) as! SSEAssistantCell
            let isActiveStream = viewModel.activeStreamingMessageID == msg.id
            cell.configure(
                message: msg,
                session: isActiveStream ? viewModel.session : nil,
                configuration: viewModel.chatConfiguration,
                isActiveStream: isActiveStream,
                parent: self
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

// MARK: - AI 消息气泡（HostingController 承载 SwiftUI adapter）

private final class SSEAssistantCell: UITableViewCell {
    static let id = "SSEAssistantCell"

    private let bubbleView = UIView()
    private let thinkingLabel = UILabel()
    private var hostingController: UIHostingController<AnyView>?
    private var isShowingThinking = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        bubbleView.backgroundColor = .secondarySystemBackground
        bubbleView.layer.cornerRadius = 12
        bubbleView.layer.cornerCurve = .continuous
        bubbleView.layer.masksToBounds = true

        thinkingLabel.text = "思考中…"
        thinkingLabel.font = .systemFont(ofSize: 16)
        thinkingLabel.textColor = .secondaryLabel
        thinkingLabel.isHidden = true

        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        thinkingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(thinkingLabel)

        NSLayoutConstraint.activate([
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -40),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            thinkingLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 14),
            thinkingLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -14),
            thinkingLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            thinkingLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(
        message: ChatDemoViewModel.ChatMessage,
        session: InkMarkdownRenderSession?,
        configuration: InkConfiguration,
        isActiveStream: Bool,
        parent: UIViewController
    ) {
        if isActiveStream, let session {
            if message.content.isEmpty && session.currentText.isEmpty {
                removeHostingController()
                showThinking()
            } else {
                hideThinking()
                embed(
                    InkStreamMarkdownView(session: session),
                    parent: parent
                )
            }
        } else if message.content.isEmpty && message.isStreaming {
            removeHostingController()
            showThinking()
        } else {
            hideThinking()
            embed(
                InkMarkdownView(message.content, configuration: configuration),
                parent: parent
            )
        }
    }

    private func embed<V: View>(_ view: V, parent: UIViewController) {
        removeHostingController()

        let hosting = UIHostingController(rootView: AnyView(view))
        hosting.view.backgroundColor = .clear
        hostingController = hosting

        parent.addChild(hosting)
        bubbleView.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 14),
            hosting.view.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -14),
            hosting.view.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
            hosting.view.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
        ])
        hosting.didMove(toParent: parent)
    }

    private func removeHostingController() {
        guard let hosting = hostingController else { return }
        hosting.willMove(toParent: nil)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        hostingController = nil
    }

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
        hideThinking()
        removeHostingController()
    }
}
