import Foundation

/// 推理程度（Reasoning Effort）配置选项。
public enum LLMReasoningEffort: String, Codable, CaseIterable, Identifiable, Hashable {
    case automatic = "auto"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case xhigh = "xhigh"
    case max = "max"
    case ultra = "ultra"

    public var id: String { rawValue }

    /// UI 显示完整名称
    public var displayName: String {
        switch self {
        case .automatic: return "默认（模型自适应）"
        case .low: return "低（快速响应 · low）"
        case .medium: return "中（均衡思考 · medium）"
        case .high: return "高（深度推理 · high）"
        case .xhigh: return "超高（复杂逻辑 · xhigh）"
        case .max: return "极限（最深思考 · max）"
        case .ultra: return "Ultra（多智能体增强 · ultra）"
        }
    }

    /// UI 紧凑短名称（供顶部状态栏等紧凑区域展示）
    public var shortName: String {
        switch self {
        case .automatic: return "默认推理"
        case .low: return "低推理"
        case .medium: return "中推理"
        case .high: return "高推理"
        case .xhigh: return "超高推理"
        case .max: return "极限推理"
        case .ultra: return "Ultra推理"
        }
    }

    /// 传递给 OpenAI / RightCodes API 的 `reasoning_effort` 字段值（auto 时不传）。
    public var apiValue: String? {
        switch self {
        case .automatic: return nil
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .xhigh: return "xhigh"
        case .max: return "max"
        case .ultra: return "ultra"
        }
    }
}

/// 大模型服务配置模型。
public struct LLMConfiguration: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    /// 配置显示名称（如 "RightCodes Codex", "OpenAI 官方", "本地模拟" 等）。
    public var name: String
    /// API 基础请求路径（如 "https://right.codes/codex/v1" 或 "https://api.openai.com/v1"）。
    public var baseURL: String
    /// 用户填入的 API Key（不加密保存在本地沙盒，仅供 Demo 调试使用）。
    public var apiKey: String
    /// 目标模型名称（如 "gpt-5.6-luna", "gpt-5.6-nova", "deepseek-reasoner" 等）。
    public var model: String
    /// 推理程度设置（支持 auto / low / medium / high）。
    public var reasoningEffort: LLMReasoningEffort
    /// 是否为本地内置的 Mock 服务（无需联网与 API Key）。
    public var isMock: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        apiKey: String = "",
        model: String = "gpt-4o-mini",
        reasoningEffort: LLMReasoningEffort = .automatic,
        isMock: Bool = false
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.isMock = isMock
    }

    // MARK: - Codable (兼容既有老版本持久化数据)

    private enum CodingKeys: String, CodingKey {
        case id, name, baseURL, apiKey, model, reasoningEffort, isMock
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.baseURL = try container.decode(String.self, forKey: .baseURL)
        self.apiKey = try container.decode(String.self, forKey: .apiKey)
        self.model = try container.decode(String.self, forKey: .model)
        self.reasoningEffort = try container.decodeIfPresent(LLMReasoningEffort.self, forKey: .reasoningEffort) ?? .automatic
        self.isMock = try container.decode(Bool.self, forKey: .isMock)
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
        reasoningEffort: .automatic,
        isMock: true
    )

    public static let rightCodesPreset = LLMConfiguration(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "RightCodes Codex",
        baseURL: LLMEndpointPresets.rightCodesBaseURL,
        apiKey: "",
        model: LLMModelPresets.rightCodesDefault,
        reasoningEffort: .automatic,
        isMock: false
    )

    public static let openAIPreset = LLMConfiguration(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "OpenAI 官方",
        baseURL: "https://api.openai.com/v1",
        apiKey: "",
        model: "gpt-4o",
        reasoningEffort: .automatic,
        isMock: false
    )

    public static let deepSeekPreset = LLMConfiguration(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        name: "DeepSeek V3 (通用对话)",
        baseURL: "https://api.deepseek.com/v1",
        apiKey: "",
        model: "deepseek-chat",
        reasoningEffort: .automatic,
        isMock: false
    )

    public static let deepSeekReasonerPreset = LLMConfiguration(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        name: "DeepSeek R1 (深度思考)",
        baseURL: "https://api.deepseek.com/v1",
        apiKey: "",
        model: "deepseek-reasoner",
        reasoningEffort: .high,
        isMock: false
    )

    public static let defaultPresets: [LLMConfiguration] = [
        .mockPreset,
        .deepSeekReasonerPreset,
        .deepSeekPreset,
        .rightCodesPreset,
        .openAIPreset
    ]
}
