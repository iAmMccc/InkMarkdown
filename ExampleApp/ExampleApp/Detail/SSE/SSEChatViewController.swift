import UIKit
import SnapKit
import InkMarkdown
import Markdown

/// 演示「服务端 SSE 流式返回 Markdown → UIKit 逐字吐字渲染」全流程。
///
/// 交互复刻 AI 问答场景：用户在底部输入框发送问题，AI 气泡先显示「思考中…」，
/// 流式攒完整段回答后，再用打字机效果逐字吐出（渲染走 `InkAttributedRenderer`）。
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
    private var inputBottom: Constraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "SSE 流式吐字"
        setupUI()
        setupKeyboard()
        seedSuggestion()
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
        textField.placeholder = "问点什么，试试「给个 swift 示例」"
        textField.returnKeyType = .send
        textField.delegate = self
        textField.font = .systemFont(ofSize: 16)

        sendButton.setTitle("发送", for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)

        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(inputContainer.snp.top)
        }
        inputContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            inputBottom = make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).constraint
            make.height.equalTo(56)
        }
        sendButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(48)
        }
        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(sendButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.height.equalTo(40)
        }
    }

    /// 预填一个示例问题，降低 demo 上手成本。
    private func seedSuggestion() {
        textField.text = "如何联系中国信达张卫东"
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
        // assistant 先占位（显示「思考中…」）
        messages.append(Message(isUser: false, content: "", isStreaming: true))
        tableView.reloadData()
        scrollToBottom(animated: true)

        isLoading = true
        sendButton.isEnabled = false

        MockSSEService.shared.askStream(
            question: question,
            onChunk: { [weak self] chunk in
                guard let self else { return }
                // 静默攒内容，UI 仍显示「思考中…」——与参考实现一致
                guard let idx = self.messages.lastIndex(where: { !$0.isUser }) else { return }
                self.messages[idx].content += chunk
            },
            onComplete: { [weak self] in
                guard let self else { return }
                self.isLoading = false
                self.sendButton.isEnabled = true
                guard let idx = self.messages.lastIndex(where: { !$0.isUser }) else { return }
                let full = self.messages[idx].content
                if let cell = self.tableView.cellForRow(at: IndexPath(row: idx, section: 0)) as? SSEAssistantCell {
                    cell.startTypewriter(fullContent: full) { [weak self] in
                        self?.requestCellHeightUpdate()
                    } completion: { [weak self] in
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
    /// 重新计算 cell 高度，但不触发 reloadRows（避免打字过程中 cell 重建）。
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
        inputBottom?.update(offset: -max(inset, 0))
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
            if !self.messages.isEmpty { self.scrollToBottom(animated: false) }
        }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        inputBottom?.update(offset: 0)
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
            cell.configure(content: msg.content, isStreaming: msg.isStreaming)
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
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(label)
        bubbleView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
        }
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14))
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(content: String) {
        label.text = content
    }
}

// MARK: - AI 消息气泡（思考中 + 分段逐字打字）

private final class SSEAssistantCell: UITableViewCell {
    static let id = "SSEAssistantCell"

    private let bubbleView = UIView()
    /// 竖直排列各片段（文本段 / 代码块卡片），首项是「思考中…」标签。
    private let stackView = UIStackView()
    private let thinkingLabel = UILabel()
    private var isShowingThinking = false

    /// 当前消息拆出的吐字片段（按文档顺序）。
    private var segments: [SSETypewriterSegment] = []
    /// 各片段的吐字长度缓存，避免每帧重复取。
    private var segmentLengths: [Int] = []
    /// 已吐出的总字符数（跨所有片段累计）。
    private var visibleTotal = 0
    /// 全部片段的字符总数。
    private var totalLength = 0

    private var typewriterTimer: Timer?
    private let typewriterInterval: TimeInterval = 0.02
    private var tickCounter = 0
    private var onHeightChange: (() -> Void)?
    private var onFinished: (() -> Void)?

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

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(stackView)
        stackView.addArrangedSubview(thinkingLabel)

