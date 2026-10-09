//
//  OpenAISSEService.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import Foundation

/// 流式错误定义。
public enum LLMStreamError: LocalizedError {
  case missingAPIKey
  case invalidURL(String)
  case httpError(statusCode: Int, message: String)
  case networkError(Error)
  case cancelled

  public var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "当前配置尚未填入 API Key，请点击右上角「⚙️ 配置」填入有效密钥。"
    case .invalidURL(let url):
      return "无效的 API 请求地址: \(url)"
    case .httpError(let code, let msg):
      return LLMErrorMapper.userFacingHTTPMessage(statusCode: code, message: msg)
    case .networkError(let err):
      return LLMErrorMapper.userFacingMessage(for: err)
    case .cancelled:
      return "流式请求已取消。"
    }
  }
}

/// 大模型流式问答服务（支持本地 Mock 与任意 OpenAI 兼容的真实 SSE 服务）。
@MainActor
public final class OpenAISSEService: NSObject {

  public static let shared = OpenAISSEService()

  private let mockService: MockSSEService
  private var activeRequest: StreamRequestDelivery?
  private var activeDataTask: URLSessionDataTask?
  private var sseDelegate: SSEStreamParserDelegate?
  private var session: URLSession?

  override init() {
    mockService = MockSSEService()
    super.init()
  }

  init(mockService: MockSSEService) {
    self.mockService = mockService
    super.init()
  }

  /// 发起流式对话请求。
  /// - Parameters:
  ///   - question: 用户提问内容。
  ///   - config: 目标大模型配置（若为 Mock 则自动调用本地 MockSSEService）。
  ///   - onChunk: 每收到有效文本分片时在主线程回调。
  ///   - onComplete: 流式正常接收完成（收到 [DONE]）时在主线程回调。
  ///   - onError: 发生网络或服务端异常时在主线程回调。
  public func askStream(
    question: String,
    config: LLMConfiguration,
    onChunk: @escaping @MainActor (String) -> Void,
    onComplete: @escaping @MainActor () -> Void,
    onError: @escaping @MainActor (LLMStreamError) -> Void
  ) {
    // 先中断上一次未完成的请求
    cancel()

    let delivery = StreamRequestDelivery(onChunk: onChunk, onComplete: onComplete, onError: onError)
    activeRequest = delivery
    delivery.onTermination = { [weak self, weak delivery] in
      guard let self, self.activeRequest === delivery else { return }
      self.mockService.cancel()
      self.activeDataTask?.cancel()
      self.activeDataTask = nil
      self.session?.invalidateAndCancel()
      self.session = nil
      self.sseDelegate = nil
      self.activeRequest = nil
    }
    let onChunk: @MainActor (String) -> Void = { delivery.receive($0) }
    let onComplete: @MainActor () -> Void = { delivery.finish() }
    let onError: @MainActor (LLMStreamError) -> Void = { delivery.fail($0) }

    // 1. 本地 Mock 模式
    if config.isMock {
      mockService.askStream(
        question: question,
        onChunk: { chunk in
          DispatchQueue.main.async { onChunk(chunk) }
        },
        onComplete: {
          DispatchQueue.main.async { onComplete() }
        }
      )
      return
    }

    // 2. 真实网络请求前置校验
    let trimmedKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedKey.isEmpty else {
      DispatchQueue.main.async { onError(.missingAPIKey) }
      return
    }

    guard let endpointURL = config.chatCompletionsURL else {
      DispatchQueue.main.async { onError(.invalidURL(config.baseURL)) }
      return
    }

    // 3. 构建 OpenAI Chat Completions 请求体
    var request = URLRequest(url: endpointURL)
    request.httpMethod = "POST"
    request.addValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 60

    let modelName = config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4o-mini" : config.model
    var payload: [String: Any] = [
      "model": modelName,
      "messages": [
        [
          "role": "system",
          "content": "You are a helpful assistant. Please use rich Markdown formatting (headings, lists, tables, code blocks with language tags, and LaTeX math $...$ or $$...$$) where appropriate."
        ],
        [
          "role": "user",
          "content": question
        ]
      ],
      "stream": true
    ]

    if let effort = config.reasoningEffort.apiValue {
      payload["reasoning_effort"] = effort
    }

    guard let bodyData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
      DispatchQueue.main.async { onError(.networkError(NSError(domain: "OpenAISSEService", code: -1, userInfo: [NSLocalizedDescriptionKey: "请求体序列化失败"]))) }
      return
    }
    request.httpBody = bodyData

