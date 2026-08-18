//
//  LLMConfiguration.swift
//  ExampleApp
//
//  Created by InkMarkdown on 2026/8/18.
//

import Foundation

/// 大模型服务配置模型。
public struct LLMConfiguration: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    /// 配置显示名称（如 "RightCodes Codex", "OpenAI 官方", "本地模拟" 等）。
    public var name: String
    /// API 基础请求路径（如 "https://right.codes/codex/v1" 或 "https://api.openai.com/v1"）。
    public var baseURL: String
    /// 用户填入的 API Key（不加密保存在本地沙盒，仅供 Demo 调试使用）。
    public var apiKey: String
    /// 目标模型名称（如 "gpt-4o", "gpt-4o-mini", "deepseek-chat" 等）。
    public var model: String
    /// 是否为本地内置的 Mock 服务（无需联网与 API Key）。
    public var isMock: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        apiKey: String = "",
        model: String = "gpt-4o-mini",
        isMock: Bool = false
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.isMock = isMock
    }

    /// 规范化后的完整 Chat Completions 端点 URL。
    public var chatCompletionsURL: URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let baseWithoutSlash = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        let fullPath: String
        if baseWithoutSlash.hasSuffix("/chat/completions") {
            fullPath = baseWithoutSlash
        } else {
            fullPath = baseWithoutSlash + "/chat/completions"
        }
        return URL(string: fullPath)
    }

    // MARK: - 预设配置

    public static let mockPreset = LLMConfiguration(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "本地预设模拟（无需 API Key）",
        baseURL: "",
        apiKey: "",
        model: "mock-model",
        isMock: true
    )

    public static let rightCodesPreset = LLMConfiguration(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "RightCodes Codex",
        baseURL: LLMEndpointPresets.rightCodesBaseURL,
        apiKey: "",
        model: LLMModelPresets.rightCodesDefault,
        isMock: false
    )

    public static let openAIPreset = LLMConfiguration(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "OpenAI 官方",
        baseURL: "https://api.openai.com/v1",
        apiKey: "",
        model: "gpt-4o",
        isMock: false
    )

    public static let deepSeekPreset = LLMConfiguration(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        name: "DeepSeek 官方",
        baseURL: "https://api.deepseek.com/v1",
        apiKey: "",
        model: "deepseek-chat",
        isMock: false
    )

    public static let defaultPresets: [LLMConfiguration] = [
        .mockPreset,
        .rightCodesPreset,
        .openAIPreset,
        .deepSeekPreset
    ]
}