        bubbleView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
        }
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// cellForRowAt 调用：根据消息状态决定显示「思考中」「全文」还是空。
    func configure(content: String, isStreaming: Bool) {
        cancelTypewriter()
        if content.isEmpty && isStreaming {
            // 思考中（流式攒字阶段，UI 不显示内容）
            rebuildSegments(from: "")
            showThinking()
        } else if content.isEmpty {
            hideThinking()
            rebuildSegments(from: "")
        } else {
            // 有内容且不在流式中 → 直接显示全文（滚动回来 / 打字已完成）
            hideThinking()
            rebuildSegments(from: content)
            // 全部可见
            for (i, seg) in segments.enumerated() { seg.setVisibleLength(segmentLengths[i]) }
            visibleTotal = totalLength
        }
    }

    /// 流式接收结束后由 VC 调用：开始逐字吐字。
    func startTypewriter(fullContent: String, onHeightChange: @escaping () -> Void, completion: @escaping () -> Void) {
        hideThinking()
        rebuildSegments(from: fullContent)
        // 全部从 0 开始
        for seg in segments { seg.setVisibleLength(0) }
        visibleTotal = 0
        tickCounter = 0
        self.onHeightChange = onHeightChange
        self.onFinished = completion

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: typewriterInterval, repeats: true) { [weak self] _ in
            self?.typewriterTick()
        }
    }

    private func typewriterTick() {
        guard visibleTotal < totalLength else {
            cancelTypewriter()
            onHeightChange?()
            onFinished?()
            onHeightChange = nil
            onFinished = nil
            return
        }
        visibleTotal += 1
        applyVisible(total: visibleTotal)

        // 每 5 个字符刷新一次高度，避免每帧都触发 layout
        tickCounter += 1
        if tickCounter >= 5 {
            tickCounter = 0
            onHeightChange?()
        }
    }

    /// 把累计可见长度按文档顺序分配到各片段。
    private func applyVisible(total: Int) {
        var remaining = total
        for (i, seg) in segments.enumerated() {
            let len = segmentLengths[i]
            let v = max(0, min(remaining, len))
            seg.setVisibleLength(v)
            remaining -= v
        }
    }

    /// 用 Block 路由把 Markdown 拆成片段视图，重建 stack。
    private func rebuildSegments(from markdown: String) {
        // 移除旧片段（保留首项 thinkingLabel）
        for seg in segments { stackView.removeArrangedSubview(seg); seg.removeFromSuperview() }
        segments = markdown.isEmpty ? [] : SSEAssistantCell.buildSegments(from: markdown)
        segmentLengths = segments.map { $0.typewriterLength }
        totalLength = segmentLengths.reduce(0, +)
        visibleTotal = 0
        for seg in segments { stackView.addArrangedSubview(seg) }
    }

    /// Markdown → 片段数组：围栏代码块走自定义卡片，表格走逐行吐字，其余走文本段。
    private static func buildSegments(from markdown: String) -> [SSETypewriterSegment] {
        let config = InkConfiguration(
            blockHandlers: [SSECodeBlockHandler(), SSETableBlockHandler()]
        )
        let blocks = InkBlockRenderer.render(markdown, configuration: config)
        var result: [SSETypewriterSegment] = []
        for block in blocks {
            if let textBlock = block as? InkAttributedTextBlock {
                result.append(SSETextSegmentView(attributedText: textBlock.attributedText))
            } else if let seg = block.makeView() as? SSETypewriterSegment {
                result.append(seg)
            }
        }
        return result
    }

    private func cancelTypewriter() {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
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
        cancelTypewriter()
        onHeightChange = nil
        onFinished = nil
        thinkingLabel.layer.removeAllAnimations()
        isShowingThinking = false
        thinkingLabel.isHidden = true
        thinkingLabel.alpha = 1
        for seg in segments { stackView.removeArrangedSubview(seg); seg.removeFromSuperview() }
        segments = []
        segmentLengths = []
        visibleTotal = 0
        totalLength = 0
    }
}

// MARK: - SSE Block Handlers

private struct SSECodeBlockHandler: InkBlockHandler {
    func canHandle(_ markup: Markup) -> Bool {
        markup is Markdown.CodeBlock
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
