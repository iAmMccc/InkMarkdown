//
//  LLMErrorMapper.swift
//  ExampleApp
//

import Foundation

/// 将 URLSession / NSURLError 映射为面向用户的中文说明（纯函数，不修改 ATS 策略）。
enum LLMErrorMapper {

  /// 将底层网络错误转为用户可读的中文消息。
  static func userFacingMessage(for error: Error) -> String {
    let nsError = error as NSError

    guard nsError.domain == NSURLErrorDomain else {
      return "网络连接失败：\(error.localizedDescription)"
    }

    switch nsError.code {
    case NSURLErrorSecureConnectionFailed: // -1200
      if hasSSLPayloadReset(underlying: nsError) {
        return "TLS 握手未完成，对端重置了连接；请确认网关为 rightapi.ai，这不是 API Key 错误，Demo 不会关闭 ATS"
      }
      return "网络连接失败（TLS）：\(nsError.localizedDescription)"

    case NSURLErrorAppTransportSecurityRequiresSecureConnection: // -1022
      return "App Transport Security 阻止了非安全连接；Demo 不会关闭 ATS，请使用 HTTPS 网关"

    case NSURLErrorServerCertificateUntrusted,   // -1202
      NSURLErrorServerCertificateHasBadDate,  // -1201
      NSURLErrorServerCertificateNotYetValid, // -1204
      NSURLErrorServerCertificateHasUnknownRoot: // -1203
      return "证书验证失败：\(nsError.localizedDescription)"

    default:
      return "网络连接失败：\(nsError.localizedDescription)"
    }
  }

  /// 将 HTTP 状态码与服务端错误信息转为用户可读的友好说明。
  static func userFacingHTTPMessage(statusCode: Int, message: String) -> String {
    let lower = message.lowercased()
    if lower.contains("upstream service temporarily unavailable") || lower.contains("temporarily unavailable") {
      return "上游大模型服务暂时不可用（当前选择的模型或超高推理档位可能超出算力预算，建议切换为中/高推理或更换模型重试）。"
    }
    if statusCode == 401 {
      return "API 认证失败 (HTTP 401)：请检查 API Key 是否正确或已过期。"
    }
    if statusCode == 429 {
      return "请求过于频繁或额度不足 (HTTP 429)：\(message)"
    }
    if statusCode >= 500 {
      return "服务暂时不可用 (HTTP \(statusCode))：\(message)"
    }
    return "服务器返回错误 (HTTP \(statusCode))：\(message)"
  }

  // MARK: - Private

  /// NSURLError -1200 且底层 SSL -9816（errSSLClosedAbort / 对端重置）。
  /// 沿 `NSUnderlyingErrorKey` 链匹配：NSOSStatus `-9816`，或 CFStream `_kCFStreamErrorCodeKey == -9816`。
  private static func hasSSLPayloadReset(underlying error: NSError) -> Bool {
    var current: NSError? = error
    while let err = current {
      if matchesSSLPayloadReset(err) {
        return true
      }
      current = err.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return false
  }

  private static func matchesSSLPayloadReset(_ error: NSError) -> Bool {
    if error.domain == NSOSStatusErrorDomain && error.code == -9816 {
      return true
    }
    return cfStreamErrorCode(in: error) == -9816
  }

  private static func cfStreamErrorCode(in error: NSError) -> Int? {
    for key in ["_kCFStreamErrorCodeKey", "kCFStreamErrorCodeKey"] {
      if let value = error.userInfo[key] as? Int {
        return value
      }
      if let number = error.userInfo[key] as? NSNumber {
        return number.intValue
      }
    }
    return nil
  }
}
