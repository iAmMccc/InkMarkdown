//
//  UIKitStreamingMarkdownViewController.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import Combine
import SwiftUI
import UIKit
import InkMarkdownSwiftUI

/// UIKit 单文档流式 Markdown 演示控制器（与 SwiftUI Streaming Demo 共用 `StreamingDemoViewModel`）。
final class UIKitStreamingMarkdownViewController: UIViewController {

  private let viewModel = StreamingDemoViewModel()
  private var cancellables = Set<AnyCancellable>()
  private var streamHostingController: UIHostingController<InkStreamMarkdownView>?

  // MARK: - UI Elements

  private let statusBanner = UIView()
  private let statusLabel = UILabel()
  private let configButton = UIButton(type: .system)

  private let scrollView = UIScrollView()
  private let contentStack = UIStackView()
  private let errorBanner = UIView()
  private let errorLabel = UILabel()
  private let streamContainer = UIView()

  private let controlPanel = UIView()
  private let stateLabel = UILabel()
  private let promptTextField = UITextField()
  private let sendButton = UIButton(type: .system)
  private let appendMockButton = UIButton(type: .system)
  private let finishButton = UIButton(type: .system)
  private let cancelButton = UIButton(type: .system)
  private let resetButton = UIButton(type: .system)

  private var controlBottomConstraint: NSLayoutConstraint?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    setupNav()
    setupUI()
    setupStreamHosting()
    bindViewModel()
    updateStatusBanner()
    updateControlStates()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateStatusBanner()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if isMovingFromParent || isBeingDismissed {
      viewModel.onDisappear()
    }
  }

  private func setupNav() {
    title = "UIKit 流式 Markdown"
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      image: UIImage(systemName: "gearshape"),
      style: .plain,
      target: self,
      action: #selector(openConfigSettings)
    )
  }

  private func setupUI() {
    view.addSubview(statusBanner)
    view.addSubview(scrollView)
    view.addSubview(controlPanel)

    statusBanner.translatesAutoresizingMaskIntoConstraints = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    controlPanel.translatesAutoresizingMaskIntoConstraints = false

    statusBanner.backgroundColor = .secondarySystemBackground
    statusBanner.addSubview(statusLabel)
    statusBanner.addSubview(configButton)
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    configButton.translatesAutoresizingMaskIntoConstraints = false

    statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
    statusLabel.textColor = .label
    configButton.setTitle("切换配置", for: .normal)
    configButton.titleLabel?.font = .systemFont(ofSize: 13)
    configButton.addTarget(self, action: #selector(openConfigSettings), for: .touchUpInside)

    scrollView.addSubview(contentStack)
    contentStack.axis = .vertical
    contentStack.spacing = 16
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    errorBanner.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
    errorBanner.layer.cornerRadius = 8
    errorBanner.isHidden = true
    errorLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
    errorLabel.textColor = .systemRed
    errorLabel.numberOfLines = 0
    errorBanner.addSubview(errorLabel)
    errorBanner.translatesAutoresizingMaskIntoConstraints = false
    errorLabel.translatesAutoresizingMaskIntoConstraints = false

    streamContainer.translatesAutoresizingMaskIntoConstraints = false
    contentStack.addArrangedSubview(errorBanner)
    contentStack.addArrangedSubview(streamContainer)

    controlPanel.backgroundColor = .systemBackground
    controlPanel.layer.borderWidth = 0.5
    controlPanel.layer.borderColor = UIColor.separator.cgColor

    stateLabel.font = .systemFont(ofSize: 12)
    stateLabel.textColor = .secondaryLabel
    stateLabel.numberOfLines = 2

    promptTextField.borderStyle = .roundedRect
    promptTextField.placeholder = "输入自定义提问测试流式渲染..."
    promptTextField.font = .systemFont(ofSize: 14)
    promptTextField.returnKeyType = .send
    promptTextField.delegate = self
    promptTextField.text = viewModel.inputPrompt

    sendButton.setTitle("发送", for: .normal)
    sendButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
    sendButton.backgroundColor = .systemBlue
    sendButton.setTitleColor(.white, for: .normal)
    sendButton.layer.cornerRadius = 6
    sendButton.addTarget(self, action: #selector(handleSendPrompt), for: .touchUpInside)

    let inputRow = UIStackView(arrangedSubviews: [promptTextField, sendButton])
    inputRow.spacing = 8
    sendButton.widthAnchor.constraint(equalToConstant: 60).isActive = true
    sendButton.heightAnchor.constraint(equalToConstant: 34).isActive = true

    appendMockButton.setTitle("追加模拟分片", for: .normal)
    appendMockButton.titleLabel?.font = .systemFont(ofSize: 13)
    appendMockButton.addTarget(self, action: #selector(handleAppendMock), for: .touchUpInside)

    finishButton.setTitle("完成输入", for: .normal)
    finishButton.titleLabel?.font = .systemFont(ofSize: 13)
    finishButton.addTarget(self, action: #selector(handleFinish), for: .touchUpInside)

    cancelButton.setTitle("取消", for: .normal)
    cancelButton.titleLabel?.font = .systemFont(ofSize: 13)
    cancelButton.setTitleColor(.systemRed, for: .normal)
    cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

    resetButton.setTitle("重置", for: .normal)
    resetButton.titleLabel?.font = .systemFont(ofSize: 13)
    resetButton.addTarget(self, action: #selector(handleReset), for: .touchUpInside)

    let buttonRow = UIStackView(arrangedSubviews: [appendMockButton, finishButton, cancelButton, resetButton])
    buttonRow.distribution = .equalSpacing

    let panelStack = UIStackView(arrangedSubviews: [stateLabel, inputRow, buttonRow])
    panelStack.axis = .vertical
    panelStack.spacing = 10
    panelStack.translatesAutoresizingMaskIntoConstraints = false
    controlPanel.addSubview(panelStack)

    controlBottomConstraint = controlPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

    NSLayoutConstraint.activate([
      statusBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      statusBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      statusBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      statusBanner.heightAnchor.constraint(equalToConstant: 36),

      statusLabel.leadingAnchor.constraint(equalTo: statusBanner.leadingAnchor, constant: 16),
      statusLabel.centerYAnchor.constraint(equalTo: statusBanner.centerYAnchor),
      configButton.trailingAnchor.constraint(equalTo: statusBanner.trailingAnchor, constant: -16),
      configButton.centerYAnchor.constraint(equalTo: statusBanner.centerYAnchor),

      scrollView.topAnchor.constraint(equalTo: statusBanner.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: controlPanel.topAnchor),

      contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
      contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
      contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
      contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
      contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

      errorLabel.topAnchor.constraint(equalTo: errorBanner.topAnchor, constant: 10),
      errorLabel.leadingAnchor.constraint(equalTo: errorBanner.leadingAnchor, constant: 10),
      errorLabel.trailingAnchor.constraint(equalTo: errorBanner.trailingAnchor, constant: -10),
      errorLabel.bottomAnchor.constraint(equalTo: errorBanner.bottomAnchor, constant: -10),

      controlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      controlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      controlBottomConstraint!,

      panelStack.topAnchor.constraint(equalTo: controlPanel.topAnchor, constant: 12),
      panelStack.leadingAnchor.constraint(equalTo: controlPanel.leadingAnchor, constant: 16),
      panelStack.trailingAnchor.constraint(equalTo: controlPanel.trailingAnchor, constant: -16),
      panelStack.bottomAnchor.constraint(equalTo: controlPanel.bottomAnchor, constant: -12),
    ])

    setupKeyboard()
  }

  private func setupStreamHosting() {
    let hosting = UIHostingController(rootView: InkStreamMarkdownView(session: viewModel.session))
    hosting.view.backgroundColor = .clear
    if #available(iOS 16.0, *) {
      hosting.sizingOptions = [.intrinsicContentSize]
    }

    addChild(hosting)
    streamContainer.addSubview(hosting.view)
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hosting.view.topAnchor.constraint(equalTo: streamContainer.topAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: streamContainer.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: streamContainer.trailingAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: streamContainer.bottomAnchor),
    ])
    hosting.didMove(toParent: self)
    streamHostingController = hosting
  }

  private func bindViewModel() {
    viewModel.$errorMessage
      .receive(on: DispatchQueue.main)
      .sink { [weak self] message in
        guard let self else { return }
        self.errorLabel.text = message
        self.errorBanner.isHidden = message == nil
      }
      .store(in: &cancellables)

    viewModel.$isLoading
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateControlStates()
      }
      .store(in: &cancellables)

    viewModel.$nextChunkIndex
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateControlStates()
      }
      .store(in: &cancellables)

    viewModel.session.$state
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateControlStates()
      }
      .store(in: &cancellables)

    viewModel.session.$isPromoted
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateControlStates()
      }
      .store(in: &cancellables)

    viewModel.session.onDisplayUpdate = { [weak self] in
      self?.scrollToBottom()
    }
  }

  private func updateStatusBanner() {
    let config = LLMConfigurationStore.shared.activeConfig
    if config.isMock {
      statusLabel.text = "当前端点: 本地预设模拟"
    } else {
      statusLabel.text = "当前端点: \(config.name) (\(config.model))"
    }
  }

  private func updateControlStates() {
    stateLabel.text = viewModel.stateDescription
    appendMockButton.isEnabled = viewModel.canAppendMock
    finishButton.isEnabled = viewModel.canFinish
    cancelButton.isEnabled = viewModel.canCancel
    let prompt = promptTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    sendButton.isEnabled = !viewModel.isLoading && !prompt.isEmpty
  }

  @objc private func openConfigSettings() {
    let hosting = UIHostingController(rootView: LLMConfigView())
    present(hosting, animated: true)
  }

  // MARK: - Actions

  @objc private func handleAppendMock() {
    viewModel.appendNextMockChunk()
  }

  @objc private func handleFinish() {
    viewModel.finishStreaming()
  }

  @objc private func handleCancel() {
    viewModel.cancelStreaming()
  }

  @objc private func handleReset() {
    viewModel.resetSession()
    promptTextField.text = StreamingDemoViewModel.defaultPrompt
    viewModel.inputPrompt = StreamingDemoViewModel.defaultPrompt
  }

  @objc private func handleSendPrompt() {
    viewModel.inputPrompt = promptTextField.text ?? ""
    viewModel.sendRealPrompt(config: LLMConfigurationStore.shared.activeConfig)
    if viewModel.showingConfigSheet {
      openConfigSettings()
    }
  }

  private func scrollToBottom() {
    let bottom = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
    if bottom > scrollView.contentOffset.y {
      scrollView.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
    }
  }

  // MARK: - Keyboard Handling

  private func setupKeyboard() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillShow),
      name: UIResponder.keyboardWillShowNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(keyboardWillHide),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }

  @objc private func keyboardWillShow(_ n: Notification) {
    guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
    let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
    let inset = frame.height - view.safeAreaInsets.bottom
    controlBottomConstraint?.constant = -max(inset, 0)
    UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
  }

  @objc private func keyboardWillHide(_ n: Notification) {
    let duration = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
    controlBottomConstraint?.constant = 0
    UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
  }
}

extension UIKitStreamingMarkdownViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    handleSendPrompt()
    return true
  }

  func textFieldDidEndEditing(_ textField: UITextField) {
    viewModel.inputPrompt = textField.text ?? ""
  }
}
