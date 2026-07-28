/// 图片加载过程中抛出的错误。
public enum ImageLoadError: Error, Sendable {
  /// HTTP 响应无效（非 2xx 或无法解析）。
  case invalidResponse
  /// 响应体不是可识别的图片数据。
  case notImageData
  /// 图片解码失败。
  case decodeFailed
  /// Data URL 的 Base64 段无效。
  case invalidBase64
  /// Asset catalog 中找不到指定资源名。
  case assetNotFound(String)
  /// Bundle 中找不到指定路径。
  case bundleNotFound(String)
  /// URL scheme 不在允许列表内。
  case unsupportedScheme
  /// 加载超时。
  case timeout
  /// 任务被取消。
  case cancelled
}

/// 图片请求被安全策略拒绝的原因（不抛出，供宿主展示或日志）。
public enum ImageRejectReason: Sendable {
  /// 图片功能被全局关闭。
  case disabledByPolicy
  /// 主机名不在白名单。
  case hostNotAllowed(String)
  /// URL scheme 不在白名单。
  case schemeNotAllowed(String)
  /// 载荷超过大小上限（字节数）。
  case payloadTooLarge(Int)
  /// 相对 URL 缺少 `baseURL` 无法解析。
  case noBaseURL
  /// 重定向被策略拦截。
  case redirectBlocked
}
