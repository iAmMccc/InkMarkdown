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