    // 4. 启动 SSE 流式任务
    let parserDelegate = SSEStreamParserDelegate(
      onChunk: onChunk,
      onComplete: onComplete,
      onError: onError
    )
    self.sseDelegate = parserDelegate

    let configSession = URLSession(
      configuration: .default,
      delegate: parserDelegate,
      delegateQueue: nil
    )
    self.session = configSession

    let task = configSession.dataTask(with: request)
    self.activeDataTask = task
    task.resume()
  }

  deinit {
    // Each demo now owns its transport; releasing that owner also releases the
    // URLSession delegate cycle even when the view never receives onDisappear.
    session?.invalidateAndCancel()
  }

  /// 中断当前活跃的流式请求。
  public func cancel() {
    activeRequest?.cancel()
  }
}

// MARK: - SSE 流式行解析器 Delegate

private final class SSEStreamParserDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {

  private let onChunk: @MainActor (String) -> Void
  private let onComplete: @MainActor () -> Void
  private let onError: @MainActor (LLMStreamError) -> Void

  private var buffer = Data()
  private var statusCode: Int = 200
  private var errorBodyData = Data()
  private var isEmittingReasoning = false
  private var isTerminated = false
  private let lock = NSLock()

  init(
    onChunk: @escaping @MainActor (String) -> Void,
    onComplete: @escaping @MainActor () -> Void,
    onError: @escaping @MainActor (LLMStreamError) -> Void
  ) {
    self.onChunk = onChunk
    self.onComplete = onComplete
    self.onError = onError
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    if let httpResponse = response as? HTTPURLResponse {
      self.statusCode = httpResponse.statusCode
    }
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    lock.lock()
    guard !isTerminated else {
      lock.unlock()
      return
    }

    // 非 2xx 响应时累积错误信息
    if statusCode < 200 || statusCode >= 300 {
      errorBodyData.append(data)
      lock.unlock()
      return
    }

    buffer.append(data)
    processBuffer(isFinal: false)
    lock.unlock()
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    lock.lock()
    defer { lock.unlock() }

    guard !isTerminated else { return }

    if let error = error {
      let nsError = error as NSError
      if nsError.code == NSURLErrorCancelled {
        terminateOnce(with: .cancelled)
        return
      }
      terminateOnce(with: .failure(.networkError(error)))
      return
    }

    if statusCode < 200 || statusCode >= 300 {
      let message = parseErrorMessage(from: errorBodyData)
      terminateOnce(with: .failure(.httpError(statusCode: statusCode, message: message)))
      return
    }

    // 处理缓冲区残留的最后一行
    processBuffer(isFinal: true)
    terminateOnce(with: .success)
  }

  // MARK: - 内部状态派发

  private enum StreamTerminalResult {
    case success
    case failure(LLMStreamError)
    case cancelled
  }

  private func terminateOnce(with result: StreamTerminalResult) {
    guard !isTerminated else { return }
    isTerminated = true

    let shouldCloseReasoning = isEmittingReasoning
    isEmittingReasoning = false

    DispatchQueue.main.async {
      if shouldCloseReasoning {
        self.onChunk("\n</think>\n\n")
      }
      switch result {
      case .success:
        self.onComplete()
      case .failure(let error):
        self.onError(error)
      case .cancelled:
        break
      }
    }
  }

