//
//  LLMModelPresets.swift
//  ExampleApp
//

import Foundation

/// 大模型 ID 预设常量（Example Demo 专用，非库公开 API）。
enum LLMModelPresets {
    /// RightCodes Codex 官方默认模型。
    static let rightCodesDefault = "gpt-5.6-luna"
}

/// API 网关端点预设常量。
enum LLMEndpointPresets {
    /// RightCodes 公开文档网关（替代旧 right.codes host，避免 TLS 握手 RST）。
    static let rightCodesBaseURL = "https://www.rightapi.ai/codex/v1"
}
