//
//  LLMModelPresets.swift
//  ExampleApp
//

import Foundation

/// 大模型 ID 预设常量（Example Demo 专用，非库公开 API）。
public enum LLMModelPresets {
    /// 预设模型描述项
    public struct PresetModel: Identifiable, Hashable {
        public let id: String
        public let name: String
        public let description: String

        public init(id: String, name: String, description: String) {
            self.id = id
            self.name = name
            self.description = description
        }
    }

    /// RightCodes / OpenAI 5.6 全系列模型（Sol、Terra、Luna 等）
    public static let gpt56Series: [PresetModel] = [
        PresetModel(id: "gpt-5.6-sol", name: "GPT 5.6 Sol", description: "旗舰最强推理模型，复杂架构、科研推演与高难度任务"),
        PresetModel(id: "gpt-5.6-terra", name: "GPT 5.6 Terra", description: "平衡型主力模型，兼顾强大性能与响应速度"),
        PresetModel(id: "gpt-5.6-luna", name: "GPT 5.6 Luna", description: "极速轻量模型，高频低时延，支持丰富推理档位"),
        PresetModel(id: "gpt-5.6-nova", name: "GPT 5.6 Nova", description: "超大参数量模型，深度逻辑分析与长文本理解"),
        PresetModel(id: "gpt-5.6-flash", name: "GPT 5.6 Flash", description: "极速轻量低时延模型，适合高频对话与流式展示"),
        PresetModel(id: "gpt-5.6-pro", name: "GPT 5.6 Pro", description: "高算力专业推理，擅长数理逻辑与长链推演"),
        PresetModel(id: "gpt-5.6-coder", name: "GPT 5.6 Coder", description: "代码与工程特化模型，支持复杂代码生成与重构")
    ]

    /// 常见流行推理/通用大模型
    public static let popularModels: [PresetModel] = [
        PresetModel(id: "deepseek-reasoner", name: "DeepSeek R1", description: "深度思考强化学习模型 (671B MoE)"),
        PresetModel(id: "deepseek-chat", name: "DeepSeek V3", description: "通用对话与代码模型"),
        PresetModel(id: "o3-mini", name: "OpenAI o3-mini", description: "OpenAI 最新轻量推理模型"),
        PresetModel(id: "o1", name: "OpenAI o1", description: "OpenAI 旗舰推理模型"),
        PresetModel(id: "gpt-4o", name: "GPT-4o", description: "OpenAI 旗舰全模态智能模型"),
        PresetModel(id: "gpt-4o-mini", name: "GPT-4o mini", description: "OpenAI 快速经济型模型")
    ]

    /// RightCodes Codex 官方默认模型。
    public static let rightCodesDefault = "gpt-5.6-luna"
}

/// API 网关端点预设常量。
public enum LLMEndpointPresets {
    /// RightCodes 公开文档网关（替代旧 right.codes host，避免 TLS 握手 RST）。
    public static let rightCodesBaseURL = "https://www.rightapi.ai/codex/v1"
}
