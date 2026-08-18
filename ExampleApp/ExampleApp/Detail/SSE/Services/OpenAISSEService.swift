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
            if code == 401 {
                return "API 认证失败 (HTTP 401)：请检查 API Key 是否正确或已过期。"
            }
            if code == 429 {
                return "请求过于频繁或额度不足 (HTTP 429)：\(msg)"
            }
            return "服务器返回错误 (HTTP \(code))：\(msg)"
        case .networkError(let err):
            return LLMErrorMapper.userFacingMessage(for: err)
        case .cancelled:
            return "流式请求已取消。"
        }
    }
}

/// 大模型流式问答服务（支持本地 Mock 与任意 OpenAI 兼容的真实 SSE 服务）。
public final class OpenAISSEService: NSObject, @unchecked Sendable {

    public static let shared = OpenAISSEService()

    private var activeDataTask: URLSessionDataTask?
    private var sseDelegate: SSEStreamParserDelegate?
    private var session: URLSession?

    private override init() {
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

        // 1. 本地 Mock 模式
        if config.isMock {
            MockSSEService.shared.askStream(
                question: question,
                onChunk: { chunk in
                    Task { @MainActor in onChunk(chunk) }
                },
                onComplete: {
                    Task { @MainActor in onComplete() }
                }
            )
            return
        }

        // 2. 真实网络请求前置校验
        let trimmedKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            Task { @MainActor in onError(.missingAPIKey) }
            return
        }

        guard let endpointURL = config.chatCompletionsURL else {
            Task { @MainActor in onError(.invalidURL(config.baseURL)) }
            return
        }

        // 3. 构建 OpenAI Chat Completions 请求体
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        let payload: [String: Any] = [
            "model": config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4o-mini" : config.model,
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

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            Task { @MainActor in onError(.networkError(NSError(domain: "OpenAISSEService", code: -1, userInfo: [NSLocalizedDescriptionKey: "请求体序列化失败"]))) }
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

    /// 中断当前活跃的流式请求。
    public func cancel() {
        MockSSEService.shared.cancel()
        activeDataTask?.cancel()
        activeDataTask = nil
        session?.invalidateAndCancel()
        session = nil
        sseDelegate = nil
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
    private var hasFinished = false

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
        guard !hasFinished else { return }

        // 非 2xx 响应时累积错误信息
        if statusCode < 200 || statusCode >= 300 {
            errorBodyData.append(data)
            return
        }

        buffer.append(data)
        processBuffer()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !hasFinished else { return }
        hasFinished = true

        if let error = error {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                // 用户主动取消
                return
            }
            Task { @MainActor in
                self.onError(.networkError(error))
            }
            return
        }

        if statusCode < 200 || statusCode >= 300 {
            let message = parseErrorMessage(from: errorBodyData)
            Task { @MainActor in
                self.onError(.httpError(statusCode: self.statusCode, message: message))
            }
            return
        }

        // 刷新剩余未处理的行
        processBuffer(isFinal: true)

        Task { @MainActor in
            self.onComplete()
        }
    }

    // MARK: - 内部行解析

    private func processBuffer(isFinal: Bool = false) {
        guard let text = String(data: buffer, encoding: .utf8) else { return }

        var lines = text.components(separatedBy: "\n")
        if !isFinal {
            // 最后一行可能是不完整的 chunk，保留在 buffer 中
            if let lastLine = lines.popLast() {
                buffer = lastLine.data(using: .utf8) ?? Data()
            }
        } else {
            buffer.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix(":") {
                continue // 注释或保活 ping
            }

            if trimmed.hasPrefix("data:") {
                let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" {
                    hasFinished = true
                    Task { @MainActor in
                        self.onComplete()
                    }
                    return
                }

                if let chunkText = parseDeltaContent(from: payload) {
                    Task { @MainActor in
                        self.onChunk(chunkText)
                    }
                }
            }
        }
    }

    /// 解析 OpenAI 单行 SSE JSON 中的 delta.content
    private func parseDeltaContent(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any] else {
            return nil
        }

        // 优先提取 content；若有 reasoning_content（深度思考模型）亦可合并或提取
        if let content = delta["content"] as? String {
            return content
        }
        return nil
    }

    /// 提取服务端返回的错误信息
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