  private func processBuffer(isFinal: Bool) {
    guard let text = String(data: buffer, encoding: .utf8) else { return }

    var lines = text.components(separatedBy: "\n")
    if !isFinal {
      if let lastLine = lines.popLast() {
        buffer = lastLine.data(using: .utf8) ?? Data()
      }
    } else {
      buffer.removeAll()
    }

    for line in lines {
      guard !isTerminated else { break }
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty || trimmed.hasPrefix(":") {
        continue
      }

      if trimmed.hasPrefix("data:") {
        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" {
          terminateOnce(with: .success)
          return
        }

        processPayload(payload)
      }
    }
  }

  private func processPayload(_ jsonString: String) {
    guard let data = jsonString.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return
    }

    // 处理服务端在 200 OK 流中内嵌 error 对象的情况
    if let errorObj = json["error"] as? [String: Any],
      let errorMsg = errorObj["message"] as? String {
      terminateOnce(with: .failure(.httpError(statusCode: statusCode, message: errorMsg)))
      return
    }

    guard let choices = json["choices"] as? [[String: Any]],
      let firstChoice = choices.first else {
      return
    }

    let delta = firstChoice["delta"] as? [String: Any] ?? [:]
    // 1. 广泛兼容提取思考/推理内容（适配 DeepSeek、OpenAI o系列、Claude 3.7、Qwen、Groq、Ollama 等各类网关格式）
    let reasoning = extractReasoning(from: delta, choice: firstChoice, root: json)

    // 2. 提取正式回答正文
    let content = extractContent(from: delta, choice: firstChoice)

    var chunksToEmit: [String] = []

    if let reasoning = reasoning, !reasoning.isEmpty {
      if !isEmittingReasoning {
        isEmittingReasoning = true
        chunksToEmit.append("<think>\n" + reasoning)
      } else {
        chunksToEmit.append(reasoning)
      }
    }

    if let content = content, !content.isEmpty {
      if isEmittingReasoning {
        isEmittingReasoning = false
        chunksToEmit.append("\n</think>\n\n" + content)
      } else {
        chunksToEmit.append(content)
      }
    }

    if !chunksToEmit.isEmpty {
      let finalChunks = chunksToEmit
      DispatchQueue.main.async {
        for chunk in finalChunks {
          self.onChunk(chunk)
        }
      }
    }
  }

  /// 从 delta、choice 以及 top-level json 中多策略提取思考/推理内容。
  private func extractReasoning(from delta: [String: Any], choice: [String: Any], root: [String: Any]) -> String? {
    // 优先在 delta 中查找各种常见 key
    let candidateKeys = [
      "reasoning_content",       // DeepSeek official / SiliconFlow / vLLM
      "reasoning",               // OpenAI o1/o3 / OpenRouter
      "thought",                 // Qwen / Groq / Gemini / Ollama
      "thoughts",                // 部分代理中转网关
      "thinking",                // Anthropic Claude 3.7 thinking
      "reasoning_text",          // 常见聚合网关
      "reasoning_content_text",  // 聚合网关变体
      "thinking_process"         // 国产模型中转变体
    ]

    for key in candidateKeys {
      if let value = delta[key] {
        if let str = extractString(from: value), !str.isEmpty {
          return str
        }
      }
    }

    // 备选：部分网关放置于 choice 级别
    for key in candidateKeys {
      if let value = choice[key] {
        if let str = extractString(from: value), !str.isEmpty {
          return str
        }
      }
    }

    // 备选：部分非标准网关放置于 choice["message"] 级别
    if let message = choice["message"] as? [String: Any] {
      for key in candidateKeys {
        if let value = message[key] {
          if let str = extractString(from: value), !str.isEmpty {
            return str
          }
        }
      }
    }

    return nil
  }

  /// 提取正文内容（兼容 delta.content 或 legacy choice.text）。
  private func extractContent(from delta: [String: Any], choice: [String: Any]) -> String? {
    if let contentVal = delta["content"] {
      return extractString(from: contentVal)
    }
    if let textVal = choice["text"] {
      return extractString(from: textVal)
    }
    return nil
  }

  /// 递归解析 Any 类型的值为 String（支持 String、字典中的 text/content、数组等）。
  private func extractString(from value: Any) -> String? {
    if let str = value as? String {
      return str
    }
    if let dict = value as? [String: Any] {
      if let text = dict["text"] as? String {
        return text
      }
      if let content = dict["content"] as? String {
        return content
      }
      if let val = dict["value"] as? String {
        return val
      }
    }
    if let array = value as? [Any] {
      let joined = array.compactMap { extractString(from: $0) }.joined()
      return joined.isEmpty ? nil : joined
    }
    return nil
  }

  private func parseErrorMessage(from data: Data) -> String {
    guard !data.isEmpty else { return "未知服务端错误" }
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      if let errorObj = json["error"] as? [String: Any],
        let msg = errorObj["message"] as? String {
        return msg
      }
      if let msg = json["message"] as? String {
        return msg
      }
    }
    return String(data: data, encoding: .utf8) ?? "未知响应"
  }
}
